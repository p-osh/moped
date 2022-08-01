df <- ggplot2::diamonds %>%
  dplyr::select(carat, cut, clarity, price) %>%
  head(1000) %>%
  as.data.frame()

df_cont <- make.cont(df, catvar = 2:3)

bounds <- data.frame(
  carat  = c(0, 1.3),
  cut = c(0, 1),
  clarity = c(0, 1),
  price = c(300, 2900)
)

fit <- moped(df_cont,
             K = 10,
             Distrib = rep("Uniform", 4),
             bounds = bounds,
             variance = T,
             recurrence = F,
             parallel = F,
             ncores = NULL,
             mpo = T,
)
