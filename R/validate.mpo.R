#' Estimate optimal max polynomial order with repeated k-fold cross-validation
#'
#' @description `validate.mpo()` performs repeated k-fold cross-validation to
#' determine an unbiased estimate of the shifted `Nk`-Norm that when minimised, it
#' provides an estimate of the optimal max polynomial order. The coefficient
#' estimates are also calculated as well as  their corresponding variance
#' estimates (optional).
#'
#' @param fit `moped` type variable outputted from `moped()`.
#' @param K Integer of the maximum possible max polynomial order of approximation.
#'   Default is `KMax` specified in `fit`.
#' @param nfolds Integer that determines the number of folds (k) to perform in
#'   k-fold cross-validation.
#' @param repeats Integer that determines the number of times k-fold cross-validation
#'   is repeated.
#' @param variance Logical that if `TRUE` (default), computes a variance estimate
#'   of each coefficient.
#'
#' @return `validate.mpo()` returns a list containing:
#' \itemize{
#'   \item `Cn` - Array of estimated moment-based coefficients.
#'   \item `varCn` - Array of variance estimates for Cn. Computed if `variance = TRUE`.
#'   \item `Nk_norm` - Array of estimated shifted Nk Norm values.
#'   \item `opt_mpo_vec` - Estimated optimal max polynomial order where K is vector.
#'   \item `opt_mpo` - Estimated optimal max polynomial order where K is constant.
#' }
#'
#' @export validate.mpo
#'
#' @examples
#' require(sdcMicro)
#' Data <- CASCrefmicrodata[,c(2,3,4,6)]
#'
#' # Fitting multivariate orthogonal polynomial based
#' # density estimation function using default setting
#' Fit <- moped(Data)
#'
#' # Select the optimal polynomial order K
#' val <- validate.mpo(fit = Fit) #warning! it might take a while
#' val$opt_mpo_vec #show the vector of optimal polynomial orders


validate.mpo <- function(fit,
                         K = fit$KMax,
                         nfolds = 5,
                         repeats = 10,
                         variance = T){
  Poly <- fit$Poly
  NS <- dim(Poly)[2]
  Nv <- dim(Poly)[3]
  NaTerms <- 0

  folds <- lapply(1:repeats,function(r) sample(1:nfolds,NS,replace=T))

  Cn_folds <- array(lapply(1:(repeats*nfolds),function(i)array(0,dim=c(rep(K+1,Nv)))),dim = c(repeats,nfolds))
  NaTerms_folds <- array(lapply(1:(repeats*nfolds),function(i)array(0,dim=c(rep(K+1,Nv)))),dim = c(repeats,nfolds))
  if (variance) Cn2_folds <- array(lapply(1:(repeats*nfolds),function(i)array(0,dim=c(rep(K+1,Nv)))),dim = c(repeats,nfolds))

  for (j in 1:NS){
    TempPoly <- Poly[0:K + 1, j, 1]
    if (Nv > 1)
      for (k in 2:Nv)
        TempPoly <- TempPoly %o% Poly[0:K + 1, j, k]
    isNaTerm <- is.na(TempPoly)
    TempPoly[isNaTerm] <- 0
    for(r in 1:repeats){
      Cn_folds[r,folds[[r]][j]][[1]] <- unlist(Cn_folds[r,folds[[r]][j]]) + TempPoly
      NaTerms_folds[r,folds[[r]][j]][[1]] <- unlist(NaTerms_folds[r,folds[[r]][j]]) + isNaTerm
      if (variance) Cn2_folds[r,folds[[r]][j]][[1]] <- unlist(Cn2_folds[r,folds[[r]][j]]) + TempPoly^2
    }
    progress(100*j/NS)
  }

  N_folds <- array(lapply(1:(repeats*nfolds),function(i)array(0,dim=c(rep(K+1,Nv)))),dim = c(repeats,nfolds))
  for(r in 1:repeats)
    for(fi in 1:nfolds){
      N_folds[r,fi][[1]] <- (sum(folds[[r]]==fi) - NaTerms_folds[r,fi][[1]])
      Cn_folds[r,fi][[1]] <- Cn_folds[r,fi][[1]]/N_folds[r,fi][[1]]
      if (variance) Cn2_folds[r,fi][[1]] <- Cn2_folds[r,fi][[1]]/N_folds[r,fi][[1]]
    }

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
  Nk_norm <- 0
  Cn <- 0
  varCn <- 0
  if(nfolds > 1){
    for(r in 1:repeats)
      for(fi in 1:nfolds){
        N_coef <- apply(array(unlist(N_folds[r,(1:nfolds)[-fi]]),dim=c(rep(K+1,Nv),nfolds-1)),1:Nv,sum)
        Cn_fi <- apply(
          array(unlist(N_folds[r,(1:nfolds)[-fi]]),dim=c(rep(K+1,Nv),nfolds-1))*
            array(unlist(Cn_folds[r,(1:nfolds)[-fi]]),dim=c(rep(K+1,Nv),nfolds-1))
          ,1:Nv,sum)/N_coef
        Cn <- Cn + Cn_fi/(repeats*nfolds)
        Nk_norm <- Nk_norm + cumsumer(Cn_fi^2 - 2*Cn_fi*Cn_folds[r,fi][[1]])/(repeats*nfolds)
        if(variance){
          Cn2_fi <- apply(
            array(unlist(N_folds[r,(1:nfolds)[-fi]]),dim=c(rep(K+1,Nv),nfolds-1))*
              array(unlist(Cn2_folds[r,(1:nfolds)[-fi]]),dim=c(rep(K+1,Nv),nfolds-1))
            ,1:Nv,sum)/N_coef
          varCn <- varCn + (Cn2_fi - Cn_fi^2)/(repeats*nfolds)
        }
      }
    Nk_vec <- Nk_norm[sapply(1:Nv, function(k) 0:K+1)]
    opt_mpo_vec <- c(which(Nk_norm == min(Nk_norm),arr.ind = T)-1)
    names(opt_mpo_vec) <- dimnames(Poly)[[3]]
    opt_mpo <- which(Nk_vec == min(Nk_vec),arr.ind = T)-1
    if (variance){
      output <- list(Cn = Cn,varCn = varCn,opt_mpo_vec = opt_mpo_vec, opt_mpo = opt_mpo, Nk_norm = Nk_norm)
    }else{
      output <- list(Cn = Cn,varCn = NULL,opt_mpo_vec = opt_mpo_vec, opt_mpo = opt_mpo, Nk_norm = Nk_norm)
    }

  }else{
    Cn <- Cn_folds[1,1][[1]]
    if (variance){
      varCn <- Cn2_folds[1,1][[1]] - Cn_folds[1,1][[1]]^2
      output <- list(Cn = Cn,varCn = varCn,opt_mpo_vec = NULL, opt_mpo = NULL, Nk_norm = NULL)
    }else{
      output <- list(Cn = Cn,varCn = NULL,opt_mpo_vec = NULL, opt_mpo = NULL, Nk_norm = NULL)
    }
  }
  return(output)
}
