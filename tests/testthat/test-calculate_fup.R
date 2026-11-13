# Tests for calculate_fup() (D4_StudyCohort_FUP producer)
#
# Function under test:
#   transformations/T3_study_design/source_code/functions/
#     calculate_fup_function.R
#
# Fixture: tests/testthat/calculate_fup/input/{D4_StudyCohort,D3_PERSONS}.csv
# Designed to cover all four censoring reasons in 4 rows:
#   p1: Death on 2024-03-15 (T0 2023-02-01).
#   p2: max_fup_date reached first (T0 2022-06-10, max_fup_days=1126 → 2025-07-10).
#   p3: end_of_data_collection reached first (2026-01-01, well before max_fup).
#   p4: end_study_period reached first (2026-06-01, before max_fup).

library(testthat)
library(data.table)

source(testthat::test_path(
  "..",
  "..",
  "transformations",
  "T3_study_design",
  "source_code",
  "functions",
  "calculate_fup_function.R"
))

d4_studycohort <- fread(testthat::test_path(
  "calculate_fup",
  "input",
  "D4_StudyCohort.csv"
))
d3_persons <- fread(testthat::test_path(
  "calculate_fup",
  "input",
  "D3_PERSONS.csv"
))

# Distinct end_study_period (2026-06-01) and end_of_data_collection (2026-01-01)
# so the precedence test isn't ambiguous.
out <- calculate_fup(
  d4_studycohort = d4_studycohort,
  d3_persons = d3_persons,
  end_study_date = as.Date("2026-06-01"),
  end_of_data_collection_date = as.Date("2026-01-01"),
  max_fup_days = 1126L
)

test_that("output has codebook column set, one row per cohort person", {
  expect_setequal(
    names(out),
    c(
      "person_id",
      "T0",
      "group",
      "end_study_period",
      "end_of_data_collection",
      "date_death",
      "max_fup_date",
      "general_end_fup",
      "reason_censoring",
      "fup_length_days",
      "fup_length_pyr",
      "event_death"
    )
  )
  expect_equal(nrow(out), nrow(d4_studycohort))
  expect_equal(uniqueN(out$person_id), nrow(out))
})

test_that("max_fup_date = T0 + max_fup_days", {
  expect_equal(out$max_fup_date, out$T0 + 1126L)
})

test_that("Death takes precedence and event_death = 1", {
  p1 <- out[person_id == "1"]
  expect_equal(p1$reason_censoring, "Death")
  expect_equal(p1$general_end_fup, as.Date("2024-03-15"))
  expect_equal(p1$event_death, 1L)
})

test_that("End of max follow-up applies when max_fup is the earliest", {
  p2 <- out[person_id == "2"]
  expect_equal(p2$reason_censoring, "End of max follow-up")
  expect_equal(p2$general_end_fup, as.Date("2022-06-10") + 1126L)
  expect_equal(p2$event_death, 0L)
})

test_that("End of data collection applies when it precedes end_study_period", {
  p3 <- out[person_id == "3"]
  expect_equal(p3$reason_censoring, "End of data collection")
  expect_equal(p3$general_end_fup, as.Date("2026-01-01"))
  expect_equal(p3$event_death, 0L)
})

test_that("End of study period applies when it is the earliest", {
  # p4 T0 = 2023-01-15, max_fup = 2026-02-15, end_study = 2026-06-01,
  # end_of_data = 2026-01-01. min is end_of_data (2026-01-01). So with this
  # fixture p4 is also End of data collection — confirm precedence rules
  # against the codebook by switching end_study earlier than end_of_data:
  out_swap <- calculate_fup(
    d4_studycohort = d4_studycohort,
    d3_persons = d3_persons,
    end_study_date = as.Date("2025-12-01"),
    end_of_data_collection_date = as.Date("2026-06-01"),
    max_fup_days = 1126L
  )
  p4 <- out_swap[person_id == "4"]
  expect_equal(p4$reason_censoring, "End of study period")
  expect_equal(p4$general_end_fup, as.Date("2025-12-01"))
  expect_equal(p4$event_death, 0L)
})

test_that("fup_length_days = general_end_fup - T0 + 1; pyr = days/365.25", {
  expect_equal(
    out$fup_length_days,
    as.integer(out$general_end_fup - out$T0 + 1L)
  )
  expect_equal(out$fup_length_pyr, out$fup_length_days / 365.25)
})

test_that("scalar end dates are broadcast to every row", {
  expect_true(all(out$end_study_period == as.Date("2026-06-01")))
  expect_true(all(out$end_of_data_collection == as.Date("2026-01-01")))
})
