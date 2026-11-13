# Tests for get_wide_anchored_covariates ----
#

library(testthat)
library(data.table)

source(testthat::test_path(
  "..",
  "..",
  "transformations",
  "T3_study_design",
  "source_code",
  "functions",
  "anchor_studyvariables_function.R"
))

study_vars <- data.table::fread(testthat::test_path(
  "..",
  "..",
  "transformations",
  "common_configuration",
  "RWE-BRIDGE",
  "study_variables.csv"
))
d4_studycohort <- data.table::fread(testthat::test_path(
  "anchor_studyvariables",
  "input",
  "D4_StudyCohort.csv"
))
d4_studycohort[, T0 := as.Date(T0)]
d3_concepts <- data.table::fread(testthat::test_path(
  "anchor_studyvariables",
  "input",
  "D3_CONCEPTS.csv"
))
d3_concepts[, date := as.Date(date)]

metadata <- combine_metadata(study_vars)
covariate_meta <- metadata[covariate == TRUE & window_name == "covariate"]

hive_path <- file.path(tempdir(), "D4_STUDYVARIABLES_ANCHORED_wide_parquet")
if (dir.exists(hive_path)) {
  unlink(hive_path, recursive = TRUE)
}

population <- unique(d4_studycohort[, .(person_id, T0)])
anchoR::anchor_by_variable(
  population = population,
  metadata = metadata,
  concepts = d3_concepts,
  anchor_col = "T0",
  anchor_hive_path = hive_path
)

wide <- anchoR::get_anchor_result(
  metadata = covariate_meta,
  anchor_hive_path = hive_path,
  result_shape = "wide",
  population = d4_studycohort
)
data.table::setDT(wide)

test_that("wide output has one row per (person_id, T0) from D4_StudyCohort", {
  expect_equal(nrow(wide), nrow(d4_studycohort))
  expect_equal(uniqueN(wide[, .(person_id, T0)]), nrow(wide))
})

test_that("schema carries value_/date_ pairs + window_name", {
  expect_true("window_name" %in% names(wide))
  for (vid in c(
    "SV_ECOG_STATUS",
    "SV_NSCLC_HISTOLOGY"
  )) {
    expect_true(paste0("value_", vid) %in% names(wide))
    expect_true(paste0("date_", vid) %in% names(wide))
  }
})

test_that("D4_StudyCohort extras (group, start, end) survive the population join", {
  joined <- wide[d4_studycohort, on = c("person_id", "T0")]
  expect_true(all(c("group", "start", "end") %in% names(joined)))
})

test_that("variables without D3 matches are NA-scaffolded, not missing", {
  # p3 has no concepts in the fixture — every covariate value/date must be NA.
  p3 <- wide[person_id == "p3"]
  expect_equal(nrow(p3), 1L)
  expect_true(is.na(p3$value_SV_ECOG_STATUS))
  expect_true(is.na(p3$value_SV_NSCLC_HISTOLOGY))

  # Variables with no hive partition at all are still present as NA columns.
  expect_true("value_SV_AGE" %in% names(wide))
  expect_true(all(is.na(wide$value_SV_AGE)))
})

test_that("LATEST / EARLIEST values land in the right value_ cells", {
  expect_equal(as.character(wide[person_id == "p1", value_SV_ECOG_STATUS]), "1")
  expect_equal(as.character(wide[person_id == "p2", value_SV_ECOG_STATUS]), "0")
  expect_equal(
    as.character(wide[person_id == "p1", value_SV_NSCLC_HISTOLOGY]),
    "ADENO"
  )
  expect_equal(
    as.character(wide[person_id == "p2", value_SV_NSCLC_HISTOLOGY]),
    "SQUAMOUS"
  )
})
