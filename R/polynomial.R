#' Computing the univariate hyper-geometric type orthogonal polynomials.
#'
#'@description `polynomial()` is used to calculate the univariate hyper-geometric
#'  type orthogonal polynomials used in the `moped()` function. 
#'
#' @param fit `moped` type object. Outputted from `moped()`.
#' @param X data frame of observations with column names matching selected 
#'   variables from `moped` type object.
#' @param K Integer vector. Maximum Polynomial Order of approximation on each 
#'   variable. Must be less than or equal to the maximum MPO K specified in 
#'   `moped()`. The default is the K specified in `moped` type object.
#' @param variables Integer vector or character string of variable names. The 
#'   `moped` position or column name of the variable(s) to be predicted from 
#'   `moped` object. The default is 1:Nv (number of variables) or 1:NCOL(Sample),
#'    whichever smallest.
#' @return A list with the following components:
#' \itemize{
#'   \item `P` - List of marginal hyper-geometric orthogonal polynomial values. 
#'   \item `PdfTerms` - Vector of reference density values for each obs of X.   
#' }
#' 
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
#' # Define the observation which the probability is desired.
#' x0 <- Data_x[1:2,]
#'
#' # Manually Compute MBD Polynomials
#' polynomial(Fit, X=x0, K=7)



polynomial <-  function(fit,
                        X,
                        K=NULL,
                        variables = NULL
){
  Nv <- NCOL(fit$SampleStats$Sample)
  if(is.null(variables)) variables <- 1:Nv
  if(is.character(variables)){
    variables <-  which(colnames(fit$SampleStats$Sample) %in% variables)
  }
  variables_names <- colnames(fit$SampleStats$Sample)[variables]
  test_names <- prod(variables_names %in% colnames(X)) == 0 | !is.data.frame(X) 
  Nv <- length(variables)
  try(if(test_names){
    return(cat("\r Error: X must be data frame and contain columns named ",variables_names))
  } else {
  X <- X[,variables_names]
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
    colnames(P[[k]]) <- rownames(X)
    rownames(P[[k]]) <- paste0("n=",0:K[k])
    PDFk <- as.function(fit$PDFControl(variables[k])$PDF)
    PdfTerms <- PdfTerms*PDFk(X[,k])
    names(PdfTerms) <- rownames(X)
  }
  names(P) <- variables_names
  output <- list(P = P, PdfTerms = PdfTerms)
  return(output)
   })
}
