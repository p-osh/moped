#' Fitting multivariate orthogonal polynomial based density estimation.
#'
#' @description
#' `moped()` is used to fit a multivariate orthogonal polynomial-based density
#' estimate. It requires a data frame to fit on data. Categorical variables need
#' to be converted into continuous variables before fitting data to the density
#' estimation.
#'
#' @param Sample A data frame.
#' @param K Integer. Maximum possible Max Polynomial Order of approximation.
#' @param Distrib Character string vector, specifying the reference distribution
#'   to be used for each variable (column) of Sample. Choices are
#'   `"Uniform"` (default), `"Normal"`, `"Gamma"`, and `"Beta"` distributions.
#' @param bounds A data frame. The limits to be used on bounded space. Should be an
#'   array of 2 x number of variables with each column having the lower and
#'   upper limit. `NULL` is the default.
#' @param variance Logical. If `TRUE` (the default), a variance estimate of each
#'   coefficient is calculated.
#' @param recurrence Logical. If `TRUE` (the default), two-term recurrence
#'   relation is not computed.
#' @param opt.mpo Logical. If `TRUE` (the default), an optimal max polynomial order
#'   estimate is estimated using repeated k-fold cross-validation.
#' @param nfolds Integer. If `opt.mpo = TRUE` number of folds (k) to perform in
#'   k-fold cross-validation. Default is 5.
#' @param repeats Integer. If `opt.mpo = TRUE` number of times k-fold
#'   cross-validation is repeated. Default is 10.
#'
#' @returns `moped()` returns a moped (list) object containing:
#' \itemize{
#'   \item `Cn` - Array of estimated moment-based coefficients.
#'   \item `varCn` - Array of variance estimates for Cn. Computed if `variance = TRUE`.
#'   \item `Nv` - Dimension (number of variables) of joint density estimate.
#'   \item `Nk_norm` - Array of estimated shifted Nk Norm values.
#'                     Computed if `opt.mpo = TRUE`.
#'   \item `opt_mpo_vec` - Estimated optimal max polynomial order where K is vector.
#'   \item `opt_mpo` - Estimated optimal max polynomial order where K is constant.
#'   \item `Cats` - List of categorical data information from Sample.
#'   \item `Distrib` - String vector of reference densities used for each variable.
#'   \item `PDFControl` - List of reference density distribution functions.
#'   \item `PolyCoef` - Array of orthogonal polynomial coefficients.
#'   \item `Poly` - Array of orthogonal polynomial values for each obs of Sample.
#'   \item `Sigma` - Array of polynomial coefficients of sigma terms in polynomial.
#'   \item `Tau` - Array of polynomial coefficients of tau terms in polynomial.
#'   \item `Lambda` - Array of lambda terms for each variable.
#'   \item `Limits` - Array of theoretical limits of each variable.
#'   \item `Bounds` - Data frame of the parameter `Bounds`.
#'   \item `LeadingTerms` - List containing leading terms of each polynomial.
#'   \item `KMax` - Maximum max polynomial order (K) specified.
#'   \item `Parameters` - Array of parameters of reference densities.
#'   \item `SampleStats` - List containing original Sample and it's range.
#'   \item `Recurrence` - Optional list of polynomial recurrence relationship terms.
#'                        Computed if `recurrence = TRUE`.
#' }
#'
#' @export
#'
#' @examples
#'
#' require(sdcMicro)
#' Data <- CASCrefmicrodata[,c(2,3,4,6)]
#' str(Data)
#'
#'# Fitting multivariate orthogonal polynomial based
#'# density estimation function using default setting
#'Fit <- moped(Data)
#'
#'# Requires a data frame of bounds to fit on data.
#'bounds <- data.frame(
#'  AGI  = c(7192, 109883),
#'  EMCONTRB = c(17, 7800),
#'  FEDTAX = c(1, 23386),
#'  STATETAX = c(2,12628)
#' )
#'
#' # Fitting the Data
#' Fit <- moped(
#' Data,
#' K=10,
#' Distrib = rep("Uniform", 4),
#' bounds = bounds,
#' variance = T,
#' recurrence = F,
#' opt.mpo = T
#' )
#'
#' Estimated optimal max polynomial order.
#' Fit$opt_mpo


