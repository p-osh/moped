test_that("check categorical variables are continulized", {

  expect_equal(class(df_cont$cut), "numeric")
  expect_equal(class(df_cont$clarity), "numeric")
})

#> Test passed!


test_that("check specifing categorical variables by variable names", {

  df_cont_name <- make.cont(df, catvar = c("cut","clarity"))

  expect_equal(class(df_cont$cut), "numeric")
  expect_equal(class(df_cont$clarity), "numeric")
})

#> Test passed!


test_that("check amalgamated variables are continulized", {

  data_amal <- make.cont(df,
                         catvar = c("cut","clarity"),
                         amalgams = list(1:2))

  expect_equal(class(data_amal$AmalgamatedVar), "numeric")

})

#> Test passed!
