#' Title
#'
#' @param fit
#' @param X
#' @param K
#' @param nprobs
#' @param variable
#'
#' @return
#' @export
#'
#' @examples






predict.marg.cdf <- function(fit, # MBDensity Type Variable (Outputed from MBDensity)
                             X = NULL,   # Grid of Probabilities to be Calculated (If NULL than generates nodes^Nv grid)
                             K =NULL, # Truncation to be used (Default is max in Fit)
                             nprobs = 1,
                             variable = NULL # Which variables to be predicted from Fit (Default is 1:Nv or 1:NCOL(X) whichever smallest) )
){
  if(is.null(variable))  variable <- 1
  if(is.null(K)) K <- max(fit$KMax)

  XDP <- (fit$PolyCoef[2:(K+1),2:(K+1),variable]/fit$Lambda[1:K,variable])*
    t(array(1:K,dim = rep(K,2)))

  fnu <- 1/(fit$Paramaters[2,variable]-fit$Paramaters[1,variable])
  E <- t(t(XDP)%*%array(1,dim=c(K,nprobs)))*fnu
  coef <- cbind(fit$Sigma[3,variable]*E,0,0) + cbind(0,fit$Sigma[2,variable]*E,0) + cbind(0,0,fit$Sigma[1,variable]*E)
  coef[,1] <- coef[,1]-fit$Paramaters[1,variable]/
    (fit$Paramaters[2,variable]-fit$Paramaters[1,variable])
  coef[,2] <- coef[,2]+1/(fit$Paramaters[2,variable]-fit$Paramaters[1,variable])
  if(is.null(X)){
    return(list(coef = coef, E = E))
  }else{
    Prob <- apply(coef*(sapply(0:(K+1),function(k)X^k)),1,sum)
    return(list(coef = coef, E = E,Prob = Prob))
  }
}
