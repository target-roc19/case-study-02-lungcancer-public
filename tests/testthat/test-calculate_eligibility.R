# Tests for calculate_eligibility()
#
# Function under test:
#   transformations/T3_study_design/source_code/functions/
#     calculate_eligibility_function.R
#
# Fixture:
#   tests/testthat/D3_ELIGIBILITY/input/D3_MULTIVARIATE_EPISODES.csv
#   tests/testthat/D3_ELIGIBILITY/expected_output/D3_ELIGIBILITY.csv
library(testthat)

source(testthat::test_path(
  "..",
  "..",
  "transformations",
  "T3_study_design",
  "source_code",
  "functions",
  "calculate_eligibility_function.R"
))

input <- data.table::fread(
  testthat::test_path("D3_ELIGIBILITY", "input", "D3_MULTIVARIATE_EPISODES.csv")
)
expected <- data.table::fread(
  testthat::test_path("D3_ELIGIBILITY", "expected_output", "D3_ELIGIBILITY.csv")
)

test_that("schema matches the codebook columns in documented order", {
  actual <- calculate_eligibility(data.table::copy(input))
  expect_named(
    actual,
    c(
      "person_id",
      "start",
      "end",
      "SV_AGE_18_OR_OLDER",
      "SV_FIRST_NSCLC_DIAGNOSIS",
      "SV_NSCLC_DIAGNOSIS",
      "SV_CSTAGE4",
      "SV_PDL_BELOW_1",
      "SV_RECEIVED_CT",
      "SV_ECOG_STATUS",
      "SV_MUTATION_ALK_ROS1_EGFR",
      "SV_PREVIOUS_CANCER_DIAGNOSIS",
      "SV_NIVOLUMAB_AND_IPILIMUMAB",
      "SV_PEMBROLIZUMAB",
      "ECOG_LE_1",
      "in_eligible_pop",
      "eligible_exposed",
      "eligible_control"
    )
  )
})

test_that("output matches hand-computed fixture row-for-row", {
  actual <- calculate_eligibility(data.table::copy(input))
  expect_equal(actual, expected, ignore_attr = TRUE)
})

test_that("eligible_exposed and eligible_control are mutually exclusive", {
  actual <- calculate_eligibility(data.table::copy(input))
  expect_false(any(actual$eligible_exposed & actual$eligible_control))
})

test_that("in_eligible_pop spells receive exactly one treatment flag", {
  actual <- calculate_eligibility(data.table::copy(input))
  eligible <- actual[in_eligible_pop == TRUE]
  expect_true(all(xor(
    eligible$SV_NIVOLUMAB_AND_IPILIMUMAB,
    eligible$SV_PEMBROLIZUMAB
  )))
})

test_that("errors when a required study variable is absent", {
  broken <- data.table::copy(input)
  broken[, SV_ECOG_STATUS := NULL]
  expect_error(calculate_eligibility(broken))
})
