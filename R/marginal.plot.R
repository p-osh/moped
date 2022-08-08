#' Marginal plots for each variable with a range of polynomial orders K.
#'
#' @description
#' `marginal.plot()` is used to Marginal plots for each variable with a range of
#' polynomial orders K. Optimal bin width using the Freedman-Diaconis rule for
#' each variable.
#'
#' @param fit A `moped` object from `moped()`.
#' @param k.range Range of polynomial orders K. Default is 1 to `KMax` specified
#'  in `moped` object.
#' @param ncol Integer vector of number of columns the marginal plots shown for
#'  a given variable.
#' @param prompt Logical, whether it needs the prompt to show the next plot.
#'   If `TRUE` (the default), press enter to show the next plot, If `FALSE`,
#'   outputs all plots simultaneously.
#'
#' @return `marginal.plot()` returns plots of each marginal variable.
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
#' Fitting the Data
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
#' # Check marginal densities with different polynomial K
#' marginal.plot(Fit)
#' marginal.plot(Fit, k.range = 3:8, ncol =3, prompt = FALSE)



marginal.plot <- function(fit,
                          k.range = 1:fit$KMax,
                          ncol = 4,
                          prompt = TRUE
){
  require(ggplot2)
  require(patchwork)
  ###############################################
  if (prompt == "TRUE") {
    par(ask=TRUE)
  }
  if (prompt == "FALSE") {
    par(ask=FALSE)
  }



  # loop around all variables, one page for each variable
  for (j  in 1:NCOL(fit$SampleStats$Sample)){
    #optimal bin width using the Freedman-Diaconis rule
    bw <- 2 * IQR(fit$SampleStats$Sample[,j]) / length(fit$SampleStats$Sample[,j])^(1/3)
    myplots <- list()  # new empty list to store the plots
    # loop through all polynomial order K
    for (i in k.range) {
      pred.temp <- predict(fit,K=i,variables = j)
      p1 <- eval(substitute(
        ggplot(as.data.frame(fit$SampleStats$Sample)) +
          geom_histogram(aes(x=fit$SampleStats$Sample[,j],y=..density..), binwidth = bw)+
          geom_line(aes(x=pred.temp[,1],y=Density),data=pred.temp,col='red')+
          ggtitle(paste0("K = ", i)) +
          labs(x = element_blank())+
          theme(plot.title = element_text(hjust = 0.5))
        ,list(i = i)))
      myplots[[i]] <- p1  # add each plot into plot list
    }
    myplots <- myplots[!sapply(myplots,is.null)]
    # multi plots by row
    p <- wrap_plots(myplots, ncol = ncol, byrow = TRUE) +
      plot_annotation(
        title = names(pred.temp)[1],
        theme = theme(plot.title = element_text(hjust = 0.5))
      )

    print(p)
  }

  par(ask=FALSE)
}

#marginal.plot(Fit)
#marginal.plot(Fit, k.range = 3:10)
