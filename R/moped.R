#' Fitting multivariate orthogonal polynomial based density estimation.
#'
#' @description
#' `moped()` is used to fit a multivariate orthogonal polynomial-based density
#' estimate. It requires a data frame to fit on data. Categorical
#' variables need to be converted into continuous variables before fitting data
#' to the density estimation.
#'
#' @param Sample A data frame.
#' @param K Integer vector. Maximum Polynomial Order of approximation on each 
#'   variable.
#' @param Distrib Character string vector, specifying the reference distribution 
#'   to be used for each variable (column) of Sample. Choices are 
#'   `"Uniform"` (default), `"Normal"`, `"Gamma"`, and `"Beta"` distributions.
#' @param bounds A data frame. The limits to be used on bounded space. Should be an
#'   array of 2 x number of variables with each column having the lower and
#'   upper limit. `NULL` is the default.
#' @param ListP Logical. If `FALSE` (the default), a list of polynomial terms
#'   for each observation of Sample is computed and returned. 
#' @param variance Logical. If `TRUE` (the default), a variance estimate of each
#'   coefficient is calculated.
#' @param recurrence Logical. If `FALSE` (the default), two-term recurrence 
#'   relation is not used to determine estimated coefficients.
#' @param parallel Logical. If `FALSE` (the default), parallel computing is not
#'   used.
#' @param ncores Integer vector. Number of cores used in parallel computing.
#' @param mpo Logical. If `TRUE` (the default), an optimal max polynomial order 
#' estimate is calculated using cross-validation. 
#'
#' @returns `moped()` returns a moped (list) object containing:
#' \itemize{
#'   \item `Cn` - Array of estimated moment-based coefficients.
#'   \item `varCn` - Array of variance estimates for Cn computed if `variance = TRUE`.
#'   \item `Cats` - List of categorical data information from Sample.
#'   \item `MPO` - List of estimated optimal max polynomial order information.
#'   \item `PolyCoef` - Array of orthogonal polynomial coefficients.
#'   \item `Poly` - Array of orthogonal polynomial values for each obs of Sample. 
#'   \item `Distrib` - String vector of reference densities used for each variable. 
#'   \item `PDFControl` - List of reference density distribution functions. 
#'   \item `Sigma` - Array of polynomial coefficients of sigma terms in polynomial. 
#'   \item `Tau` - Array of polynomial coefficients of tau terms in polynomial. 
#'   \item `Limits` - Array of theoretical limits of each variable.
#'   \item `Bounds` - Data frame of the parameter `Bounds`.
#'   \item `PnList` - List of polynomial terms computed if `ListP = TRUE`.
#'   \item `Lambda` - Array of lambda terms for each variable.
#'   \item `Bn` - Array of Bn terms for each variable.
#'   \item `Kappa` - Array of leading polynomial coefficients for each variable.
#'   \item `Kappa2` - Array of second leading polynomial coefficients for each variable.
#'   \item `Recurrence` - List of polynomial recurrence relationship values. 
#'   \item `KMax` - Maximum max polynomial order (K) specified. 
#'   \item `Parameters` - Array of parameters of reference densities.
#'   \item `SampleStats` - List containing Range, Sample, and NaTerms on `Sample`.
#' }
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
#' mpo = T
#' )
#'
#' Estimated optimal max polynomial order. 
#' Fit$MPO$opt.mpo


