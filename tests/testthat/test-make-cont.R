test_that("check categorical variables are continulized", {
  Data_full <- ISLR::Wage
  Data <- Data_full %>%
    dplyr::select(age, education, jobclass, wage)
  Data_x <- make.cont(Data, catvar = 2:3)

  expect_equal(class(Data_x$education), "numeric")
  expect_equal(class(Data_x$jobclass), "numeric")
})

#> Test passed!



# test_that("check categorical variables are continulized with amalgamations", {
#   Data_full <- ISLR::Wage
#   Data <- Data_full %>%
#     dplyr::select(age, maritl, race, education, jobclass, wage)
#   Data_x <- make.cont(Data,
#                       catvar = c("maritl","race","education","jobclass"),
#                       amalgams = list(1:2,3:4))
#
#   expect_equal() #???? reorder first
#   make.cat....
# })

