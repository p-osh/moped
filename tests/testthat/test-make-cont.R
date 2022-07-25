test_that("check categorical variables are continulized", {
  Data_full <- ISLR::Wage
  Data <- Data_full %>%
    select(age, education, jobclass, wage)
  Data_x <- make.cont(Data,catvar = 2:3)

  expect_equal(class(Data_x$education), "numeric")
  expect_equal(class(Data_x$jobclass), "numeric")
})





