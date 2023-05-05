#' Calculate univariate marginal probabilities
#'
#' @description
#' `estimate.marg.cdf()` calculates univariate marginal cumulative probabilities
#' and the coefficients of the polynomial approximation from a `moped` object.
#'
#'
#' @param fit moped type variable outputted from `moped()`.
#' @param X vector of values to predict the marginal probability. Not required
#'   for variables with "Uniform" reference densities to compute coefficients.
#' @param K integer maximum polynomial order of approximation on marginal
#'   variable. Must be less than or equal to the maximum MPO K specified in
#'   `moped()`.The default is the `opt_mpo` or `KMax` (if `opt_mpo = NULL`)
#'   specified in `fit`.
#' @param nprobs integer of number of probability coefficients replications to be
#'   outputted. Used when `X = NULL` for variables with `"Uniform"` reference
#'   densities. The default value is 1 (no replications).
#' @param variable integer or string of variable name corresponding to which
#'   marginal variable position or name to be predicted from `moped` object.
#'
#' @return `estimate.marg.cdf()` returns a list with the following components:
#' \itemize{
#'   \item `Prob` - vector of computed probabilities when X is specified.
#'   \item `coef` - An array of coefficients of the polynomial approximation.
#'                  When variable reference density is "Uniform", coefficients
#'                  are not specific for each value of X.
#' }
#' @export
#'
#' @examples
#' require(ISLR)
#' Data_full <- Wage
#'
#' require(tidyverse)
#' Data <- Data_full %>%
#' select(age, education, jobclass,wage)
#'
#' # Convert Categorical Data to Continuous Data
#' Data_x <- make.cont(Data, catvar = 2:3)
#'
#' # Fitting multivariate orthogonal polynomial based
#' # density estimation function
#'
#' # Fitting the Data
#' Fit <- moped(Data_x)
#'
#' # Compute marginal distribution function probabilities of "wage"
#' x <- seq(21,310,length.out = 100)
#' wage_prob <- estimate.marg.cdf(Fit, X = x, K = 10, variable = "wage")




estimate.marg.cdf <- function(fit,
                             X = NULL,
                             K = NULL,
                             nprobs = 1,
                             variable = 1
){
  if(is.character(variable)){
    variable <-  which(colnames(fit$SampleStats$Sample) %in% variable)
  }
  if(is.null(X) & fit$Distrib[variable] != "Uniform"){
    stop("Non-uniform approximations require numeric values for X.")
  }
  if(is.null(K)) K <- fit$opt_mpo
  if(is.null(K)) K <- fit$KMax
  if(!is.null(X)) nprobs <- NROW(X)
  requireNamespace("R.utils")
  subsetnames <- lapply(1:NCOL(fit$SampleStats$Sample),function(k)1)
  subsetnames[[variable]] <- 1:K+1
  if(is.vector(fit$Cn)){
    C <- fit$Cn[1:K+1]%o%array(1,dim=c(nprobs))
  }else{
    C <- c(extract.array(fit$Cn,indices = subsetnames))%o%array(1,dim=c(nprobs))
  }
  XDP <- (fit$PolyCoef[2:(K+1),2:(K+1),variable]/fit$Lambda[1:K,variable])*
    t(array(1:K,dim = rep(K,2)))
  if(fit$Distrib[variable]=="Uniform"){
    fnu <- 1/(fit$Paramaters[2,variable]-fit$Paramaters[1,variable])
    E <- t(t(XDP)%*%C)*fnu
    coef <- cbind(fit$Sigma[3,variable]*E,0,0) + cbind(0,fit$Sigma[2,variable]*E,0) + cbind(0,0,fit$Sigma[1,variable]*E)
    coef[,1] <- coef[,1]-fit$Paramaters[1,variable]/
      (fit$Paramaters[2,variable]-fit$Paramaters[1,variable])
    coef[,2] <- coef[,2]+1/(fit$Paramaters[2,variable]-fit$Paramaters[1,variable])
  }else{
    fnu <- fit$PDFControl(variable)$PDF(X)
    Fnu <- fit$PDFControl(variable)$CDF(X)
    E <- t(t(XDP)%*%C)*fnu
    coef <- cbind(fit$Sigma[3,variable]*E,0,0) + cbind(0,fit$Sigma[2,variable]*E,0) + cbind(0,0,fit$Sigma[1,variable]*E)
    coef[,1] <- coef[,1] + Fnu
  }
  if(is.null(X)){
    return(list(coef = coef))
  }else{
    Prob <- apply(coef*(sapply(0:(K+1),function(k)X^k)),1,sum)
    names(Prob) <- names(X)
    return(list(Prob = Prob,coef = coef))
  }
}