moped <- function(
    Sample,
    K = 10,
    Distrib = rep("Uniform",NCOL(Sample)),
    bounds = NULL,
    variance = TRUE,
    recurrence = FALSE,
    opt.mpo = T,
    nfolds = 5,
    repeats = 10
) {

  require(tensor)
  require(R.utils)
  require(svMisc)

  ###################################
  Cats <- attributes(Sample)$Cats
  Sample <- as.matrix(Sample)
  attr(Sample,"Cats") <- Cats
  Nv <- NCOL(Sample)

  # Array Definitions (Distribution Parameters)
  par <- array(dim = c(2,Nv))
  parnames <- array(dim = c(2,Nv))
  colnames(parnames) <- paste("Variable",1:Nv)
  sigma  <- array(dim = c(3,Nv))
  tau    <- array(dim = c(2,Nv))
  limits <- array(dim = c(2,Nv))

  # Parameter Calculation based on Reference Choice
  for( k in 1:Nv){
    if(Distrib[k]=="Uniform"){
      if(is.null(bounds)){
        par[,k] <- range(Sample[,k],na.rm=T)
      }else{
        par[,k] <- bounds[,k]
      }

      parnames[,k] <- c("UniformMin","UniformMax")

      sigma[,k] = c(1,-sum(par[,k]), prod(par[,k]))
      tau[,k] = c(2, -sum(par[,k]))
      limits[,k] = par[,k]

      PDFControl <- function(k) list(PDF = function(x) dunif(x, par[1,k],par[2,k]),
                                     CDF = function(x) punif(x, par[1,k],par[2,k]))
    } else if (Distrib[k]=="Normal") {
      par[1,k] <- mean(Sample[,k],na.rm=T)
      par[2,k] <- var(Sample[,k],na.rm=T)
      parnames[,k] <- c("NormalMean","NormalVar")

      sigma[,k] = c(0,0,-par[2,k])
      tau[,k] = c(1, -par[1,k])
      limits[,k] = c(-Inf,Inf)

      PDFControl = function(k) list(PDF = function(x) dnorm(x, mean = par[1,k], sd = sqrt(par[2,k])),
                                    CDF = function(x) pnorm(x, mean = par[1,k], sd = sqrt(par[2,k])))
    } else if (Distrib[k]=="Gamma") {
      xbar = mean(Sample[,k],na.rm=T)
      sx2  = var(Sample[,k],na.rm=T)
      par[2,k] <-  xbar/sx2
      par[1,k] <-  xbar*par[2,k]
      parnames[,k] <- c("GammaShape","GammaRate")

      sigma[,k] = c(0,1,0)
      tau[,k] = c(-par[2,k], par[1,k])
      limits[,k] = c(0,Inf)

      PDFControl = function(k) list(PDF = function(x) dgamma(x, shape = par[1,k], rate = par[2,k]),
                                    CDF = function(x) pgamma(x, shape = par[1,k], rate = par[2,k]))
    } else if (Distrib[k]=="Beta"){
      xbar  <- mean(Sample[,k],na.rm=T)
      sx2   <- var(Sample[,k],na.rm=T)
      par[1,k] <- ((xbar^2)*(1-xbar)/sx2) - xbar
      par[2,k] <- (par[1,k]/xbar) - par[1,k]
      parnames[,k] <- c("BetaShape1","BetaShape2")

      sigma[,k] = c(-1,1,0)
      tau[,k] = c(-(par[1,k]+par[2,k]), par[1,k])
      limits[,k] = c(0,1)

      PDFControl = function(k) list(PDF = function(x) dbeta(x, shape1 = par[1,k], shape2 = par[2,k]),
                                    CDF = function(x) pbeta(x, shape1 = par[1,k], shape2 = par[2,k]))
    }
  }

  PDFControl <- function(k){
    if(Distrib[k]=="Uniform"){
      return(list(PDF = function(x) dunif(x, par[1,k],par[2,k]),
                  CDF = function(x) punif(x, par[1,k],par[2,k]),
                  norm = function(n) ((-1)^n)*((par[2,k]-par[1,k])^(2*n))*beta(n+1,n+1)))
    } else if (Distrib[k]=="Normal") {
      return(list(PDF = function(x) dnorm(x, mean = par[1,k], sd = sqrt(par[2,k])),
                  CDF = function(x) pnorm(x, mean = par[1,k], sd = sqrt(par[2,k])),
                  norm = function(n) ((-par[2,k])^n)))
    } else if (Distrib[k]=="Gamma") {
      return(list(PDF = function(x) dgamma(x, shape = par[1,k], rate = par[2,k]),
                  CDF = function(x) pgamma(x, shape = par[1,k], rate = par[2,k]),
                  norm = function(n) (par[2,k]^(-n))*gamma(par[1,k]+n)/gamma(par[1,k]) ))
    } else if (Distrib[k]=="Beta"){
      return(list(PDF = function(x) dbeta(x, shape1 = par[1,k], shape2 = par[2,k]),
                  CDF = function(x) pbeta(x, shape1 = par[1,k], shape2 = par[2,k]),
                  norm = function(n) beta(par[1,k]+n,par[2,k]+n)/(beta(par[1,k],par[2,k]))))
    }
  }
  ####################

  # Polynomial Constants calculation
  # Array Definitions
  Bn <- array(dim=c(K+1,Nv))     #Polynomial Coefficient
  Kappa <- array( dim = c(K+1,Nv)) #Leading Term Coefficient
  Kappa2 <- array( dim = c(K,Nv)) #Second Term Coefficient
  lambda <- array( dim = c(K+1,Nv)) #Eigenvalues

  #Recurrence Coefficients Pn+1 = (Rn x + Sn) Pn + Tn Pn-1
  Rn <- array( dim = c(K,Nv))
  Sn <- array( dim = c(K,Nv))
  Tn <- array( dim = c(K,Nv))

  #Bn Calculator
  Bnfunction <- function(k,n){
    PDF <- PDFControl(k)$PDF
    #norm <- integrate(function(x) Vectorize(((sigma[1,k]*x^2 + sigma[2,k]*x +sigma[3,k])^n)*PDF(x)),limits[1,k],limits[2,k])$value
    if(Distrib[k]=='Uniform'){
      return(exp(0.5*log(2*n+1)- n*log(par[2,k] - par[1,k])-sum(log(1:n))))
    }else{
      lead <- prod(sapply(0:(n-1), function(i) tau[1,k] + (n+i-1)*sigma[1,k]))
      if(lead == 0) lead <- 1
      norm <- PDFControl(k)$norm(n)
      Bnterm <- 1/sqrt(abs(lead*factorial(n)*norm))
    }
    return(Bnterm)
  }

  #Constant Calculations
  for(k in 1:Nv){
    Bn[1,k] <- Bnfunction(k,1)
    Kappa[1,k] <- Bn[1,k]*tau[1,k]
    lambda[1,k] <- tau[1,k]
  }

  for(n in 1:K){
    Bn[n+1,] <-  sapply(1:Nv, function (k) Bnfunction(k,n+1))

    Kappa[n+1,] <- sapply(1:Nv, function(k){
      if(Distrib[k]=='Uniform'){
        return(exp(sum(log(1+(n+1)/(1:(n+1))))-(n+1)*log(par[2,k]-par[1,k])+0.5*log(2*n+3)))
      }else{
        return(Bn[n+1,k]*prod(sapply(0:n, function(i) tau[1,k] + (n+i)*sigma[1,k]) ))
      }
    })

    Kappa2[n,] <- sapply(1:Nv, function(k) Kappa[n,k]*(n*(n-1)*sigma[2,k] + n*tau[2,k])/(tau[1,k] + 2*(n-1)*sigma[1,k]))
    lambda[n+1,] <- sapply(1:Nv, function(k) (n+1)*tau[1,k] + sigma[1,k]*n*(n+1))
    if(recurrence){
    Rn[n,] <- sapply(1:Nv, function(k) Kappa[n+1,k]/Kappa[n,k])
    Sn[n,] <- sapply(1:Nv, function(k) Rn[n,k]*(tau[2,k]*(tau[1,k]-2*sigma[1,k])+ sigma[2,k]*
                                                  (2*tau[1,k]+2*n*(n-1)*sigma[1,k]))/((tau[1,k]+2*n*sigma[1,k])*(tau[1,k] + 2*(n-1)*sigma[1,k])))
    if(n==1){
      Tn[n,] <- sapply(1:Nv, function(k) n*((tau[1,k]+2*n*sigma[1,k])/(2*(tau[1,k]+2*(n-1)*sigma[1,k])*(tau[1,k] + (n-1)*sigma[1,k])))*
                         (Bn[n+1,k])*(2*tau[1,k]*(sigma[3,k]*tau[1,k] - sigma[2,k]*(tau[2,k] + (n-1)*sigma[2,k])) +
                                        2*sigma[1,k]*(tau[2,k]^2 - ((n-1)^2)*sigma[2,k]^2 + 4*(n-1)*sigma[3,k]*(tau[1,k] + sigma[1,k]*(n-1)))))
    }else {
      Tn[n,] <- sapply(1:Nv, function(k) n*((tau[1,k]+2*n*sigma[1,k])/(2*(tau[1,k]+2*(n-1)*sigma[1,k])*(tau[1,k] + (n-1)*sigma[1,k])))*
                         (Bn[n+1,k]/Bn[n-1,k])*(2*tau[1,k]*(sigma[3,k]*tau[1,k] - sigma[2,k]*(tau[2,k] + (n-1)*sigma[2,k])) +
                                                  2*sigma[1,k]*(tau[2,k]^2 - ((n-1)^2)*sigma[2,k]^2 + 4*(n-1)*sigma[3,k]*(tau[1,k] + sigma[1,k]*(n-1)))))
    }
    }
   # K[which(sapply(1:Nv, function(k) Bn[n,k] == 0 && Bn[n-1,k] != 0 ))] <- n
    if(K < n) break
  }

  an <- function(k,n){
    aterm <- array(dim = n+1)
    if (n==0) return(1) else if (n==1) return(c(Kappa2[1,k],Kappa[1,k])) else{
      aterm[n+1] <- Kappa[n,k]
      aterm[n] <- Kappa2[n,k]
      for(i in ((n-2):0)){
        aterm[i+1] <- ((i+1)*(i*sigma[2,k]+tau[2,k])*aterm[i+2] + (i+2)*(i+1)*sigma[3,k]*aterm[i+3])/(lambda[n,k] - i*(i-1)*sigma[1,k] - i*tau[1,k])
      }
      return(aterm)
    }
  }
  #Polynomial Coefficient Arrays
  A <- array(dim= c(rep(K+1,2),Nv))
  #Construct Indice Array
  for (i in 0:K)
    for (k in 1:Nv){
      A[i+1, ,k] <- c(an(k,i),rep(0,K-i))
    }

  #######################################################################################
  Poly <- array(0,dim = c(K+1,NROW(Sample),Nv))

  for(k in 1:Nv){
      XMk <- t(sapply(0:K, function(i) Sample[,k]^i))
      Poly[0:K+1,,k] <- A[0:K+1,0:K+1,k]%*%(XMk[0:K+1,])
    }
  Poly[1,,] <- array(1,dim = dim(Poly[1,,]))

  if(opt.mpo){
    calc_cn <- validate.mpo(list(Poly=Poly),K=K,variance = variance,nfolds = nfolds,repeats = repeats)
  }else{
    calc_cn <- validate.mpo(list(Poly=Poly),K=K,variance = variance,nfolds = 1,repeats = 1)
  }


  if(Nv==1)   lam <- array(lambda[-((K+1):NROW(lambda)),],dim =c(rep(K,Nv),1)) else  lam <- lambda[-((K+1):NROW(lambda)),]

  output <- list(Cn = calc_cn$Cn, varCn = calc_cn$varCn,Nv=Nv, Nk_norm = calc_cn$Nk_norm,
                 opt_mpo_vec = calc_cn$opt_mpo_vec, opt_mpo = calc_cn$opt_mpo,
                 Cats = Cats, Distrib = Distrib, PDFControl = PDFControl,
                 PolyCoef = A, Poly = Poly,
                 Sigma = sigma, Tau = tau, Lambda = lam, Limits = limits,
                 LeadingTerms = list(Bn = rbind(rep(1,Nv),Bn[-(K:NROW(lambda)+1),]),
                 Kappa = Kappa, Kappa2 = Kappa2), KMax = K, Paramaters = par, Bounds = bounds,
                 SampleStats = list(Range = sapply(1:Nv,function(k) range(Sample[,k],na.rm = T)),
                                    Sample = data.frame(Sample)))
  if(recurrence){
  output$Recurrence = list(Rn = Rn[-((K):NROW(lambda)),],
                           Sn = Sn[-((K):NROW(lambda)),],
                           Tn = Tn[-((K):NROW(lambda)),])
  }
  class(output) <- "moped"
  return(output)
}

