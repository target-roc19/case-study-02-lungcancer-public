# Tests for build_fup_censoring_table() (D5 FUP & censoring table, issue #67)
#
# Function under test:
#   transformations/T4_statistical_analysis/source_code/functions/
#     fup_censoring_table_function.R
#
# Fixtures:
#   tests/testthat/D5_fup_censoring_table/input/D4_StudyCohort_FUP.csv
#   tests/testthat/D5_fup_censoring_table/expected_output/D5_fup_censoring_table.csv
library(testthat)

fn_dir <- testthat::test_path(
  "..", "..",
  "transformations", "T4_statistical_analysis", "source_code", "functions"
)
source(file.path(fn_dir, "fup_censoring_table_function.R"))

fixture_dir <- testthat::test_path("D5_fup_censoring_table")
d4_fup <- data.table::fread(
  file.path(fixture_dir, "input", "D4_StudyCohort_FUP.csv")
)
expected <- data.table::fread(
  file.path(fixture_dir, "expected_output", "D5_fup_censoring_table.csv"),
  na.strings = "",
  strip.white = FALSE
)

test_that("FUP & censoring table matches the expected_output fixture", {
  out <- build_fup_censoring_table(d4_fup)

  expect_setequal(
    names(out),
    c("label", "overall", "exposed", "control")
  )
  expect_equal(nrow(out), nrow(expected))
  expect_equal(out$label, expected$label)
  expect_equal(out$overall, expected$overall)
  expect_equal(out$exposed, expected$exposed)
  expect_equal(out$control, expected$control)
})

test_that("censoring header row has NA values across the three group columns", {
  out <- build_fup_censoring_table(d4_fup)
  hdr <- out[label == "Censoring, n (%)"]
  expect_equal(nrow(hdr), 1L)
  expect_true(is.na(hdr$overall))
  expect_true(is.na(hdr$exposed))
  expect_true(is.na(hdr$control))
})

test_that("all four codebook censoring reasons appear as rows", {
  out <- build_fup_censoring_table(d4_fup)
  expect_true(all(c(
    "Death",
    "End of max follow-up",
    "End of data collection",
    "End of study period"
  ) %in% out$label))
})

test_that("person-months total matches sum(fup_length_pyr) * 12 by group", {
  out <- build_fup_censoring_table(d4_fup)
  total_row <- out[label == "Person-months of follow-up"]
  expect_equal(
    total_row$overall,
    sprintf("%.1f", sum(d4_fup$fup_length_pyr) * 12)
  )
  expect_equal(
    total_row$exposed,
    sprintf("%.1f", sum(d4_fup[group == "EXPOSED", fup_length_pyr]) * 12)
  )
  expect_equal(
    total_row$control,
    sprintf("%.1f", sum(d4_fup[group == "CONTROL", fup_length_pyr]) * 12)
  )
})
