test_that("checking categorical variables are continulized", {
  Data_full <- ISLR::Wage
  Data <- Data_full %>%
    select(age, education, jobclass, wage)
  Data_x <- make.cont(Data,catvar = 2:3)

  expect_that(Data_x$education, is_a("numeric"))
  expect_that(Data_x$jobclass, is_a("numeric"))
})





