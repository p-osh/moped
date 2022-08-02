#' Title (?Brad)
#'
#' @param fit MBDensity type variable. Outputed from `moped()`.
#' @param X Grid of probabilities to be calculated. If `NULL` (the default) than
#'   generates nodes x Nv grid.
#' @param K Truncation to be used. If `NULL`( the default). it is max in Fit.
#' @param nprobs (?Brad)
#' @param variable Which variables to be predicted from Fit. The Default `NULL`
#'   is 1:Nv or 1:NCOL(X) whichever smallest.
#'
#' @return
#' @export
#'
#' @examples (?Brad)






predict.marg.cdf <- function(fit, # MBDensity Type Variable (Outputed from MBDensity)
                             X = NULL,   # Grid of Probabilities to be Calculated (If NULL than generates nodes^Nv grid)
                             K =NULL, # Truncation to be used (Default is max in Fit)
                             nprobs = 1,
                             variable = NULL # Which variables to be predicted from Fit (Default is 1:Nv or 1:NCOL(X) whichever smallest) )
){
  if(is.null(variable))  variable <- 1
  try(if(is.null(X) & fit$Distrib[variable] != "Uniform"){
    return(cat("Error: Non-uniform approximations require numeric values for X."))
  }else{
  if(is.null(K)) K <- max(fit$KMax)
  if(!is.null(X)) nprobs <- nrow(X)
  subsetnames <- lapply(1:NCOL(fit$SampleStats$Sample),function(k)1)
  subsetnames[[variable]] <- 1:K+1
  C <- c(extract.array(fit$Cn,indices = subsetnames))%o%array(1,dim=c(nprobs))

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
    return(list(coef = coef, E = E))
  }else{
    Prob <- apply(coef*(sapply(0:(K+1),function(k)X^k)),1,sum)
    return(list(coef = coef, E = E,Prob = Prob))
  }
  })
}
