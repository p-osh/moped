test_that("check plot is printed", {
  p <- marginal.plot(fit)

  expect_error(print(p), NA)
})


# marginal.plot(fit, k.range = 3:8, ncol =3, prompt = FALSE)
#
# marginal.plot(fit)