moped <- function(
    Sample, 
    K = rep(15,NCOL(Sample)),
    Distrib = rep("Uniform",NCOL(Sample)), 
    bounds = NULL, 
    ListP = FALSE, 
    variance = TRUE,
    recurrence = FALSE,
    parallel = FALSE,
    ncores = NULL,
    mpo = TRUE
) {

  require(tensor)
  require(R.utils)
  require(svMisc)

  ###################################
  Cats <- attributes(Sample)$Cats
  Sample <- as.matrix(Sample)
  attr(Sample,"Cats") <- Cats
  Nv <- NCOL(Sample)
  if(NROW(K)==NCOL(K) && NROW(K) == 1) K <- rep(K,Nv)  #Ensures K is Nv vector if constant used in Input

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
  Bn <- array(dim=c(max(K)+1,Nv))     #Polynomial Coefficient
  Kappa <- array( dim = c(max(K)+1,Nv)) #Leading Term Coefficient
  Kappa2 <- array( dim = c(max(K),Nv)) #Second Term Coefficient
  lambda <- array( dim = c(max(K)+1,Nv)) #Eigenvalues

  #Recurrence Coefficients Pn+1 = (Rn x + Sn) Pn + Tn Pn-1
  Rn <- array( dim = c(max(K),Nv))
  Sn <- array( dim = c(max(K),Nv))
  Tn <- array( dim = c(max(K),Nv))

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

  for(n in 1:max(K)){
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
    K[which(sapply(1:Nv, function(k) Bn[n,k] == 0 && Bn[n-1,k] != 0 ))] <- n
    if(max(K) < n) break
  }
  Km <- max(K)
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
  A <- array(dim= c(rep(Km+1,2),Nv))
  #Construct Indice Array
  for (i in 0:Km){ for (k in 1:Nv){
    A[i+1, ,k] <- c(an(k,i),rep(0,Km-i)) }}

  #######################################################################################
  Poly <- array(0,dim = c(Km+1,NROW(Sample),Nv))

  if(recurrence){
    Pn2 <- array(1,dim = c(NROW(Sample),Nv))
    Pn1 <-  t(array(Kappa2[1,],dim = c(Nv,NROW(Sample)))) +
      t(array(Kappa[1,],dim = c(Nv,NROW(Sample))))*Sample
    Poly[1,,] <- Pn2
    Poly[2,,] <- Pn1
    for(i in 1:(Km-1)){
      Pn <- (t(array(Rn[i,],dim = c(Nv,NROW(Sample))))*Sample +
               t(array(Sn[i,],dim = c(Nv,NROW(Sample)))))*Pn1 +
        t(array(Tn[i,],dim = c(Nv,NROW(Sample))))*Pn2
      Pn2 <- Pn1
      Pn1 <- Pn
      Poly[2+i,,] <- Pn
    }}else{
      Km <- max(K)
      for(k in 1:Nv){
        XMk <- t(sapply(0:Km, function(i) Sample[,k]^i))
        Poly[0:K[k]+1,,k] <- A[0:K[k]+1,0:K[k]+1,k]%*%(XMk[0:K[k]+1,])
      }
      Poly[1,,] <- array(1,dim = dim(Poly[1,,]))
    }

  if(ListP){
    Pngen <- function(j){
      TempPoly <- Poly[0:K[1]+1,j,1]
      if(Nv>1) for(k in 2:Nv) TempPoly <-TempPoly%o%Poly[0:K[k]+1,j,k]
      TempPoly[is.na(TempPoly)] <- 0
      return(TempPoly)
    }
    if(parallel){
      library(parallel)
      if(is.null(ncores)) {ncores = detectCores()}
      PnList <- mclapply(1:NROW(Sample),function(j) Pngen(j),mc.cores = ncores)
    }else(
      PnList <- lapply(1:NROW(Sample),function(j) Pngen(j))
    )
    Cn <- 0
    Csplit1 <- 0
    Csplit2 <- 0
    NaTerms <- 0
    NaTerms1 <- 0
    NaTerms2 <- 0

    if(variance) Cn2 <- 0
    if(mpo) split <- sample(1:NROW(Sample), floor(NROW(Sample)/2),replace = F)
    for(j in 1:NROW(Sample)){
      Cn <- Cn+PnList[[j]]
      NaTerms <- NaTerms + is.na(PnList[[j]])
      if(variance) Cn2 <- Cn2 + PnList[[j]]^2
      if (mpo) {
        if (j %in% split) {
          NaTerms1 <- NaTerms1 + is.na(PnList[[j]])
          Csplit1 <- Csplit1 + PnList[[j]]
        } else{
          NaTerms2 <- NaTerms2 + is.na(PnList[[j]])
          Csplit2 <- Csplit2 + PnList[[j]]
        }
      }
    }
    Cn <- Cn/(NROW(Sample) - NaTerms)
    Cn2 <- Cn2/(NROW(Sample) - NaTerms)
    Csplit1 <- Csplit1/(length(split) - NaTerms1)
    Csplit2 <- Csplit2/(NROW(Sample)-length(split) - NaTerms2)
    if(variance) varCn <- Cn2- Cn^2 else varCn <- 0
  }else{
    PnList = NULL
    Cn <- array(0,dim = K+1)
    if(variance) Cn2 <- array(0,dim = K+1)

    if(mpo){
      split <- sample(1:NROW(Sample), floor(NROW(Sample)/2),replace = F)
      Csplit1 <- array(0,dim = K+1)
      Csplit2 <- array(0,dim = K+1)
    }

    if(parallel){
      require(parallel)
      spindex <- suppressWarnings(split(1:NROW(Sample),1:ncores))
      sploop <- function(s) {
        for (j in spindex[[s]]) {
          TempPoly <- Poly[0:K[1] + 1, j, 1]
          if (Nv > 1)
            for (k in 2:Nv)
              TempPoly <- TempPoly %o% Poly[0:K[k] + 1, j, k]
          Cn <- Cn + TempPoly / NROW(Sample)
          if (variance)
            Cn2 <- Cn2 + TempPoly ^ 2 / NROW(Sample)

          if (mpo) {
            if (j %in% split) {
              Csplit1 <- Csplit1 + TempPoly / length(split)
            } else{
              Csplit2 <- Csplit2 + TempPoly / (NROW(Sample) - length(split))
            }
          }
          # progress(100 * j / NROW(Sample))
        }
        return(list(Cn,Cn2,Csplit1,Csplit2))
      }
      Cn <- 0
      Cn2 <- 0
      Csplit1 <- 0
      Csplit2 <- 0
      splist <- mclapply(1:ncores,function(s) sploop(s),mc.cores = ncores)
      for(j in 1:ncores){
        Cn <- Cn + splist[[j]][[1]]
        Cn2 <- Cn2 + splist[[j]][[2]]
        Csplit1 <- Csplit1 + splist[[j]][[3]]
        Csplit2 <- Csplit2 + splist[[j]][[4]]
      }
      rm(splist)
    }else{
      NaTerms <- 0
      NaTerms1 <- 0
      NaTerms2 <- 0

      for (j in 1:NROW(Sample)) {
        TempPoly <- Poly[0:K[1] + 1, j, 1]
        if (Nv > 1)
          for (k in 2:Nv)
            TempPoly <- TempPoly %o% Poly[0:K[k] + 1, j, k]
        NaTerms <- NaTerms + is.na(TempPoly)
        TempPoly[is.na(TempPoly)] <- 0
        Cn <- Cn + TempPoly
        if (variance)
          Cn2 <- Cn2 + TempPoly ^ 2

        if (mpo) {
          if (j %in% split) {
            NaTerms1 <- NaTerms1 + is.na(TempPoly)
            Csplit1 <- Csplit1 + TempPoly
          } else{
            NaTerms2 <- NaTerms2 + is.na(TempPoly)
            Csplit2 <- Csplit2 + TempPoly
          }
        }
        progress(100 * j / NROW(Sample))
      }
      Cn <- Cn/(NROW(Sample)-NaTerms)
      if(variance) Cn2 <- Cn2/(NROW(Sample)-NaTerms)
      if(mpo){
        Csplit1 <- Csplit1/(length(split) - NaTerms1)
        Csplit2 <- Csplit2/ (NROW(Sample) - length(split) - NaTerms2)
      }
    }
  }
  if(variance) varCn <- Cn2 - Cn^2 else varCn <- 0
  if(mpo){
    cumsumer <- function(Array){
      Nv <- length(dim(Array))
      if(Nv>1){
        for(k in 1:Nv){
          Tperm <- order(c(k,setdiff(1:Nv,k)))
          Array <- apply(Array,setdiff(1:Nv,k),cumsum)
          Array <- aperm(Array, perm = Tperm)
        }}else{
          Array <- cumsum(Array)
        }
      return(Array)
    }
    normval <- cumsumer(Csplit1^2 - 2*Csplit1*Csplit2)
    minnorm <- min(normval,na.rm = T)
    opt.mpo <- (which(normval == minnorm,arr.ind = T)-1)

    MPO <- list(opt.mpo = opt.mpo, normval = normval, minnorm = minnorm)
  }else{
    MPO <- NULL
  }

  if(Nv==1)   lam <- array(lambda[-(max(K+1):NROW(lambda)),],dim =c(K,1)) else  lam <- lambda[-(max(K+1):NROW(lambda)),]

  output <- list(Cn = Cn, varCn = varCn, Cats = Cats, MPO = MPO,
                 PolyCoef = A, Poly = Poly,
                 Distrib = Distrib, PDFControl = PDFControl,
                 Sigma = sigma, Tau = tau, Limits = limits, 
                 Bounds = bounds, PnList = PnList,
                 Lambda = lam, Bn = rbind(rep(1,Nv),Bn[-(max(K):NROW(lambda)+1),]),
                 Kappa = Kappa, Kappa2 = Kappa2,
                 Recurrence = list(Rn = Rn[-(max(K):NROW(lambda)),], 
                                   Sn = Sn[-(max(K):NROW(lambda)),],
                                   Tn = Tn[-(max(K):NROW(lambda)),]), 
                 KMax = K, Paramaters = par,
                 SampleStats = list(Range = sapply(1:Nv,function(k) range(Sample[,k],na.rm = T)),
                                    Sample = data.frame(Sample),
                                    NaTerms = NaTerms))
  class(output) <- "moped"

  return(output)
}
