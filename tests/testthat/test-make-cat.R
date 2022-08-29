
test_that("check continulized variables are converted back to categorical.", {

  df_cat <- make.cat(df_cont)

  expect_equal(class(df_cat$cut), "factor")
  expect_equal(class(df_cat$clarity), "factor")
})

#> Test passed!
