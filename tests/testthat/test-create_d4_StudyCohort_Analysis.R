# Tests for create_d4_studycohort_analysis()
#
# Function under test:
#   transformations/T4_statistical_analysis/source_code/functions/
#     create_d4_StudyCohort_Analysis_function.R
library(testthat)

fn_dir <- testthat::test_path(
  "..",
  "..",
  "transformations",
  "T4_statistical_analysis",
  "source_code",
  "functions"
)
source(file.path(fn_dir, "create_d4_StudyCohort_Analysis_function.R"))

d4_fup <- data.table::fread(testthat::test_path(
  "D5_fup_censoring_table",
  "input",
  "D4_StudyCohort_FUP.csv"
))
d4_iptw <- data.table::fread(testthat::test_path(
  "D5_baseline_table",
  "input",
  "D4_StudyCohort_IPTW.csv"
))
d4_cov <- data.table::fread(testthat::test_path(
  "D5_baseline_table",
  "input",
  "D4_StudyCohort_Covariates.csv"
))

test_that("lookup has the expected schema and one row per followed-up person", {
  lk <- create_d4_studycohort_analysis(d4_fup, d4_iptw, d4_cov)

  expect_setequal(
    names(lk),
    c(
      "person_id",
      "T0",
      "group",
      "fup_days",
      "pyr",
      "event_death",
      "reason_censoring",
      "p_score",
      "include_after_trimming",
      "ip_weight",
      "subgroup_squamous",
      "subgroup_brain"
    )
  )
  # left join keeps every followed-up person
  expect_equal(nrow(lk), data.table::uniqueN(d4_fup$person_id))
  expect_equal(data.table::uniqueN(lk$person_id), nrow(lk))
})

test_that("keys are aligned to character/Date and weights are numeric", {
  lk <- create_d4_studycohort_analysis(d4_fup, d4_iptw, d4_cov)
  expect_type(lk$person_id, "character")
  expect_s3_class(lk$T0, "Date")
  expect_type(lk$ip_weight, "double")
  expect_type(lk$event_death, "integer")
})

test_that("subgroup labels are character with the expected levels", {
  lk <- create_d4_studycohort_analysis(d4_fup, d4_iptw, d4_cov)
  expect_type(lk$subgroup_squamous, "character")
  expect_true(all(lk$subgroup_squamous %in% c("Squamous", "Non-squamous")))
  expect_type(lk$subgroup_brain, "character")
  expect_true(all(lk$subgroup_brain %in% c(
    "No brain metastases", "Brain metastases, no RT", "Brain metastases, with RT"
  )))
})
