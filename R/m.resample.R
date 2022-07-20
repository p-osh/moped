#' Generate syntheic samples
#'
#' @param fit
#' @param K
#' @param variables
#' @param Sample
#' @param n
#' @param bounds
#' @param replicates
#' @param parallel
#' @param ncores
#' @param mps
#' @param fixed.var
#' @param er_alert
#'
#' @return
#' @export
#'
#' @examples



m.resample <- function(fit, # MBDensity Type Variable (Outputed from MBDensity)
                       K=NULL, # Truncation to be used (Default is max in Fit)
                       variables = NULL, # Which variables to be predicted from Fit (Default is 1:Nv or 1:NCOL(X) whichever smallest) )
                       Sample = fit$SampleStats$Sample, #initial values and deine the size of the synthetic dataframe
                       n = NROW(Sample),
                       bounds = NULL , #Bounds allows you to control the grid min and max (2 X Nv Dataframe)
                       replicates = 1,
                       parallel = F,
                       ncores = NULL,
                       mps = 5000,
                       fixed.var = NULL, #position of the variable(s) conditional upon
                       er_alert = T
){
  #try(if(NCOL(Sample) == 1){
  #  return(cat("\r Error: Sample must be a data frame with the length of variables"))
  #} else {


  #Default Allocations
  NS <- n
  if(is.character(fixed.var)){
    fixed.var <-  which(colnames(fit$SampleStats$Sample) %in% fixed.var)
  }
  if(is.character(variables)){
    variables <-  which(colnames(fit$SampleStats$Sample) %in% variables)
  }
  if(is.null(variables)) variables <- 1:length(fit$KMax)
  Nv <- length(variables)
  if(is.null(bounds)) bounds <- sapply(variables, function(i) fit$SampleStats$Range[,i])
  if(is.null(K)) K <- fit$KMax[variables]
  if(length(K)==1) K <- rep(K,Nv)
  if(is.null(fixed.var)) impute.vars <- 1:length(variables) else impute.vars <- (1:length(variables))[-fixed.var]

  K <- sapply(1:Nv, function(k) min(fit$KMax[variables[k]],K[k]))
  SS <- NROW(Sample)
  if(NS != SS) Sample <- Sample[sample(1:SS,NS,replace = T),]
  SS <- NS
  OSample <- Sample
  nonerror <- 1:NS
  for(re in 1:replicates){
    for(nu in impute.vars){
      Condk <- predict.conditional(fit,K.X = K[nu],Y = Sample[,-nu], K.Y = K[-nu],
                                   X.variable = variables[nu], Y.variables = variables[-nu],
                                   X.bounds = bounds[,nu], Y.bounds = bounds[,-nu])

      error <- which(apply(is.nan(Condk$coef),1,sum)>0)

      if(length(error)> 0){
        Sample <- Sample[-error,]
        Condk$coef <- Condk$coef[-error,]
        nonerror <- nonerror[-error]
        SS <- NROW(Sample)
      }
      synthetic_generator <- function(i){
        U <- c()
        coefi <- Condk$coef[i, ]
        cnt <- 0
        boundsi <- bounds[, nu]
        endpoints <-  sapply(0:(K[nu] + 1), function(k) boundsi ^ k) %*% coefi
        dproot <- polyroot(coefi[-1] * (1:(K[nu]+1)))
        dzeros <- sort(Re(dproot)[round(Im(dproot), 2) == 0 &
                                    Re(dproot) > boundsi[1] & Re(dproot) < boundsi[2]])
        if (length(dzeros) > 0) {
          rootmean <- (c(boundsi[1], dzeros) - c(dzeros, boundsi[2])) / 2
          rmi <- sapply(0:(K[nu]), function(k) (dzeros + rootmean[-length(rootmean)])^k)
          dsign <- sign( rmi %*% (coefi[-1] * (0:K[nu]+1)))
          statpoints <- sapply(0:(K[nu] + 1), function(k) dzeros ^ k) %*% coefi

          ### Trimming
          if (dsign[1] == -1) boundsi[1] <- dzeros[1] else if (statpoints[1] < 0.05) boundsi[1] <- dzeros[2]
          if (dsign[length(dsign)] == 1) boundsi[2] <- dzeros[length(dzeros)] else if
          (statpoints[length(statpoints)] > 1 - 0.05) boundsi[2] <- dzeros[length(dzeros) - 1]
          dsign <- dsign[dzeros > boundsi[1] & dzeros < boundsi[2]]
          statpoints <- statpoints[dzeros > boundsi[1] & dzeros < boundsi[2]]
          dzeros <- dzeros[dzeros > boundsi[1] & dzeros < boundsi[2]]
          ##########################

          endpoints <-  sapply(0:(K[nu] + 1), function(k) boundsi ^ k) %*% coefi
          nadjs <- length(statpoints)
          if (nadjs > 0) cdfadj <-statpoints[seq(1, nadjs, 2)] - statpoints[seq(2, nadjs, 2)] else cdfadj <- 0

          U[1] <- runif(1, endpoints[1], endpoints[2] + sum(cdfadj))

          if (nadjs > 0) {
            uregion <- which( U[1] < c(statpoints[seq(2, length(statpoints), 2)] + cumsum(cdfadj) , endpoints[2] + sum(cdfadj))
                              & U[1] > c(endpoints[1] , statpoints[seq(2, length(statpoints), 2)] + cumsum(cdfadj)) )
            boundsi[2] <- c(dzeros[seq(1, length(statpoints), 2)]  , boundsi[2] )[uregion]
            boundsi[1] <- c(boundsi[1] , dzeros[seq(2, length(statpoints), 2)] )[uregion]
            coefi[1] <- Condk$coef[i, 1] + c(0,cumsum(cdfadj))[uregion]
          }
        } else{
          U[1] <- runif(1, endpoints[1], endpoints[2])
        }
        coefi[1] <- coefi[1]- U[1]
        proot <- polyroot(coefi)
        sim <-(Re(proot)[round(Im(proot), 2) == 0 &
                           Re(proot) >= boundsi[1] & Re(proot) <= boundsi[2]])
        return(sim)
      }

      for(i in 1:SS){
        an.error.occured <- FALSE
        tryCatch( { Sample[i,nu] <- synthetic_generator(i) }
                  , error = function(e) {an.error.occured <<- TRUE})
        if(an.error.occured) error <- c(error,i)
      }

      if(length(error)> 0){
        Sample <- Sample[-error,]
        Condk$coef <- Condk$coef[-error,]
        nonerror <- nonerror[-error]
        SS <- NROW(Sample)
      }
    }}
  if(SS < NS){
    if(er_alert) cat(paste0('\n Warning: ',NS-SS,' Observations were resampled due to errors. \n'))
    ErrorSample <- m.resample(fit = fit,K=K,variables = variables,n = NS-SS+1,
                              fixed.var = fixed.var,
                              Sample = OSample[nonerror,],
                              bounds= bounds, replicates = replicates ,parallel = parallel,
                              ncores = ncores,mps = mps,er_alert = F)
    Sample <- rbind(Sample,ErrorSample)

  }

  Synth <- as.data.frame(Sample[1:NS,])
  Cats <- fit$Cats
  Cats$variables <- variables
  attr(Synth,"Cats") <- Cats
  return(Synth)
  #})
}

