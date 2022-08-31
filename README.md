
<!-- README.md is generated from README.Rmd. Please edit that file -->

# moped <br> <font size="5"> **R** package for Multivariate Orthogonal Polynomial based Estimation of Density </font>

<!-- badges: start -->
<!-- badges: end -->

**moped** package estimates the multivariate orthogonal polynomial based
density function from sample moments (add reference of Brad’s paper here
and a link). Subsequently, probabilities and density of joint and
marginal distribution can be computed, and resampled values from the
estimated joint and marginal density can be generated.

## Installation

Install the **moped** version from [CRAN](https://github.com/):

``` r
install.packages("moped")
```

Or install the **development** version of moped from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
remotes::install_github("p-osh/moped")
```

## Example

Here we show an example demonstrating the capability of the **moped**
package.

``` r
library(moped)
library(tidyverse)
library(ISLR)
```

### 1. Data exploration and pre-processing

``` r
# Wage data from ISLR package
Data_full <- ISLR::Wage
# Must be a dataframe - Categorical Data should be factors
Data <- Data_full %>% select(age, education, jobclass, wage)
# Show structure of the dataset
str(Data)
# Scatter plot matrix of the Data
pairs(Data)
```

#### Converting categorical data to continuous data

``` r
Data_x <- make.cont(Data, catvar = 2:3)

# check the structure of continuous-converted data
str(Data_x)
# Conversion retrains the original categorical information
all.equal(make.cat(Data_x), Data)
```

#### (optional) Converting categorical with amalgamations

``` r
Data <- Data_full %>% select(age, maritl, race, education, jobclass, wage)

Data_amal <- make.cont(Data, catvar = c("maritl", "race", "education", "jobclass"),
                       amalgams = list(1:2, 3:4))

# revert continuous variable back to categorical
make.cat(Data_amal)
```

### 2. Fitting data to estimate the multivariate density function

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
```

#### Checking the marginal fit with different polynomial K for all variables

``` r
marginal.plot(Fit, k.range = 3:8, ncol =3, prompt = FALSE)
```

#### Determining the optimal polynomial orders with repeated k-fold cross-validation

``` r
# estimate the optimal K
val <- validate.mpo(Fit, K = 8, nfolds = 5, repeats = 10)
# Show the optimal K for each variable
val$opt_mpo_vec
```

### 3. Generating probablites and density from the estimated density

``` r
# define the observation which the probability is desired
x0 <- Data_x[2,]

pred_1 <- predict(Fit, 
                  K = val$opt_mpo_vec, 
                  X = x0, 
                  type = "distribution")


# when constructing partially joint density, sample and variables must be used together.
pred_2 <- predict(Fit, 
                  K = 7, 
                  X = Data_x[,3:4], 
                  variables = c("jobclass", "wage"))
```

### Plotting density estimate

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

### 4. Generating resampled (synthetic) observations

``` r
# resample a full sample of synthetic observations
resampled_full <- m.resample(Fit,
                        K = 3,
                        Sample = Data_x,
                        passes = 1)

# resample marginal synthetic observations
resampled_marginal <- m.resample(Fit,
                                 Sample=Data_x[,3:4],
                                 K=c(4,4),
                                 variables = 3:4,
                                 passes = 1)
```

!!!!!!!add here a histograms for both original data and synthetic data

#### (Optional) Invert the continous-converted variables back to it orginal categorical formate

``` r
resample_c <- make.cat(resample_full)
str(resample_c)
head(resample_c)
```
