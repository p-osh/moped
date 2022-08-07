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


test_that("check all components in moped object are calculated", {
  expect_identical(
    c("Cn", "PolyCoef", "Poly", "MPO", "PDFControl", "NaTerms", "Cats", "Sigma",
      "Tau", "Limits", "varCn", "Distrib", "Bounds", "PnList", "Lambda", "Bn",
      "Recurrence", "KMax", "Paramaters", "Kappa", "Kappa2", "SampleStats"),
    names(fit)
    )

})

#> Test passed!






