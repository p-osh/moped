#' Convert categorical variables into continuous.
#'
#' @description
#' `make.cont()` is used to converting categorical variables into continuous
#' variables. It must done before fitting data to the density estimation
#' function `moped()`.
#'
#' @param Sample A data frame.
#' @param catvar Columns to convert into continuous variables. Variable names
#'   can be used as if they were positions in the data frame.
#' @param amalgams A list using numeric positions indicating the order of variables in
#'   `"catvar"`. Each list item contains a vector of positions of `"catvar"`
#'   that are to be amalgamated into a single continuous variable.
#'
#' @return `make.cont()` returns a data frame with strictly continuous values.
#' @export
#'
#' @examples
#' require(ISLR)
#' Data_full <- Wage
#'
#' # Convert Categorical Data to Continuous Data
#' require(tidyverse)
#' Data <- Data_full %>%
#' select(age, education, jobclass, wage)
#' Data_x <- make.cont(Data, catvar = 2:3)
#' # Select variables by name
#' Data_x <- make.cont(Data, catvar = c("education", "jobclass"))
#'
#' # Convert categorical with amalgamations of subsets of variables
#' Data <- Data_full %>%
#' select(age, maritl, race, education, jobclass, wage)
#' Data_amal <- make.cont(Data,catvar = c("maritl", "race", "education", "jobclass"),
#' amalgams = list(
#' 1:2, #maritl and race are 1st and 2nd variables in the catvar list and they are amalgamated into a single variable.
#' 3:4 #education and jobclass are 3rd and 4th variables in the catvar list and are amalgamated into a single variable.
#' ))


make.cont <- function(
    Sample,
    catvar = 1:NCOL(Sample),
    amalgams = NULL
){

  if(is.character(catvar)){
    catvar <-  which(colnames(Sample) %in% catvar)
  }

  indexer <- function(X,n){
    nX <- length(c(X))
    Xdim <- dim(X)
    nval <- nX
    val <- c(X)

    for(k in 1:length(n)){
      val <- val[seq((rev(n)[k]-1)*(nval/rev(Xdim)[k])+1,
                     (rev(n)[k])*nval/rev(Xdim)[k],1)]
      nval <- length(val)
    }
    return(val)
  }

  polyinv <- function(x){
    return(x)
  }

  # polyinv <- function(x){
  #   if(length(x) > 1){
  #     dx <- dim(x)
  #     x_vec <- sapply(c(x),function(i) polyinv(i)[1])
  #     return(array(x_vec,dim=dx))
  #   }else{
  #     roots <- polyroot(c(-x,0,0,10,-15,6))
  #     return((Re(roots)[which(abs(Im(roots)) < 1e-6)])[1])
  #   }
  # }

  ###################################
  amalgamated <- T
  if(is.null(amalgams)){
    amalgams <- lapply(1:length(catvar),function(i) return(i))
    amalgamated <- F
  }
  catSam <- Sample[,catvar]

  if(NCOL(catSam) == 1) catSam <- as.matrix(catSam)

  amalgams_names <- lapply(1:length(amalgams),function(k)colnames(catSam)[amalgams[[k]]])
  contnam <- colnames(Sample)[-catvar]
  key <- list()
  amalSam <- c()
  for(k in 1:length(amalgams)){
    first_key <- T
    key[[k]] <- rep('',NROW(catSam))
    for(j in amalgams[[k]]){
      if(first_key){
        key[[k]] <- as.character(catSam[,j])
        first_key <- F
      }else{
        key[[k]] <- paste(key[[k]],catSam[,j],sep='_;_')
      }}
    amalSam <- cbind(amalSam,(key[[k]]))
  }
  amalSam <- as.data.frame(amalSam)
  amalSam <- data.frame(lapply(amalSam,factor))

  jprop <- table(amalSam)/NROW(amalSam)

  proplist <- list()
  upperlist <- list()
  lowerlist <- list()
  caselist <- list()

  proplist[[1]] <- c(table(amalSam[,1]))/NROW(amalSam)
  upperlist[[1]] <- (cumsum(proplist[[1]]))
  lowerlist[[1]] <- (upperlist[[1]] - proplist[[1]])
  caselist[[1]] <- levels(amalSam[order(amalSam[,1]),1])

  if(NCOL(amalSam)> 1){
    for(k in 2:NCOL(amalSam)){
      proplist[[k]] <- table(amalSam[,1:k])/array(table(amalSam[,1:(k-1)]),dim = dim(jprop)[1:k])
      upperlist[[k]] <- aperm(apply(proplist[[k]],1:(k-1),cumsum), perm = c(2:k,1))
      lowerlist[[k]] <- upperlist[[k]] - proplist[[k]]
      if(sum(is.nan(upperlist[[k]])) > 0) upperlist[[k]][is.nan(upperlist[[k]])] <- 0
      if(sum(is.nan(lowerlist[[k]])) > 0) lowerlist[[k]][is.nan(lowerlist[[k]])] <- 0
      caselist[[k]] <- levels(amalSam[order(amalSam[,k]),k])
    }
  }
  CamalSam <- array(0,dim = dim(amalSam))

  sel.bound <- function(i,j,blist){
    if(i ==1){
      return(blist[[1]][amalSam[j,1]])
    }else{
      case <- sapply(1:i,function(k1) which(caselist[[k1]]== amalSam[j,k1]))
      return(indexer(blist[[i]],case))
    }
  }

  for(k in 1:NCOL(amalSam)){
    for(j in 1:NROW(amalSam)){
      CamalSam[j,k] <- polyinv(runif(1,sel.bound(k,j,lowerlist),sel.bound(k,j,upperlist)))
    }}

  if(amalgamated){
    contvar <- (1:NCOL(Sample))[-catvar]
    tSample <- cbind(CamalSam,Sample[,-catvar])
    colnames(tSample) <- rep('AmalgamatedVar',NCOL(tSample))
    if(length(contvar)>0) colnames(tSample)[NCOL(CamalSam)+1:length(contvar)] <- colnames(Sample)[contvar]
    catvar <- 1:NCOL(CamalSam)
    message("Warning: Column order has been changed.")
  }else{
    tSample <- Sample
    tSample[,catvar] <- CamalSam
  }
  Cats <- list(
    catvar = catvar, amalgams = amalgams,
    caselist = caselist, amalgamated = amalgamated,
    upperlist = upperlist, lowerlist = lowerlist,
    amalgams_names = amalgams_names,
    variables = 1:NCOL(tSample),
    catvar_names = colnames(tSample)[catvar]
  )

  attr(tSample,"Cats") <- Cats

  return(tSample)
}
