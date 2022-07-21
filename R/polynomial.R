#' Computing MBD polynomials.
#'
#' @param fit MBDensity type variable. Outputed from `moped()`.
#' @param X Grid of probabilities to be calculated. If `NULL` (the default) than
#'   generates nodes x Nv grid.
#' @param K K Integer vector. Maximum Truncation of Approximation on each
#'   variable. The default is the maximum MPO Order in `moped` object.
#' @param variables Integer vector or character string. Variables to be
#'   predicted from `moped` object. The default is 1:Nv or 1:NCOL(Sample)
#'   whichever smallest.
#' @param bounds A data frame. Bounds allows you to control the grid min and max.
#'   Should be an array of 2 x number of variables. `NULL` is the default.
#'
#' @return MBD polynomials from MBDensity type object.
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
#' # define the observation which the probability is desired.
#' x0 <- Data_x[1,]
#'
#' # Manually Compute MBD Polynomials
#' polynomial(Fit, X=x0, K=7)




polynomial <-  function(fit,
                        X = NULL,
                        K=NULL,
                        variables = NULL,
                        bounds = NULL  #Bounds allows you to control the grid min and max (2 X Nv Dataframe)
){
  Nv <- NCOL(X)
  if(is.null(variables)) variables <- 1:Nv
  if(Nv > length(variables)) X <- X[,1:length(variables)]
  Nv <- NCOL(X)
  if(Nv == 1) X <- as.matrix(X)
  if(is.null(K)) K <- fit$KMax[variables]
  if(length(K)==1) K <- rep(K,Nv)
  K <- sapply(1:Nv, function(k) min(fit$KMax[variables[k]],K[k]))
  Km <- max(K) #Max Truncation
  nprobs <- NROW(X)
  #Array Definitions
  XM <- list() # Array of 1, X, X^2, ....
  P <- list() # Polynomial Terms P_0(X), P_1(X), ...
  PdfTerms <- rep(1,nprobs) # Reference PDF f_v(X)

  for(k in 1:Nv){
    if(NROW(X)==1) XM[[k]] <- as.matrix(sapply(0:Km, function(i) X[,k]^i))
    else XM[[k]] <- t(sapply(0:Km, function(i) X[,k]^i))
    P[[k]] <- fit$PolyCoef[0:K[k]+1,0:K[k]+1,variables[k]]%*%((XM[[k]])[0:K[k]+1,])
    PDFk <- as.function(fit$PDFControl(variables[k])$PDF)
    PdfTerms <- PdfTerms*PDFk(X[,k])
  }

  output <- list(P = P, PdfTerms = PdfTerms)
  return(output)
}
