# Tests for the outcome analysis functions
#
# Functions under test:
#   transformations/T4_statistical_analysis/source_code/functions/
#     outcome_analysis_function.R
library(testthat)

fn_dir <- testthat::test_path(
  "..",
  "..",
  "transformations",
  "T4_statistical_analysis",
  "source_code",
  "functions"
)
source(file.path(fn_dir, "outcome_analysis_function.R"))

lookup <- data.table::fread(testthat::test_path(
  "D4_StudyCohort_Analysis",
  "input",
  "D4_StudyCohort_Analysis.csv"
))

test_that("HR table has one row per arm and pembrolizumab is the reference", {
  hr <- build_outcome_hr_table(lookup)
  expect_equal(nrow(hr), 2L)
  expect_setequal(
    hr$treatment_group,
    c("nivolumab + ipilimumab", "pembrolizumab")
  )
  ref <- hr[treatment_group == "pembrolizumab"]
  expect_equal(ref$crude_hr, "ref")
  expect_equal(ref$adj_hr, "ref")
  # crude denominators cover the whole cohort
  expect_equal(sum(hr$n_crude), nrow(lookup))
  expect_equal(sum(hr$n_events_crude), sum(lookup$event_death))
  # adjusted denominators cover the trimmed set
  expect_equal(sum(hr$n_adj), nrow(lookup[include_after_trimming == TRUE]))
})

test_that("cox_hr returns NA when an arm has no events", {
  dt <- .prep(
    data.table::data.table(
      person_id = as.character(1:6),
      group = rep(c("EXPOSED", "CONTROL"), each = 3),
      fup_days = c(100, 200, 300, 100, 200, 300),
      event_death = c(1L, 1L, 1L, 0L, 0L, 0L),
      ip_weight = 1
    ),
    weighted = FALSE
  )
  expect_true(is.na(cox_hr(dt)[["est"]]))
})

test_that("forest data has an Overall row plus one row per subgroup level", {
  fd <- build_forest_data(lookup)
  expect_true("Overall" %in% fd$subgroup)
  n_levels <- sum(vapply(FOREST_SUBGROUPS, function(s) length(s$levels), integer(1)))
  expect_equal(nrow(fd), 1L + n_levels)
  # each subgroup's strata partition the trimmed cohort
  trimmed_n <- nrow(lookup[include_after_trimming == TRUE])
  for (sg in FOREST_SUBGROUPS) {
    expect_equal(sum(fd[subgroup %in% sg$levels]$n), trimmed_n)
  }
})

test_that("forest plot builds", {
  expect_s3_class(plot_forest(build_forest_data(lookup)), "ggplot")
})

test_that("mask_hr_table masks small counts and NRs their person-years", {
  hr <- data.table::data.table(
    treatment_group = c("nivolumab + ipilimumab", "pembrolizumab"),
    n_crude = c(3, 120),
    n_events_crude = c(2, 50),
    person_years_crude = c(10.5, 300.2),
    n_adj = c(80, 118),
    n_events_adj = c(30, 49),
    person_years_adj = c(200.1, 295.0)
  )
  out <- suppressWarnings(mask_hr_table(hr))
  # small exposed cell ->  control cell also masked
  expect_match(out$n_crude[1], "\\[")
  expect_match(out$n_crude[2], "\\[")
  # masked estimate -> person-years reported as NR
  expect_equal(out$person_years_crude, c("NR", "NR"))
  # estimate has no small cell -> untouched
  expect_equal(out$person_years_adj, c("200.1", "295"))
  expect_false(any(grepl("\\[", out$n_adj)))
})
