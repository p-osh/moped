#' Computes moped estimated conditional distribution function values for X|Y1,Y2,...
#'
#' @description
#' `estimate.conditional()` is used to compute moped estimated conditional
#' distribution function values for a single variable X given a data frame of
#' conditional Y values.
#'
#' @param fit `moped` type variable outputted from `moped()`.
#' @param X Vector of values with which to estimate conditional probabilities.
#'  `X` must have length consistent with number of observations in `Y`.
#'  `X` is optional when reference density of X variable is "Uniform" and only
#'  approximation polynomial coefficients are to be determined.
#' @param K.X Integer maximum polynomial order of approximation on X variable.
#'  Must be less than or equal to the maximum MPO K specified in `moped()`.
#'  The default is the `opt_mpo` or `KMax` (if `opt_mpo = NULL`) specified
#'   in `fit`.
#' @param Y A data frame in which to look for conditional (Y) variables with which
#'  to estimate probability values. Must contain column names matching variables in
#'  the `moped` object.
#' @param K.Y  Integer vector maximum polynomial order of approximation on each
#'   conditional variable. Must be less than or equal to the maximum MPO K specified
#'   in `moped()`. The default is the `opt_mpo` or `KMax` (if `opt_mpo = NULL`) specified
#'   in `fit`.
#' @param X.variable Integer or character string of variable name corresponding to the
#'   `moped` position or column name of the variable to be predicted from
#'   `moped` object. The default is 1 (first variable in `fit`).
#' @param Y.variables Integer vector or character string of variable names corresponding
#'  to the `moped` position or column name of the variable(s) to be conditioned on from
#'   `moped` object. If `NULL` conditions on all non `X.variable` variables.
#'
#' @return `estimate.conditional()` returns a list with the following components:
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
#' # Compute moped conditional distribution estimate
#' cond_pred <- estimate.conditional(Fit,
#' X=seq(20,300,length.out=100),
#' Y = x0[rep(1,100),-4],
#' K.Y=rep(7,3),
#' K.X=7,
#' X.variable = "wage",
#' Y.variables = c("age","education","jobclass"))




estimate.conditional <- function(fit,
                                X = NULL,
                                K.X=NULL,
                                Y,
                                K.Y=NULL,
                                X.variable = NULL,
                                Y.variables = NULL){
  tNv <- fit$Nv
  tKm <- fit$KMax
  if(is.null(X.variable)) X.variable <- 1
  try(if(is.null(X) & fit$Distrib[X.variable] != "Uniform"){
    return(cat("Error: Non-uniform approximations require numeric values for X."))
  }else{
  if(is.null(Y.variables)) Y.variables <- setdiff(1:tNv,X.variable)
  Y.Nv <- length(Y.variables)
  if(is.null(K.X)) K <- fit$opt_mpo
  if(is.null(K.X)) K <- fit$KMax
  if(is.null(K.Y) & !is.null(fit$opt_mpo)) K.Y <- rep(fit$opt_mpo,Y.Nv)
  if(is.null(K.Y)) K.Y <- rep(tKm,Y.Nv)
  if(length(K.Y) != Y.Nv) K.Y <- rep(K.Y[1], Y.Nv)

  if(is.character(X.variable)){
    X.variable <-  which(colnames(fit$SampleStats$Sample) %in% X.variable)
  }
  if(is.character(Y.variables)){
    Y.variables <-  which(colnames(fit$SampleStats$Sample) %in% Y.variables)
  }

  nprobs <- NROW(Y)
  tvariables <- c(c(Y.variables,X.variable),setdiff(1:tNv,c(Y.variables,X.variable)))

  fY <- predict(fit,X = Y,K=K.Y,normalise = F,variables = Y.variables)
  Y.poly <- polynomial(fit,X = Y,K=K.Y,variables = Y.variables)

  Y.variables_names <- colnames(fit$SampleStats$Sample)[Y.variables]
  Y <- setNames(data.frame(Y[,Y.variables_names]),Y.variables_names)

  Km <- max(K.Y,K.X)
  XDP <- (fit$PolyCoef[2:(K.X+1),2:(K.X+1),X.variable]/
            fit$Lambda[1:K.X,X.variable])*
    t(array(1:Km,dim = rep(K.X,2)))

  tK <- c(c(K.Y,K.X),rep(0,tNv - Y.Nv-1))[order(tvariables)]

  bK <- rep(0,tNv)
  bK[X.variable] <- 1

  subsetnames <- lapply(1:tNv,function(k) return((bK[k]:tK[k])+1))
  C <- aperm(extract.array(fit$Cn,indices = subsetnames), perm = tvariables)
  C <- array(C,dim = c(dim = c(K.Y+1,K.X)))

  tt <- tensor(C,Y.poly$P[[1]],1,1)

  if(Y.Nv > 1) {
    for(k in 2:Y.Nv){
      dimperm <- c(dim(tt)[1],nprobs,dim(tt)[2:(length(dim(tt))-1)])
      tt <- tt*aperm(array(Y.poly$P[[k]],dim = dimperm),perm = c(1,3:length(dimperm),2))
      tt <- apply(tt,2:length(dim(tt)),sum)
    }
  }
  if(fit$Distrib[X.variable]=="Uniform"){
    fnu <- 1/(fit$Paramaters[2,X.variable]-fit$Paramaters[1,X.variable])
    E <- t(t(XDP)%*%tt)*Y.poly$PdfTerms*fnu/fY$Density
    coef <- cbind(fit$Sigma[3,X.variable]*E,0,0) + cbind(0,fit$Sigma[2,X.variable]*E,0) + cbind(0,0,fit$Sigma[1,X.variable]*E)
    coef[,1] <- coef[,1]-fit$Paramaters[1,X.variable]/
      (fit$Paramaters[2,X.variable]-fit$Paramaters[1,X.variable])
    coef[,2] <- coef[,2]+1/(fit$Paramaters[2,X.variable]-fit$Paramaters[1,X.variable])
  }else{
    fnu <- fit$PDFControl(X.variable)$PDF(X)
    Fnu <- fit$PDFControl(X.variable)$CDF(X)
    E <- t(t(XDP)%*%tt)*Y.poly$PdfTerms*fnu/fY$Density
    coef <- cbind(fit$Sigma[3,X.variable]*E,0,0) + cbind(0,fit$Sigma[2,X.variable]*E,0) + cbind(0,0,fit$Sigma[1,X.variable]*E)
    coef[,1] <- coef[,1] + Fnu
  }
  if(is.null(X)){
    return(list(coef = coef))
  }else{
    Prob <- apply(coef*(sapply(0:(K.X+1),function(k)X^k)),1,sum)
    return(list(Prob = Prob,coef = coef))
  }
  })
}
