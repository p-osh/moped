test_that("check plot is printed", {
  p <- marginal.plot(fit)

  expect_error(print(p), NA)
})

#> Test passed!





