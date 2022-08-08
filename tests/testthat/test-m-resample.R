test_that("check output is a data frame", {
  resampled <- m.resample(fit,
                          K = fit$opt_mpo)

  expect_s3_class(resampled, "data.frame")
})

#> Test passed!
