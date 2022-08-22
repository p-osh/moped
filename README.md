
<!-- README.md is generated from README.Rmd. Please edit that file -->

# moped

<!-- badges: start -->
<!-- badges: end -->

The goal of moped package is to apply multivariate orthogonal polynomial
based estimation of density.

## Installation

You can install the **moped** version from [CRAN](https://github.com/):

``` r
install.packages("moped")
```

You can install the **development** version of moped from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
remotes::install_github("p-osh/moped")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(moped)
library(tidyverse)
library(ISLR)
```

### Pre-processing

#### Convert categorical data to Continuous Data

``` r
Data_full <- ISLR::Wage

# Must be a dataframe - Categorical Data should be factors
Data <- Data_full %>% select(age, education, jobclass, wage)

Data_x <- make.cont(Data, catvar = 2:3)
```

#### Convert categorical with amalgamations

``` r
Data <- Data_full %>% select(age, maritl, race, education, jobclass, wage)

Data_amal <- make.cont(Data, catvar = c("maritl", "race", "education", "jobclass"),
                       amalgams = list(1:2, 3:4))

# revert contimous variable back to categorical
make.cat(Data_amal)
```

### Fitting MBD Function

``` r
# define bounds of Data
bounds <- data.frame(
  age  = c(18,80),
  education = c(0,1),
  jobclass = c(0,1),
  wage = c(0,350)
)

# fitting the data
Fit <- moped(Data_x,
             K=10, 
             Distrib = rep("Uniform", 7),
             bounds = bounds, 
             variance = T,
             recurrence = F,
             opt.mpo = T)

# extraact maximum optimal MPO

Fit$opt_mpo
```

#### check marginal densities with different polynomial K

``` r
marginal.plot(Fit, k.range = 3:8, ncol =3, prompt = FALSE)
```

### Applying the MBD Estimate

``` r
# define the observation which the probability is desired
x0 <- Data_x[2,]

pred_1 <- predict(Fit, 
                  K = 7, 
                  X = x0, 
                  type = "distribution")


# when constructing partially joint density, sample and variables must be used together.
pred_2 <- predict(Fit, 
                  K = 7, 
                  X = Data_x[,3:4], 
                  variables = c("jobclass", "wage"))
```

### Plotting Density Estimate

``` r
# marginal density
predict(Fit, K= 7, variables =4) %>%
  ggplot(aes(x = wage, y = Density)) +
  geom_line()
```

``` r
# bivariate density plot
predict(Fit, K = c(2,7), variables = 3:4) %>%
  ggplot(aes(x = jobclass, y = wage, fill = Density)) +
  geom_tile() +
  scale_fill_distiller(palette = "Spectral")
```

### Generating resampled Obs

``` r
resampled <- m.resample(Fit,
                        K = 3,
                        Sample = Data_x,
                        fixed.var = 1,
                        replicates = 1)

# marginal synthetic sample
resampled_marginal <- m.resample(Fit,
                                 Sample=Data_x[,3:4],
                                 K=c(4,4),
                                 variables = 3:4,
                                 replicates = 1)
```
