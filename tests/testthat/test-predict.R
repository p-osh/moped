test_that("check output is a data frame", {
  df_cont_1 <- df_cont[1,]
  pred <- predict(fit, K = fit$opt_mpo, X = df_cont_1)

  expect_s3_class(pred, "data.frame")
})

#> Test passed!

test_that("check joint density error ouput", {
  expect_output(pred <- predict(fit,
                               K = fit$opt_mpo,
                               X = df_cont[, 2:3]),
               "Error: Sample must be a data frame and contain columns named  carat cut clarity price")
})
#> Test passed!

test_that("check density calculation with differen X", {
  pred <- predict(fit,
                  K = fit$opt_mpo,
                  X = df_cont[, 2:3],
                  variables = c("cut", "clarity"))

  expect_identical(colnames(pred), c("cut", "clarity", "Density"))

  pred <- predict(fit,
                  K = fit$opt_mpo,
                  X = data.frame(cut = df_cont$cut),
                  variables = c("cut"))

  expect_identical(colnames(pred), c("cut", "Density"))

  pred <- predict(fit,
                  K = fit$opt_mpo,
                  X = data.frame(cut = df_cont$cut),
                  variables = 2)

  expect_identical(colnames(pred), c("cut", "Density"))
})

#> Test passed!


