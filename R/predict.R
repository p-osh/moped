#' Predicting the probability of an observation based on moped density estimate
#'
#' @description
#' `predict()` is used to predict marginal density for a set of observations.
#' When constructing partically joint density, sample and variables must be used
#' together. Sample must be a data frame and its variable length must equal to
#' the length in var.
#'
#' @param fit MBDensity Type Variable. Outputed from `moped()`.
#' @param Sample A data frame for which the probabilities to be calculated. If
#'   `NULL` (the default) than generates nodes^Nv grid. Usually used to
#'   calculate probability for a specific set of obs.
#' @param K Integer vector. Truncation to be used, the default is the maximum
#'   MPO Order in `moped` object.
#' @param variables Integer vector or character string. Variables to be
#'   predicted from `moped` object. The default is 1:Nv or 1:NCOL(Sample)
#'   whichever smallest.
#' @param bounds A data frame. Bounds allows you to control the grid min and max.
#'   Should be an array of 2 x number of variables. `NULL` is the default.
#' @param normalise Logical. If `TRUE` (the default). (?Brad)
#' @param nodes Integer vector. Nodes allows you to control how many grid points.
#' @param parallel Logical. If `FALSE` (the default), parallel computing is not
#'   used.
#' @param ncores Integer vector. NCores to use in parallel computing.
#' @param mps Integer vector. The default is 5000. (?Brad)
#'
#' @return `predict()` returns a data frame.
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
#' # Define the observation which the probability is desired
#' x0 <- Data_x[1,]
#' pred <- predict(Fit, K= 7, Sample = x0)
#'
#' # Predicting Marginal Density for a set of observations
#' # When constructing partically joint density, Sample and varaibles must be used together.
#  # Sample must be a dataframe and its variable length must equal to the length in var.
#' pred <- predict(Fit, K= 7, Sample= Data_x[,3:4] , variables =c("jobclass", "wage"))
#' pred <- predict(Fit, K= 7, Sample= Data_x[,4] , variables =c("wage"))
#' pred <- predict(Fit, K= 7, Sample= Data_x[,4] , variables =4 )
#' pred <- predict(Fit, K= c(2,7), Sample= Data_x[,3:4] , variables =c("jobclass","wage"))
#'
#' # Plotting marginal density
#' predict(Fit, K= 7, variables =4) %>%
#' ggplot(aes(x=wage,y=Density)) +
#' geom_line()
#'
#' # Plotting bivariate density plot
#' predict(Fit, K= c(2,7), variables =3:4) %>%
#' ggplot(aes(x=jobclass,y=wage,fill=Density)) +
#' geom_tile() +
#' scale_fill_distiller(palette = "Spectral")


