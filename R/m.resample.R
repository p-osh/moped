#' Generate synthetic samples
#'
#' @description
#' `m.resample()` is used to genderate synthetic samples.
#'
#' @param fit MBDensity Type Variable. Outputed from MBDensity.
#' @param K Integer vector. Maximum Truncation of Approximation on each variable.
#'   The default is the maximum MPO Order in `moped` object.
#' @param variables Integer vector or character string. Variables to be
#'   predicted from `moped` object. The default is 1:Nv or 1:NCOL(Sample)
#'   whichever smallest.
#' @param Sample A data frame defines the size of the synthetic data frame.
#' @param n Integer vector. The number of rows in the sample data frame.
#' @param bounds A data frame. Bounds allows you to control the grid min and max.
#'   Should be an array of 2 x number of variables. `NULL` is the default.
#' @param replicates Integer vector. The default is 1.
#' @param parallel Logical. If `FALSE` (the default), parallel computing is not
#'   used.
#' @param ncores Integer vector. NCores to use in parallel computing.
#' @param mps Integer vector. The default is 5000. (?Brad)
#' @param fixed.var The position of the variable(s) conditional upon. The
#'   default is `NULL`.
#' @param er_alert Logical. The default is `TRUE`. (?Brad)
#'
#' @return `m.resample()` returns a data frame.
#' @export
#'
#' @examples
#' Data_full <- ISLR::Wage
#' Data <- Data_full %>%
#' select(age, education, jobclass,wage)
#'
#' # Convert Categorical Data to Continuous Data
#' Data_x <- make.cont(Data, catvar = 2:3)
#'
#' # Fitting multivariate orthogonal polynomial based
#' # density estimation function
#' # Requires a data frame of bounds to fit on data.
#' bounds <- data.frame(
#' age  = c(18,80),
#' education = c(0,1),
#' jobclass = c(0,1),
#' wage = c(0,350)
#' )
#'
#' # Fitting the Data
#' Fit <- moped(
#' Data_x,
#' K=10,
#' Distrib = rep("Uniform", 7),
#' bounds = bounds,
#' variance = T,
#' recurrence = F,
#' parallel = F,
#' ncores = NULL,
#' mpo = T
#' )
#'
#' # Generating resampled Obs
#'resampled <- m.resample(Fit, K=3, Sample=Data_x, fixed.var = 1, replicates = 1)
#'resampled <- m.resample(Fit, K=3, replicates = 1) # A fully resampled dataset
#'resampled <- m.resample(Fit, K=3, Sample = Data_x, variables = 4, replicates = 1)
#'
#' # Marginal Synthetic
#' resampled_marginal <- m.resample(Fit,
#' Sample = Data_x[,3:4],
#' K = c(3,4),
#' variables = 3:4,
#' replicates = 1
#' )
#'
#' # Convert previously continulized variables back to categorical variables.
#' resampled <- make.cat(resampled)
#'
#'
#'
#'


m.resample <- function(fit,
                       K=NULL,
                       variables = NULL,
                       Sample = fit$SampleStats$Sample,
                       n = NROW(Sample),
                       bounds = NULL ,
                       replicates = 1,
                       parallel = F,
                       ncores = NULL,
                       mps = 5000,
                       fixed.var = NULL,
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

