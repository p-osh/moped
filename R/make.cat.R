#' Convert previously continuous-transformed variables back to categorical variables.
#'
#' @param Sample A data frame outputted from `make.cont()` or `m.resample()` which
#' originally contained categorical variables.
#' @param fit optional `moped` type object outputted from `moped()`. Must be specified
#' if `Sample` has lost `Cats` attribute due to subsetting or transformation.
#'
#' @return `make.cat()` returns a data frame.
#' @export
#'
#' @examples
#' require(ISLR)
#' Data_full <- Wage
#'
#' require(tidyverse)
#' Data <- Data_full %>%
#' select(age, maritl, race, education, jobclass, wage)
#' Data_amal <- make.cont(Data,catvar = c("maritl", "race", "education", "jobclass"),
#' amalgams = list(1:2,3:4))
#'
#' # Convert previously continuous-transformed variables back to categorical variables.
#' make.cat(Data_amal)
#'
#' # Categorised resampled data from `moped()`.
#' Data <- Data_full %>%
#'   select(education, jobclass, wage)
#' Data_numeric <- make.cont(Data, catvar = c("education","jobclass"))
#' Fit <- moped(Data_numeric)
#' new_Data_num <- m.resample(Fit)
#' new_Data <- make.cat(new_Data_num)
#'
#' # If data has been subsetted. Fit is also required.
#' new_subset_Data <- make.cat(new_Data_num[1:10,-3],fit = Fit)

make.cat <- function(Sample,
                     fit=NULL){

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


  polyinv <- function(x){
    return(x)
  }

  Cats <- attributes(Sample)$Cats

  if(is.null(Cats) & !is.null(fit)) Cats <- fit$Cats

  if(is.null(Cats)){
    stop('Data frame must be output of make.cont() or m.resample().
         Please specify the fitted moped object to re-categorise.')
  }else if (prod(Cats$catvar_names %in% colnames(Sample))) {

    contvar_names <- setdiff(colnames(Sample),Cats$catvar_names)

    CamalSam <- Sample[,Cats$catvar_names]

    if(NCOL(CamalSam) == 1) CamalSam <- as.data.frame(CamalSam)

    amalSam <- data.frame()

    inv.sel.bound <- function(i,j){
      if(i ==1){
        case <- which(Cats$lowerlist[[1]] < CamalSam[j,1] &
                        Cats$upperlist[[1]] > CamalSam[j,1])
      }else{
        case <- which(indexer(
          polyinv(aperm(Cats$lowerlist[[i]],perm = c(i,1:(i-1)))),
          unlist(amalSam[j,1:(i-1)])) < CamalSam[j,i] &
            indexer(polyinv(
              aperm(Cats$upperlist[[i]],perm = c(i,1:(i-1)))),
              unlist(amalSam[j,1:(i-1)])) > CamalSam[j,i])
      }
      return(case)
    }

    for(k in 1:NCOL(CamalSam)){
      for(j in 1:NROW(CamalSam)){
        amalSam[j,k] <- inv.sel.bound(k,j)
      }
    }
    amalSam <- data.frame(lapply(amalSam,factor))
    for(k in 1:NCOL(amalSam)) levels(amalSam[,k]) <- Cats$caselist[[k]]

    CatSam <- array(dim=c(NROW(Sample),1))

    for(i in length(Cats$amalgams):1){
      if(length(Cats$amalgams[[i]]) > 1){
        amal_split <- data.frame(matrix(unlist(strsplit(as.character(amalSam[,i]),"_;_",fixed=T)),ncol=2,byrow=T))
        amal_split <- data.frame(lapply(amal_split,factor))
      }else{
        amal_split <- data.frame(factor(amalSam[,i]))
      }
      colnames(amal_split) <- Cats$amalgams_names[[i]]
      CatSam <- cbind(amal_split,CatSam)
    }
    CatSam <- CatSam[,-NCOL(CatSam)]

    if(!Cats$amalgamated){
      Sample[,Cats$catvar_names] <- CatSam
    }else{
      Sample <- cbind(CatSam,Sample[,contvar_names])
    }

  }else{
    stop('Sample must be a data frame containing columns ',paste(Cats$catvar_names,collapse=" "))
  }
  return(Sample)
}
