test_that("check plot is printed", {
  p <- marginal.plot(fit)

  expect_error(print(p), NA)
})

#> Test passed!


test_that("Scale is labelled 'Proportion'",{
  p <- plot_fun(df)
  expect_true(is.ggplot(p))
  expect_identical(p$labels$y, "Proportion")

  p <- plot_fun(df2)
  expect_true(is.ggplot(p))
  expect_identical(p$labels$y, "Proportion")
})




# marginal.plot(fit, k.range = 3:8, ncol =3, prompt = FALSE)
#
# marginal.plot(fit)


