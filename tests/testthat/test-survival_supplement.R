# Tests for the supplemental survival figures
#
# Functions under test:
#   transformations/T4_statistical_analysis/source_code/functions/
#     survival_supplement_function.R
library(testthat)

fn_dir <- testthat::test_path(
  "..",
  "..",
  "transformations",
  "T4_statistical_analysis",
  "source_code",
  "functions"
)
source(file.path(fn_dir, "survival_supplement_function.R"))

lookup <- data.table::fread(testthat::test_path(
  "D4_StudyCohort_Analysis",
  "input",
  "D4_StudyCohort_Analysis.csv"
))

test_that("crude and IPTW Kaplan-Meier plots build", {
  expect_s3_class(plot_km(lookup, weighted = FALSE), "ggplot")
  expect_s3_class(plot_km(lookup, weighted = TRUE), "ggplot")
})

test_that("Schoenfeld and log-log plots build", {
  expect_s3_class(plot_schoenfeld(lookup), "ggplot")
  expect_s3_class(plot_loglog(lookup), "ggplot")
})

test_that("tidied survfit starts each group at (0, 1)", {
  fit <- survival::survfit(
    survival::Surv(fup_days, event_death) ~ group,
    data = .group_factor(data.table::as.data.table(lookup))
  )
  km <- .tidy_survfit(fit)
  anchors <- km[time == 0]
  expect_true(all(anchors$surv == 1))
  expect_equal(nrow(anchors), data.table::uniqueN(km$group))
})
