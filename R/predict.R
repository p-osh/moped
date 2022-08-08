#' Predicting the density or probability of an observation based on moped
#' density estimate.
#'
#' @description
#' `predict.moped()` is used to predict density and probabilities for a set of
#' observations. When constructing partially joint density, sample and variables must be used
#' together. X must be a data frame and its variable length must equal to
#' the length in var.
#'
#' @param fit `moped` type variable. Outputted from `moped()`.
#' @param X An optional data frame in which to look for variables with which
#'   to estimate density values. Must contain column names matching variables in
#'   the `moped` object. If `NULL` (the default) then generates a `nodes`^`fit$Nv`
#'   grid with density values.
#' @param K Integer vector of max polynomial order of approximation on each
#'   variable. Must be less than or equal to the maximum MPO K specified in
#'   `moped()`. The default is the `opt_mpo` or `KMax` (if `opt_mpo = NULL`) specified
#'   in `fit`.
#' @param variables Integer vector or character string of variable names. The
#'   `moped` position or column name of the variable(s) to be predicted from
#'   `moped` object. The default is `1:fit$Nv`.
#' @param bounds An optional data frame specifying the limits to be used on bounded space.
#'   Should be an array of 2 x number of variables with each column having the
#'   lower and upper limit.
#' @param type string equal to `"density"` (default) or `"distribution"`. If
#'  `type = "density"` density values are estimated. If `type = "distribution"`
#'  cumulative distribution function probabilities are estimated.
#' @param normalise Logical that if `TRUE` (the default), scales density estimate
#'  to correct for any estimated negative values.
#' @param nodes Integer vector that corresponds to the number of grid points per
#'   dimension when `X = NULL` and a grid is calculated.
#' @param parallel Logical that if `TRUE` uses the `parallel` package to simulate
#'   values using parallel computing.
#' @param ncores Integer vector that determines the number of cores used in parallel computing.
#' @param mps Integer vector that places a limit on maximum number of probabilities
#'   calculated at a time. The default is 5000.
#'
#' @return `predict.moped()` returns a data frame with estimated density/probability values.
#'
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
#' age  = c(17,80),
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
#' mpo = T
#' )
#'
#' # Define the observation which the probability is desired
#' x0 <- Data_x[1,]
#' pred <- predict(Fit, K= 7, X = x0)
#'
#' # Predicting Marginal Density for a set of observations
#' # When constructing partially joint density, X and variables must be used together.
#  # X must be a data frame and its variable length must equal to the length in var.
#' pred <- predict(Fit, K= 7, X= Data_x[,3:4] , variables =c("jobclass", "wage"))
#' pred <- predict(Fit, K= 7, X= data.frame(wage=Data_x$wage) , variables =c("wage"))
#' pred <- predict(Fit, K= 7, X= data.frame(wage=Data_x$wage) , variables =4 )
#' pred <- predict(Fit, K= c(2,7), X= Data_x[,3:4] , variables =c("jobclass","wage"))
#'
#' # Plotting marginal density
#' predict(Fit, K= 7, variables =4) %>%
#' ggplot(aes(x=wage,y=Density)) +
#' geom_line()
#'
#' # Plotting bivariate density plot
#' predict(Fit, K= c(2,7), variables =3:4) %>%
#' ggplot(aes(x=jobclass,y=wage,fill=Density)) +
#' geom_tile() +
#' scale_fill_distiller(palette = "Spectral")


