test_that("check output has correct class", {
  expect_s3_class(fit, "moped")
})
#> Test passed!

test_that("check arguments are correctly passed", {

  # sample data
  expect_identical(dim(fit[["SampleStats"]][["Sample"]]), dim(df_cont))

  # maximum optimal MPO
  expect_identical(max(fit$MPO$opt.mpo), 10)

  # reference distribution
  expect_identical(fit[["Distrib"]], rep("Uniform", 4))

})

#> Test passed!


test_that("check all outputs are calculated in moped object", {
  expect_identical(c("Cn", "PolyCoef", "Poly", "MPO", "PDFControl", "NaTerms",
                     "Cats", "Sigma", "Tau", "Limits", "varCn", "Distrib",
                     "Bounds", "PnList", "Lambda", "Bn", "Recurrence", "KMax",
                     "Paramaters", "Kappa", "Kappa2", "SampleStats"),
               names(fit))

})

#> Test passed!










# test_that("check moped function", {
#   Data_full <- ISLR::Wage
#   Data <- Data_full %>%
#     dplyr::select(age, education, jobclass, wage)
#   Data_x <- make.cont(Data, catvar = 2:3)
#
#   bounds <- data.frame(
#     age  = c(18, 80),
#     education = c(0, 1),
#     jobclass = c(0, 1),
#     wage = c(0, 350)
#   )
#
#   Fit <- moped(Data_x,
#                K = 10,
#                Distrib = rep("Uniform", 7),
#                bounds = bounds,
#                variance = T,
#                recurrence = F,
#                parallel = F,
#                ncores = NULL,
#                mpo = T,
#   )
#
#   # model output has correct class
#   expect_s3_class(Fit, "moped")
#
#   # sample data is correctly passed
#   expect_identical(dim(Fit[["SampleStats"]][["Sample"]]), dim(Data_x))
#
#   # maximum optimal MPO
#   expect_identical(max(Fit$MPO$opt.mpo), 10)
#
#   # reference distribution
#   expect_equal(class(Data_x$education), "numeric")
# })
