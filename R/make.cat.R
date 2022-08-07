#' Convert previously continulized variables back to categorical variables.
#'
#' @param Sample A data frame.
#'
#' @return `make.cat()` returns a data frame.
#' @export
#'
#' @examples
#' Data_full <- ISLR::Wage
#'
#' Data <- Data_full %>%
#' select(age, maritl, race, education, jobclass, wage)
#' Data_amal <- make.cont(Data,catvar = c("maritl", "race", "education", "jobclass"),
#' amalgams = list(1:2,3:4))
#'
#' # Convert previously continulized variables back to categorical variables.
#' make.cat(Data_amal)




make.cat <- function(Sample){

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

  Sample <- Sample[,order(Cats$variables)]

  CamalSam <- Sample[,Cats$catvar]

  if(NCOL(CamalSam) == 1) CamalSam <- as.matrix(CamalSam)

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

  CatSam <- Sample[,-Cats$catvar]

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

  if(!Cats$amalgamated){
    CatSam <- CatSam[,order(c(Cats$catvar,(1:NCOL(CatSam))[-Cats$catvar]))]
  }

  return(CatSam)
}