predict.moped <- function(fit,
                    X = NULL,
                    K=NULL,
                    variables = 1:fit$Nv,
                    bounds = NULL ,
                    type = "density",
                    normalise = T,
                    nodes = 100,
                    parallel = F,
                    ncores = NULL,
                    mps = 5000
){
  if(is.character(variables)){
    variables <-  which(colnames(fit$SampleStats$Sample) %in% variables)
  }
  Nv <- length(variables)
  variables_names <- colnames(fit$SampleStats$Sample)[variables]
  tryCatch(bounds <- setNames(data.frame(bounds[,variables_names]),
                              variables_names),
           error = function(e) bounds <<- NULL)
  if(is.null(bounds)){
    bounds <- as.data.frame(fit$SampleStats$Range[,variables])
    colnames(bounds) <- variables_names
  }

  # X Setup
  if(is.null(X)){
    Grid <- T
    X <- data.frame(expand.grid(lapply(1:length(variables),
          function(i) seq(bounds[1,i],bounds[2,i],length.out = nodes))))
    colnames(X) <- variables_names
    deltaX <- sapply(1:length(variables),function(i) (bounds[2,i] - bounds[1,i])/(nodes - 1))
  }else{
    Grid <- F
  }

  test_names <- prod(variables_names %in% colnames(X)) == 0 | !is.data.frame(X)
  Sample <- X

  if(test_names){
    return(cat("\r Error: Sample must be a data frame and contain columns named ",variables_names))
  } else {
    X <- setNames(data.frame(X[,variables_names]),variables_names)
    #Max Polynomial Order
    if(is.null(K) & !is.null(fit$opt_mpo)) K <- rep(fit$opt_mpo,length(variables))
    if(is.null(K)) K <- rep(fit$KMax,length(variables))
    if(length(K)==1) K <- rep(K,Nv)
    K <- sapply(1:Nv, function(k) min(fit$KMax,K[k]))
    Km <- max(K)

    require(tensor)
    require(R.utils)

    tK <- c(K,rep(0,fit$Nv - Nv))[order(c(variables,setdiff(1:fit$Nv,variables)))]
    #Extract Related Coefficients
    if(fit$Nv==1){
      C <- fit$Cn[1:(Km+1)]
    }else{
      subsetnames <- lapply(1:fit$Nv,function(k) return((0:tK[k])+1))
      C <- aperm(extract.array(fit$Cn,indices = subsetnames), perm = c(variables,setdiff(1:fit$Nv,variables)))
    }
    #Split Grid for allocation (OVERCOME VECTOR ALLOCATION SIZE ISSUES)
    SS <- NROW(X)
    nsplits <- ceiling(SS/mps)
    if(nsplits==1){ splitindex <- list(1:SS) }else{
      splitindex <- lapply(1:nsplits, function(j) (((j-1)*mps)+1):min((j*mps),SS))
    }

    Tgen <- function(j){
      nprobs <- length(splitindex[[j]])
      #Array Definitions
      Km <- max(K) #Max Truncation
      XM <- list() # Array of 1, X, X^2, ....
      P <- list() # Polynomial Terms P_0(X), P_1(X), ...
      PdfTerms <- rep(1,nprobs) # Reference PDF f_v(X)

      for(k in 1:Nv){
        XM[[k]] <- t(sapply(0:Km, function(i) X[splitindex[[j]],k]^i))
        if(length(splitindex[[j]])==1) XM[[k]] <- t(XM[[k]])
        P[[k]] <- fit$PolyCoef[0:K[k]+1,0:K[k]+1,variables[k]]%*%((XM[[k]])[0:K[k]+1,])
        PDFk <- as.function(fit$PDFControl(variables[k])$PDF)
        PdfTerms <- PdfTerms*PDFk(X[splitindex[[j]],k])
      }
      Terms <- c()
      tt <- tensor(C,P[[1]],1,1)
      if(Nv > 1) {
        for(k in 2:Nv){
          if(length(dim(tt))==2){
            tt <- tt*P[[k]]
          }else{
            dimperm <- c(dim(tt)[1],nprobs,dim(tt)[2:(length(dim(tt))-1)])
            tt <- tt*aperm(array(P[[k]],dim = dimperm),perm = c(1,3:length(dimperm),2))
          }
          tt <- apply(tt,2:length(dim(tt)),sum)
        }
      }
      Terms <- c(Terms,tt)
      return(Terms*PdfTerms)
    }
    Tgen_cdf <- function(j){
      nprobs <- length(splitindex[[j]])
      #Array Definitions
      Km <- max(K) #Max Truncation
      XM <- list() # Array of 1, X, X^2, ....
      P <- list() # Polynomial Terms P_0(X), P_1(X), ...

      for(k in 1:Nv){
        CDFk <- as.function(fit$PDFControl(variables[k])$CDF)
        PDFk <- as.function(fit$PDFControl(variables[k])$PDF)
        PDFkX <- PDFk(X[splitindex[[j]],k])
        CDFkX <- CDFk(X[splitindex[[j]],k])
        sigX <-  c(fit$Sigma[,variables[k]]%*%t(cbind((X[splitindex[[j]],k])^2,X[splitindex[[j]],k],1)))
        XM[[k]] <- t(sapply(1:K[k], function(i) i*(X[splitindex[[j]],k]^(i-1)))*sigX*PDFkX)
        if(length(splitindex[[j]])==1) XM[[k]] <- t(XM[[k]])
        P[[k]] <- fit$PolyCoef[1:K[k]+1,1:K[k]+1,variables[k]]%*%((XM[[k]])[1:K[k],])
        P[[k]] <- rbind(CDFkX,P[[k]])/c(1,fit$Lambda[1:K[k],variables[k]])
      }
      Terms <- c()
      tt <- tensor(C,P[[1]],1,1)
      if(Nv > 1) {
        for(k in 2:Nv){
          if(length(dim(tt))==2){
            tt <- tt*P[[k]]
          }else{
            dimperm <- c(dim(tt)[1],nprobs,dim(tt)[2:(length(dim(tt))-1)])
            tt <- tt*aperm(array(P[[k]],dim = dimperm),perm = c(1,3:length(dimperm),2))
          }
          tt <- apply(tt,2:length(dim(tt)),sum)
        }
      }
      Terms <- c(Terms,tt)
      return(Terms)
    }

    if(parallel){
      if(is.null(ncores)) ncores <- detectCores()
      if(type=="distribution"){
        Terms <- unlist(mclapply(1:nsplits,function(j) Tgen_cdf(j),mc.cores = ncores))
      }else{
        Terms <- unlist(mclapply(1:nsplits,function(j) Tgen(j),mc.cores = ncores))
      }
    }else{
      if(type=="distribution"){
        Terms <- unlist(lapply(1:nsplits,function(j) Tgen_cdf(j)))
      }else{
        Terms <- unlist(lapply(1:nsplits,function(j) Tgen(j)))
      }
    }

    Probability <- Terms
    if(normalise){
      Prob_old <- Probability
      Probability[Probability<0] <- 0 #Truncate -ve probabilities
      if(type=="density") norm <- abs(sum(Probability)/sum(Prob_old)) #Rescale
      if(type=="distribution") norm <- max(1,Probability)
    }else{
      norm <- 1
    }
    if(Grid == T & normalise ==T){
      if(type=="density") norm <- sum(Probability)*prod(deltaX)
      if(type=="distribution"){
        Probability <- (Prob_old - min(Prob_old))/(max(Prob_old)-min(Prob_old))
      }
    }

    if(type=="density") Sample$Density <- Probability
    if(type=="distribution") Sample$Prob <- Probability
    return(Sample)
  }

}
