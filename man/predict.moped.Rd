% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/predict.R
\name{predict.moped}
\alias{predict.moped}
\title{Predict the density or probability of an observation}
\usage{
\method{predict}{moped}(
  fit,
  X = NULL,
  K = NULL,
  variables = 1:fit$Nv,
  bounds = NULL,
  type = "density",
  cond.variables = NULL,
  normalise = T,
  nodes = 100,
  parallel = F,
  ncores = NULL,
  mps = 5000
)
}
\arguments{
\item{fit}{\code{moped} type variable. Outputted from \code{moped()}.}

\item{X}{An optional data frame in which to look for variables with which
to estimate density values. Must contain column names matching variables in
the \code{moped} object. If \code{NULL} (the default) then generates a \code{nodes}^\code{fit$Nv}
grid with density values.}

\item{K}{Integer vector of max polynomial order of approximation on each
variable. Must be less than or equal to the maximum MPO K specified in
\code{moped()}. The default is the \code{opt_mpo} or \code{KMax} (if \code{opt_mpo = NULL})
specified in \code{fit}.}

\item{variables}{Integer vector or character string of variable names. The
\code{moped} position or column name of the variable(s) to be predicted from
\code{moped} object. The default is \code{1:fit$Nv}.}

\item{bounds}{An optional data frame specifying the limits to be used on bounded
space. Should be an array of 2 x number of variables with each column having
the lower and upper limit.}

\item{type}{string equal to \code{"density"} (default), \code{"distribution"}, or
\code{"conditional"}. If \code{type = "density"} density values are estimated. If
\code{type = "distribution"} cumulative distribution function probabilities are
estimated. If \code{type = "conditional"} conditional distribution function
probabilities are estimated conditioned on the variables chosen in
\code{cond.variables}.}

\item{cond.variables}{Integer vector or character string of conditional variable
names. The \code{moped} position or column name of the conditional variable(s) to
be predicted from \code{moped} object if \code{type="conditional"}.}

\item{normalise}{Logical that if \code{TRUE} (the default), scales density estimate
to correct for any estimated negative values.}

\item{nodes}{Integer vector that corresponds to the number of grid points per
dimension when \code{X = NULL} and a grid is calculated.}

\item{parallel}{Logical that if \code{TRUE} uses the \code{parallel} package to simulate
values using parallel computing.}

\item{ncores}{Integer vector that determines the number of cores used in
parallel computing.}

\item{mps}{Integer vector that places a limit on maximum number of probabilities
calculated at a time. The default is 5000.}
}
\value{
\code{predict.moped()} returns a data frame with estimated density/probability values.
}
\description{
\code{predict.moped()} predicts density and probabilities for a set of observations.
When constructing partially joint density, sample and variables must be used
together. X must be a data frame and its variable length must equal to the
length in \code{var}.
}
\examples{
require(ISLR)
Data_full <- Wage

require(tidyverse)
Data <- Data_full \%>\%
select(age, education, jobclass,wage)

# Convert Categorical Data to Continuous Data
Data_x <- make.cont(Data, catvar = 2:3)

# Fitting multivariate orthogonal polynomial based
# density estimation function

# Fitting the Data
Fit <- moped(Data_x)

# Define the observation which the probability is desired
x0 <- Data_x[1,]
pred <- predict(Fit, K= 7, X = x0)

# Predicting Marginal Density for a set of observations
# When constructing partially joint density, X and variables must be used together.
predict(Fit, K= 7, X= Data_x[,3:4] , variables =c("jobclass", "wage"))
predict(Fit, K= 7, X= data.frame(wage=Data_x$wage) , variables = 4 )
}
