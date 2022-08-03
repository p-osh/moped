#' Compute unscaled MBD conditional distribution estimate
#'
#' @description
#' `predict.conditional()` is used to compute unscaled MBD conditional
#' distribution estimate.
#'
#' @param fit MBDensity type variable. Outputed from `moped()`.
#' @param X Grid of probabilities to be calculated. If `NULL` (the default) than
#'   generates nodes x Nv grid.
#' @param K.X Truncation to be used. If `NULL`( the default). it is max in Fit.
#' @param Y Grid of probabilities to be calculated. If `NULL` (the default),
#'   than generates nodes x Nv grid.
#' @param K.Y Which variables to be predicted from Fit. If `NULL` (the default),
#'   it is 1:Nv or 1:NCOL(X) whichever smallest.
#' @param X.variable (?Brad)
#' @param Y.variables (?Brad)
#' @param X.bounds A data frame. Bounds allows you to control the grid min and
#'   Should be an array of 2 x number of variables.
#' @param Y.bounds (?Brad)
#'
#' @return `predict.conditional()` returns a list object
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
#' # Compute MBD Conditional Distribution Estimate (unscaled)
#' Cond.prob <- predict.conditional(Fit,
#' X=seq(20,300,length.out=100),
#' Y = x0[rep(1,100),-4],
#' K.Y=rep(7,3),
#' K.X=c(7),
#' X.bounds = data.frame(wage=bounds$wage),
#' Y.bounds = bounds[,-4],
#' X.variable = 4,
#' Y.variables = 1:3)
#'
#' plot(seq(20, 300, length.out = 100), Cond.prob$Prob)






predict.conditional <- function(fit,
                                X = NULL,
                                K.X=NULL,
                                Y,
                                K.Y=NULL,
                                X.variable = NULL,
                                Y.variables = NULL,
                                X.bounds = NULL ,
                                Y.bounds= NULL){
  tNv <- length(fit$KMax)
  tKm <- max(fit$KMax)
  if(is.null(X.variable)) X.variable <- 1
  try(if(is.null(X) & fit$Distrib[X.variable] != "Uniform"){
    return(cat("Error: Non-uniform approximations require numeric values for X."))
  }else{
  if(is.null(Y.variables)) Y.variables <- setdiff(1:tNv,X.variable)
  if(is.null(X.bounds)) X.bounds <- fit$SampleStats$Range[,X.variable]
  if(is.null(Y.bounds)) Y.bounds <- sapply(Y.variables, function(i) fit$SampleStats$Range[,i])
  Y.Nv <- length(Y.variables)
  if(is.null(K.X)) K.X <- tKm
  if(is.null(K.Y)) K.Y <- rep(tKm,Y.Nv)
  if(length(K.Y) != Y.Nv) K.Y <- rep(K.Y[1], Y.Nv)

  nprobs <- NROW(Y)
  tvariables <- c(c(Y.variables,X.variable),setdiff(1:tNv,c(Y.variables,X.variable)))

  fY <- predict(fit,Sample = Y,K=K.Y,normalise = F,
                bounds = Y.bounds,variables = Y.variables)
  Y.poly <- polynomial(fit,X = Y,K=K.Y,
                       bounds = Y.bounds,variables = Y.variables)

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
      dimperm = c(dim(tt)[1],nprobs,dim(tt)[2:(length(dim(tt))-1)])
      tt = tt*aperm(array(Y.poly$P[[k]],dim = dimperm),perm = c(1,3:length(dimperm),2))
      tt = apply(tt,2:length(dim(tt)),sum)
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
    return(list(coef = coef, E = E))
  }else{
    Prob <- apply(coef*(sapply(0:(K.X+1),function(k)X^k)),1,sum)
    return(list(coef = coef, E = E,Prob = Prob))
  }
  })
}
