% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/moped.R
\name{moped}
\alias{moped}
\title{Fit the multivariate orthogonal polynomial-based estimation of density}
\usage{
moped(
  Sample,
  K = 10,
  Distrib = rep("Uniform", NCOL(Sample)),
  bounds = NULL,
  variance = TRUE,
  recurrence = FALSE,
  opt.mpo = TRUE,
  nfolds = 5,
  repeats = 10
)
}
\arguments{
\item{Sample}{A data frame.}

\item{K}{Integer of maximum possible max polynomial order (mpo) of approximation.}

\item{Distrib}{Character string vector of length \code{NCOL(Sample)}, specifying the
reference distribution to be used for each variable (column) of Sample. Choices
are \code{"Uniform"} (default), \code{"Normal"}, \code{"Gamma"}, and \code{"Beta"} distributions.}

\item{bounds}{An optional data frame specifying the limits to be used on bounded
space. Should be an array of 2 x number of variables with each column having
the lower and upper limit. If \code{NULL} (default) bounds are estimated based on
range of \code{Sample}.}

\item{variance}{Logical that if \code{TRUE} (default), computes a variance estimate
of each coefficient.}

\item{recurrence}{Logical that if \code{TRUE}, computes the two-term recurrence
relation of each marginal orthogonal polynomial. Terms take the form
\eqn{P_{n+1}(x) = (R_nx + S_n)P_n(x) + T_nP_{n-1}(x)}.}

\item{opt.mpo}{Logical that if \code{TRUE} (the default), determines an optimal
max polynomial order estimate  using repeated k-fold cross-validation.}

\item{nfolds}{Integer that if \code{opt.mpo = TRUE}, determines the number of folds
(k) to perform in k-fold cross-validation.}

\item{repeats}{Integer that if \code{opt.mpo = TRUE}, determines the number of times
k-fold cross-validation is repeated.}
}
\value{
\code{moped()} returns a moped (list) object containing:
\itemize{
\item \code{Cn} - Array of estimated moment-based coefficients.
\item \code{varCn} - Array of variance estimates for Cn. Computed if \code{variance = TRUE}.
\item \code{Nv} - Dimension (number of variables) of joint density estimate.
\item \code{Nk_norm} - Array of estimated shifted Nk Norm values.
Computed if \code{opt.mpo = TRUE}.
\item \code{opt_mpo_vec} - Estimated optimal max polynomial order where K is vector.
Computed if \code{opt.mpo = TRUE}.
\item \code{opt_mpo} - Estimated optimal max polynomial order where K is constant.
Computed if \code{opt.mpo = TRUE}.
\item \code{Cats} - List of categorical data information from Sample.
\item \code{Distrib} - String vector of reference densities used for each variable.
\item \code{PDFControl} - List of reference distribution functions.
\item \code{PolyCoef} - Array of orthogonal polynomial coefficients.
\item \code{Poly} - Array of orthogonal polynomial values for each observation of Sample.
\item \code{Sigma} - Array of polynomial coefficients of sigma terms in polynomial.
\item \code{Tau} - Array of polynomial coefficients of tau terms in polynomial.
\item \code{Lambda} - Array of lambda terms (eigenvalues) for each variable.
\item \code{Limits} - Array of theoretical limits of each variable.
\item \code{Bounds} - Data frame of the parameter \code{Bounds}.
\item \code{LeadingTerms} - List containing leading terms of each polynomial.
\item \code{KMax} - Maximum max polynomial order (K) specified.
\item \code{Parameters} - Array of parameters of reference densities.
\item \code{SampleStats} - List containing original Sample and its range.
\item \code{Recurrence} - Optional list of polynomial recurrence relationship terms.
Computed if \code{recurrence = TRUE}.
}
}
\description{
\code{moped()} fits a multivariate orthogonal polynomial-based density
estimation to a dataframe. Categorical variables need to be converted to
continuous with \code{make.cont()} before fitting.
}
\examples{

require(sdcMicro)
Data <- CASCrefmicrodata[,c(2,3,4,6)]
str(Data)

# Fitting multivariate orthogonal polynomial based
# density estimation function using default setting
Fit <- moped(Data)

# Requires a data frame of bounds to fit on data.
bounds <- data.frame(
 AGI  = c(7192, 109883),
 EMCONTRB = c(17, 7800),
 FEDTAX = c(1, 23386),
 STATETAX = c(2,12628)
)

# Fitting the Data
Fit <- moped(
Data,
K=10,
Distrib = rep("Uniform", 4),
bounds = bounds,
variance = TRUE,
recurrence = FALSE,
opt.mpo = TRUE
)
}
