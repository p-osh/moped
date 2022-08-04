#' Generate resampled (synthetic) samples
#'
#' @description
#' `m.resample()` is used to generate synthetic samples from full, conditional,
#'  or marginal moped density estimate.
#'
#' @param fit moped type variable. Outputted from `moped()`.
#' @param K Integer vector. Maximum Polynomial Order of approximation on each 
#'   variable. Must be less than or equal to the maximum MPO K specified in 
#'   `moped()`. The default is the K specified in `moped` object.
#' @param variables Integer vector or character string of variable names. The 
#'   `moped` position or column name of the variable(s) to be predicted from 
#'   `moped` object. The default is 1:Nv or 1:NCOL(Sample) whichever smallest.
#' @param Sample A data frame of initial values used to impute values. Must 
#'   contain column names matching variables in the `moped` object. Default is 
#'   the Sample used to fit the `moped` object.
#' @param n Integer vector. The number of rows to be simulated.
#' @param bounds A data frame. Bounds allows you to control the grid min and max.
#'   Should be an array of 2 x number of variables. `NULL` is the default.
#' @param replicates Integer vector. Number of complete Gibbs sampling passes.
#'     The default is 1.
#' @param parallel Logical. If `FALSE` (the default), parallel computing is not
#'   used.
#' @param ncores Integer vector. Number of cores used in parallel computing.
#' @param mps Integer vector. Limit on maximum number of probabilities 
#'  calculated at a time. The default is 5000.
#' @param fixed.var Integer vector or string of variable names. The `moped` 
#'   position or column name of the variable(s) conditioned upon without 
#'   imputation. The default is `NULL`.
#' @param er_alert Logical. The default is `TRUE`. If `TRUE` returns error 
#' message when observations require re-sampling due to errors.
#'
#' @return `m.resample()` returns a data frame of imputed values.
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
#' Distrib = rep("Uniform", 4),
#' bounds = bounds,
#' variance = T,
#' recurrence = F,
#' parallel = F,
#' ncores = NULL,
#' mpo = F
#' )
#'
#' # Generating resampled (synthetic) observations
#' # Sample 100 obs from moped joint density estimate without updating "age"
#'resampled <- m.resample(Fit, K=3, Sample=Data_x, n = 100, fixed.var = "age")
#' # Simulate a fully resampled data set of same size as Data_x.
#'resampled <- m.resample(Fit, K=3, replicates = 2) # 2 Gibbs passes used.
#'
#' # Convert previously continuised variables back to categorical variables.
#' resampled <- make.cat(resampled)
#'
#' # Sample fully synthetic data set from marginal bivariate moped density 
#' # estimate of "age" and "wage"
#' resampled_marginal <- m.resample(Fit,
#' Sample = Data_x[,c(1,4)],
#' K = c(4,5),
#' variables = c(1,4),
#' replicates = 1
#' )
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

  #Default Allocations
  NS <- n
  if(is.character(fixed.var)){
    fixed.var <-  which(colnames(fit$SampleStats$Sample) %in% fixed.var)
  }
  if(is.character(variables)){
    variables <-  which(colnames(fit$SampleStats$Sample) %in% variables)
  }
  if(is.null(variables)) variables <- 1:length(fit$KMax)
  if(is.null(fixed.var)) impute.vars <- 1:length(variables) else impute.vars <- (1:length(variables))[-fixed.var]
  Nv <- length(variables)
  
  variables_names <- colnames(fit$SampleStats$Sample)[variables]
  
  test_names <- prod(variables_names %in% colnames(Sample)) == 0 | !is.data.frame(Sample) 
  
  try(if(test_names){
    return(cat("\r Error: Sample must be a data frame and contain columns named ",variables_names))
  } else {
    tryCatch(bounds <- setNames(data.frame(bounds[,variables_names]),
                                variables_names),
             error = function(e) bounds <<- NULL)
    if(is.null(bounds)){
      bounds <- as.data.frame(fit$SampleStats$Range[,variables])
      colnames(bounds) <- variables_names
    }
  if(is.null(K)) K <- fit$KMax[variables]
  if(length(K)==1) K <- rep(K,Nv)
  K <- sapply(1:Nv, function(k) min(fit$KMax[variables[k]],K[k]))
  
  OSample <- Sample
  SS <- NROW(Sample)
  if(NS != SS) Sample <- Sample[sample(1:SS,NS,replace = T),]
  SS <- NS
  Sample <- as.data.frame(Sample[,variables_names])
  colnames(Sample) <- variables_names
  
  nonerror <- 1:NS
  for(re in 1:replicates){
    for(nu in impute.vars){
      if(fit$Distrib[variables[nu]] == "Uniform"){
      if(length(variables[-nu])==0){
      Condk <- predict.marg.cdf(fit,K = K[nu],nprobs = NROW(Sample), 
                                variable = variables[nu])  
      }else{
      Condk <- predict.conditional(fit,
                                   K.X = K[nu],
                                   Y = setNames(data.frame(Sample[,-nu]),
                                                colnames(Sample)[-nu]), K.Y = K[-nu],
                                   X.variable = variables[nu], 
                                   Y.variables = variables[-nu])
      }
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
      }else{
        if(length(variables[-n])==0){
        lb <- predict.marg.cdf(fit,K = K[nu], 
                               X= fit$SampleStats$Range[1,variables[nu]],
                               variable = variables[nu])$Prob
        ub <- predict.marg.cdf(fit,K = K[nu], 
                               X= fit$SampleStats$Range[2,variables[nu]],
                               variable = variables[nu])$Prob
        }else{
          lb <- predict.conditional(fit,K.X = K[nu], 
                                    X= rep(fit$SampleStats$Range[1,variables[nu]],
                                           NROW(Sample)), 
                                    Y = setNames(data.frame(Sample[,-nu]),
                                                 colnames(Sample)[-nu]), 
                                    K.Y = K[-nu],
                                    X.variable = variables[nu], 
                                    Y.variables = variables[-nu])$Prob
          ub <- predict.conditional(fit,K.X = K[nu], 
                                    X= rep(fit$SampleStats$Range[2,variables[nu]],
                                           NROW(Sample)), 
                                    setNames(data.frame(Sample[,-nu]),
                                             colnames(Sample)[-nu]),
                                    K.Y = K[-nu],
                                    X.variable = variables[nu], 
                                    Y.variables = variables[-nu])$Prob
        }
        
        synthetic_generator <- function(i){
          if(length(variables[-nu])==0){
            xi<- data.frame(median(fit$SampleStats$Sample[,variables[nu]]))
            colnames(xi) <- variables_names[nu]
            x0<-xi+1
            u <- runif(1,lb,ub)
            it_cnt <- 0
            while(abs(x0-xi)>0.001 &!is.nan(xi) & it_cnt <= 100){
            x0 <- xi
            FX <- predict.marg.cdf(fit,K = K[nu], X= xi,variable = variables[nu])$Prob 
            fX <- predict(fit, K= K[nu],X=xi,variables = variables[nu])$Density
            xi <- xi - (FX-u)/fX
            it_cnt <- it_cnt + 1
            }
            if(is.nan(xi) | it_cnt>=100 | 
               xi < fit$SampleStats$Range[1,variables[nu]] | 
               xi > fit$SampleStats$Range[2,variables[nu]]){
              fX <- predict(fit, K= K[nu],variables = variables[nu],nodes=200)
              FX_p <- cumsum(fX$Density)
              FX_p <- (FX_p - min(FX_p))/(max(FX_p)- min(FX_p))
              FX_p <- (ub-lb)*FX_p + lb
              FX <- approxfun(x=FX_p,y=fX[,1])
              xi <- FX(u)
            }
            return(unlist(xi))
          }else{
            xi<- data.frame(median(fit$SampleStats$Sample[,variables[nu]]))
            colnames(xi) <- variables_names[nu]
            x0<-xi+1
            u <- runif(1,lb[i],ub[i])
            it_cnt <- 0
            while(abs(x0-xi)>0.001 &!is.nan(xi) & it_cnt <= 100){
            x0 <- xi
            xi_vec <- cbind(xi,setNames(data.frame(Sample[i,-nu]),colnames(Sample)[-nu]))
            FX <- predict.conditional(fit,K.X = K[nu],X=xi,
                                         Y = setNames(data.frame(Sample[,-nu]),
                                                      colnames(Sample)[-nu]), 
                                         K.Y = K[-nu],
                                         X.variable = variables[nu], Y.variables = variables[-nu])$Prob
            mfX <- predict(fit, K= K[nu],X=xi,variables = variables[nu])$Density
            fX <-  predict(fit, K= c(K[nu],K[-nu]),X=xi_vec,
                           variables = c(variables[nu],variables[-nu]))$Density
            xi <- xi - mfX*(FX-u)/fX
            it_cnt <- it_cnt + 1
            }
            if(is.nan(xi) | it_cnt>=100 | 
               xi < fit$SampleStats$Range[1,variables[nu]] | 
               xi > fit$SampleStats$Range[2,variables[nu]]){
              grid_pts <- data.frame(seq(fit$SampleStats$Range[1,variables[nu]],
                              fit$SampleStats$Range[2,variables[nu]],length.out=200))
              colnames(grid_pts) <- variables_names[nu]
              grid_pts <- suppressWarnings(cbind(grid_pts,setNames(data.frame(Sample[,-nu]),
                                                                   colnames(Sample)[-nu])))
              fX <- predict(fit, K= c(K[nu],K[-nu]),X=grid_pts,
                            variables = c(variables[nu],variables[-nu]))
              FX_p <- cumsum(fX$Density)
              FX_p <- (FX_p - min(FX_p))/(max(FX_p)- min(FX_p))
              FX_p <- (ub[i]-lb[i])*FX_p + lb[i]
              FX <- suppressWarnings(approxfun(x=FX_p,y=fX[,1]))
              xi <- FX(u)
            }
            return(unlist(xi))
          }
        }
        error <- c()
        for(i in 1:SS){
          an.error.occured <- FALSE
          tryCatch( { Sample[i,nu] <- synthetic_generator(i) }
                    , error = function(e) {an.error.occured <<- TRUE})
          if(an.error.occured) error <- c(error,i)
        }
        
        error <- unique(c(error,which(is.nan(Sample[,nu]))))
        
        if(length(error)> 0){
          Sample <- Sample[-error,]
          nonerror <- nonerror[-error]
          SS <- NROW(Sample)
        }
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
  Synth <- OSample[1:NS,]
  Synth[,variables_names] <- as.data.frame(Sample)[1:NS,]
  Cats <- fit$Cats
  Cats$variables <- variables
  attr(Synth,"Cats") <- Cats
  return(Synth)
   })
}

