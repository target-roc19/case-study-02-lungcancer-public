# Tests for build_baseline_table()
#
# Function to test:
#   transformations/T4_statistical_analysis/source_code/functions/
#     baseline_table_function.R
#
# Fixtures:
#   tests/testthat/D5_baseline_table/input/D4_StudyCohort_Covariates.csv
#   tests/testthat/D5_baseline_table/input/D4_StudyCohort_IPTW.csv
#   tests/testthat/D5_baseline_table/input/BaselineCharacteristics_metadata.csv
#   tests/testthat/D5_baseline_table/expected_output/D5_baseline_table.csv
library(testthat)

fn_dir <- testthat::test_path(
  "..",
  "..",
  "transformations",
  "T4_statistical_analysis",
  "source_code",
  "functions"
)
source(file.path(fn_dir, "baseline_table_function.R"))

fixture_dir <- testthat::test_path("D5_baseline_table")
d4_covariates <- data.table::fread(
  file.path(fixture_dir, "input", "D4_StudyCohort_Covariates.csv")
)
d4_iptw <- data.table::fread(
  file.path(fixture_dir, "input", "D4_StudyCohort_IPTW.csv")
)
baseline_metadata <- data.table::fread(
  file.path(fixture_dir, "input", "BaselineCharacteristics_metadata.csv"),
  sep = ";"
)
expected <- data.table::fread(
  file.path(fixture_dir, "expected_output", "D5_baseline_table.csv"),
  na.strings = ""
)

test_that("baseline table matches expected_output fixture", {
  out <- build_baseline_table(d4_covariates, d4_iptw, baseline_metadata)

  num_cols <- c(
    "N_unwt_overall",
    "perc_unwt_overall",
    "aux_unwt_overall",
    "N_unwt_exposed",
    "perc_unwt_exposed",
    "aux_unwt_exposed",
    "N_unwt_control",
    "perc_unwt_control",
    "aux_unwt_control",
    "N_wt_overall",
    "perc_wt_overall",
    "aux_wt_overall",
    "N_wt_exposed",
    "perc_wt_exposed",
    "aux_wt_exposed",
    "N_wt_control",
    "perc_wt_control",
    "aux_wt_control",
    "asd_unwt",
    "asd_wt"
  )
  expect_setequal(names(out), c("label", "var", "type", num_cols))
  expect_equal(nrow(out), nrow(expected))
  expect_equal(out$label, expected$label)
  expect_equal(out$var, expected$var)
  expect_equal(out$type, expected$type)
  for (col in num_cols) {
    expect_equal(
      as.numeric(out[[col]]),
      as.numeric(expected[[col]]),
      tolerance = 1e-4,
      info = col
    )
  }
})

test_that("trimmed-out persons are excluded from the cohort", {
  # Person 9 has include_after_trimming == FALSE and age 95;
  # SV_AGE summary should not be affected by that observation.
  out <- build_baseline_table(d4_covariates, d4_iptw, baseline_metadata)
  age_rows <- out[var == "SV_AGE"]
  # Q3 of EXPOSED ages {50, 60, 70, 80} is 72.5 (without trimmed-out 95).
  expect_equal(age_rows[1L, aux_unwt_exposed], 72.5)
})


test_that("variable order matches metadata order", {
  out <- build_baseline_table(d4_covariates, d4_iptw, baseline_metadata)
  seen <- setdiff(unique(stats::na.omit(out$var)), "Total")
  expect_equal(seen, baseline_metadata$var)
})

test_that("mask = TRUE masks small counts", {
  plain <- build_baseline_table(d4_covariates, d4_iptw, baseline_metadata)
  masked <- suppressWarnings(
    build_baseline_table(d4_covariates, d4_iptw, baseline_metadata, mask = TRUE)
  )
  # same shape, disclosure-controlled counts become character intervals
  expect_equal(nrow(masked), nrow(plain))
  expect_true(any(grepl("\\[", as.character(masked$N_unwt_exposed))))
  # numeric (NUM) summary rows are not masked
  expect_equal(
    masked[var == "SV_AGE", aux_unwt_exposed],
    plain[var == "SV_AGE", aux_unwt_exposed]
  )
})