predict <- function(fit,
                    Sample = NULL,
                    K=NULL,
                    variables = NULL,
                    bounds = NULL ,
                    normalise = T,
                    nodes = 100,
                    parallel = F,
                    ncores = NULL,
                    mps = 5000
){

  if( length(Sample) != 0 & length(variables) != 0 & NCOL(Sample) != length(variables)){
    return(cat("Error: Sample must be a dataframe and the number of columns must equal to the length in 'variables'"))
  } else {

    #Default Allocations
    if(is.character(variables)){
      variables <-  which(colnames(fit$SampleStats$Sample) %in% variables)
    }

    if(is.null(Sample)){
      Grid = T
      if(is.null(variables)) variables <- 1:length(fit$KMax)
      if(is.null(bounds)) bounds = sapply(variables, function(i) fit$SampleStats$Range[,i])
      Sample = expand.grid(lapply(1:length(variables),function(i) seq(bounds[1,i],bounds[2,i],length.out = nodes)))
      deltaX = sapply(1:length(variables),function(i) (bounds[2,i] - bounds[1,i])/(nodes - 1))
    }else{
      Grid=F
    }


    onerow <- F
    if(NROW(Sample)==1){
      Sample <- rbind(Sample,Sample)
      onerow <- T
    }
    Nv <- NCOL(Sample)
    if(is.null(variables)) variables <- 1:Nv
    if(Nv > length(variables)) Sample <- Sample[,1:length(variables)]
    Nv <- NCOL(Sample)
    if(Nv == 1) Sample <- as.matrix(Sample)
    if(is.null(K)) K <- fit$KMax[variables]
    if(length(K)==1) K <- rep(K,Nv)
    K <- sapply(1:Nv, function(k) min(fit$KMax[variables[k]],K[k]))
    Km <- max(K) #Max Truncation
    require(tensor)
    require(R.utils)

    tK <- c(K,rep(0,length(fit$KMax) - Nv))[order(c(variables,setdiff(1:length(fit$KMax),variables)))]
    #Extract Related Coefficients
    if(length(fit$KMax)==1){
      C <- fit$Cn[1:(Km+1)]
    }else{
      subsetnames <- lapply(1:length(fit$KMax),function(k) return((0:tK[k])+1))
      C <- aperm(extract.array(fit$Cn,indices = subsetnames), perm = c(variables,setdiff(1:length(fit$KMax),variables)))
    }
    #Split Grid for allocation (OVERCOME VECTOR ALLOCATION SIZE ISSUES)
    SS <- NROW(Sample)
    nsplits = ceiling(NROW(Sample)/mps)
    if(parallel) nsplits = max(ceiling(NROW(Sample)/mps))

    if(nsplits==1){
      splitindex <- list(1:SS)
    }else{
      splitindex <- lapply(1:nsplits, function(j) (((j-1)*mps)+1):min((j*mps),SS))
    }

    Tgen <- function(j){
      nprobs <- length(splitindex[[j]])
      #Array Definitions
      Km <- max(K) #Max Truncation
      XM <- list() # Array of 1, X, X^2, ....
      P <- list() # Polynomial Terms P_0(X), P_1(X), ...
      PdfTerms <- rep(1,nprobs) # Reference PDF f_v(X)

      for(k in 1:Nv){
        XM[[k]] <- t(sapply(0:Km, function(i) Sample[splitindex[[j]],k]^i))
        P[[k]] <- fit$PolyCoef[0:K[k]+1,0:K[k]+1,variables[k]]%*%((XM[[k]])[0:K[k]+1,])
        PDFk <- as.function(fit$PDFControl(variables[k])$PDF)
        PdfTerms <- PdfTerms*PDFk(Sample[splitindex[[j]],k])
      }
      Terms = c()
      tt = tensor(C,P[[1]],1,1)
      if(Nv > 1) {
        for(k in 2:Nv){
          if(length(dim(tt))==2){
            tt = tt*P[[k]]
          }else{
            dimperm = c(dim(tt)[1],nprobs,dim(tt)[2:(length(dim(tt))-1)])
            tt = tt*aperm(array(P[[k]],dim = dimperm),perm = c(1,3:length(dimperm),2))
          }
          tt = apply(tt,2:length(dim(tt)),sum)
        }
      }
      Terms <- c(Terms,tt)
      return(Terms*PdfTerms)
    }

    if(parallel){
      if(is.null(ncores)) ncores <- detectCores()
      Terms <- unlist(mclapply(1:nsplits,function(j) Tgen(j),mc.cores = ncores))
    }else{
      Terms <- unlist(lapply(1:nsplits,function(j) Tgen(j)))
    }

    Probability <-Terms
    Prob1 <- Probability
    if(normalise){
      Probability[Probability<0] <- 0 #Truncate -ve probabilities
      norm <- abs(sum(Probability)/sum(Prob1)) #Rescale
    }else{
      norm <- 1
    }
    if(Grid == T & normalise ==T) norm = sum(Probability)*prod(deltaX)

    output = as.data.frame(cbind(Sample,Probability/norm))
    names(output) = c(colnames(fit$SampleStats$Sample)[variables], "Density")
    if(onerow) return(output[1,]) else return(output)
  }

}
