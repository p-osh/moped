test_that("check continulized variables are converted back to categorical.", {
  Data_full <- ISLR::Wage
  Data <- Data_full %>%
    dplyr::select(age, education, jobclass, wage)
  Data_x <- make.cont(Data, catvar = 2:3)
  Data_y <- make.cat(Data_x)

  expect_equal(class(Data_y$education), "factor")
  expect_equal(class(Data_y$jobclass), "factor")
})

#> Test passed!
