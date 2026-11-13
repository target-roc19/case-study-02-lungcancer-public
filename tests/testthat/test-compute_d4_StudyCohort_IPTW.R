# Tests for compute_d4_studycohort_iptw()
#
# Function under test:
#   transformations/T3_study_design/source_code/functions/
#     compute_d4_StudyCohort_IPTW_function.R
#
# Fixtures:
#   tests/testthat/D4_StudyCohort_IPTW/input/D4_StudyCohort_Covariates.csv
#   configuration/psmodel_variables.csv
library(testthat)

functions_dir <- testthat::test_path(
  "..", "..",
  "transformations", "T3_study_design", "source_code", "functions"
)
source(file.path(functions_dir, "CohortPropensity", "fit_ps_model.R"))
source(file.path(functions_dir, "compute_d4_StudyCohort_IPTW_function.R"))

d4_covariates <- data.table::fread(testthat::test_path(
  "D4_StudyCohort_IPTW", "input", "D4_StudyCohort_Covariates.csv"
))
ps_variables <- data.table::fread(
  testthat::test_path("..", "..", "configuration", "psmodel_variables.csv"),
  sep = ";"
)

test_that("compute returns the documented list shape", {
  res <- compute_d4_studycohort_iptw(
    d4_covariates = data.table::copy(d4_covariates),
    ps_variables = ps_variables,
    ps_trim_bounds = NULL
  )

  expect_named(
    res,
    c("D4_StudyCohort_IPTW", "D5_PS_Coef", "D5_PS_ModelBuilding"),
    ignore.order = FALSE
  )
})

test_that("D4_StudyCohort_IPTW has expected columns and one row per person", {
  res <- compute_d4_studycohort_iptw(
    d4_covariates = data.table::copy(d4_covariates),
    ps_variables = ps_variables,
    ps_trim_bounds = NULL
  )
  iptw <- res$D4_StudyCohort_IPTW

  expected_cols <- c(
    "person_id",
    "match_id",
    "T0",
    "group",
    "group_binary",
    "p_score",
    "include_after_trimming",
    "raw_iptw",
    "stabilized_iptw",
    "stabilized_trunc_iptw"
  )
  expect_setequal(names(iptw), expected_cols)
  expect_equal(nrow(iptw), nrow(d4_covariates))
  expect_setequal(unique(iptw$person_id), unique(d4_covariates$person_id))
})

test_that("p_score is a probability and weights are positive on selected rows", {
  res <- compute_d4_studycohort_iptw(
    d4_covariates = data.table::copy(d4_covariates),
    ps_variables = ps_variables,
    ps_trim_bounds = NULL
  )
  iptw <- res$D4_StudyCohort_IPTW

  expect_true(all(iptw$p_score >= 0 & iptw$p_score <= 1, na.rm = TRUE))

  selected <- iptw[include_after_trimming == TRUE]
  expect_true(all(selected$raw_iptw > 0))
  expect_true(all(selected$stabilized_iptw > 0))
  expect_true(all(selected$stabilized_trunc_iptw > 0))
})

test_that("ps_trim_bounds excludes individuals outside the bounds", {
  bounds <- c(0.2, 0.8)
  res <- compute_d4_studycohort_iptw(
    d4_covariates = data.table::copy(d4_covariates),
    ps_variables = ps_variables,
    ps_trim_bounds = bounds
  )
  iptw <- res$D4_StudyCohort_IPTW

  expect_true(all(
    iptw[include_after_trimming == TRUE, p_score] >= bounds[1] &
      iptw[include_after_trimming == TRUE, p_score] <= bounds[2]
  ))
  # Weights only populated for selected rows
  expect_true(all(is.na(iptw[include_after_trimming == FALSE, raw_iptw])))
})

test_that("D5_PS_Coef and D5_PS_ModelBuilding have expected columns", {
  res <- compute_d4_studycohort_iptw(
    d4_covariates = data.table::copy(d4_covariates),
    ps_variables = ps_variables,
    ps_trim_bounds = NULL
  )

  expect_setequal(
    names(res$D5_PS_Coef),
    c(
      "coefficient",
      "estimate",
      "std_error",
      "z_score",
      "p_value",
      "exp_estimate"
    )
  )
  expect_true("(Intercept)" %in% res$D5_PS_Coef$coefficient)

  expect_setequal(
    names(res$D5_PS_ModelBuilding),
    c(
      "variable_id",
      "var_type",
      "force_in",
      "force_out",
      "missing_pct",
      "nonzero_variance",
      "include_r1",
      "included_r2",
      "reason_excluded"
    )
  )
  expect_setequal(res$D5_PS_ModelBuilding$variable_id, ps_variables$var)
})
