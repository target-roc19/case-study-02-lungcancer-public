# Tests for build_attrition_table() + flowchart construction
#
# Function under test:
#   transformations/T4_statistical_analysis/source_code/functions/
#     attrition_table_function.R
#
# Fixtures:
#   tests/testthat/D5_attrition_table/input/D3_ELIGIBILITY.csv
#   tests/testthat/D5_attrition_table/expected_output/D5_attrition_table.csv
#   tests/testthat/D5_attrition_table/expected_output/D5_attrition_flowchart.csv
library(testthat)

source(testthat::test_path(
  "..", "..",
  "transformations", "T4_statistical_analysis", "source_code", "functions",
  "attrition_table_function.R"
))

d3_eligibility <- data.table::fread(
  testthat::test_path("D5_attrition_table", "input", "D3_ELIGIBILITY.csv")
)
expected_table <- data.table::fread(
  testthat::test_path(
    "D5_attrition_table", "expected_output", "D5_attrition_table.csv"
  )
)
expected_flowchart <- data.table::fread(
  testthat::test_path(
    "D5_attrition_table", "expected_output", "D5_attrition_flowchart.csv"
  )
)

test_that("attrition table matches the expected_output fixture", {
  out <- build_attrition_table(d3_eligibility)

  expect_setequal(names(out), c("step", "label", "n", "pct"))
  expect_equal(nrow(out), nrow(expected_table))
  expect_equal(out$step, expected_table$step)
  expect_equal(out$label, expected_table$label)
  expect_equal(out$n, expected_table$n)
  expect_equal(out$pct, expected_table$pct)
})

test_that("cumulative counts are non-increasing across criteria steps", {
  out <- build_attrition_table(d3_eligibility)
  expect_true(all(diff(out[step <= 10L, n]) <= 0))
})

test_that("exposed + control split sums to eligible population", {
  out <- build_attrition_table(d3_eligibility)
  exposed <- out[label == "Eligible nivolumab + ipilimumab + chemotherapy", n]
  control <- out[label == "Eligible pembrolizumab + chemotherapy", n]
  total_eligible <- out[label == "Total Eligible Cohort", n]
  expect_equal(exposed + control, total_eligible)
  expect_equal(total_eligible, out[step == 10L, n])
})

test_that("attrition criteria sum up to in_eligible_pop", {
  out <- build_attrition_table(d3_eligibility)
  last_consecutive_criteria <- out[step == 10, n]
  in_eligible_pop <- data.table::uniqueN(d3_eligibility[
    in_eligible_pop == TRUE,
    person_id
  ])
  expect_equal(last_consecutive_criteria, in_eligible_pop)
})

test_that("flowchart deltas equal the per-step exclusion counts", {
  out <- build_attrition_table(d3_eligibility)
  flowchart_n <- as.integer(-diff(out[step <= 10L, n]))

  expect_equal(flowchart_n, expected_flowchart$n_excluded)
  expect_equal(sum(flowchart_n), out[step == 1L, n] - out[step == 10L, n])
})
