# Tests for anchor_studyvariables ----
#
# Covers: combine_metadata() and anchoR::anchor_by_variable()

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
d3_concepts <- data.table::fread(testthat::test_path(
  "anchor_studyvariables",
  "input",
  "D3_CONCEPTS.csv"
))
d3_concepts[, date := as.Date(date)]

metadata <- combine_metadata(study_vars)

test_that("anchor_by_variable writes a hive partitioned by variable_id", {
  hive_path <- file.path(tempdir(), "D4_STUDYVARIABLES_ANCHORED_parquet")
  if (dir.exists(hive_path)) {
    unlink(hive_path, recursive = TRUE)
  }

  population <- unique(
    d4_studycohort[, .(person_id, T0 = as.Date(T0))]
  )

  anchoR::anchor_by_variable(
    population = population,
    metadata = metadata,
    concepts = d3_concepts,
    anchor_col = "T0",
    anchor_hive_path = hive_path
  )

  parts <- list.dirs(hive_path, recursive = FALSE, full.names = FALSE)
  # At minimum the two variables with fixture matches must show up.
  expect_true(all(
    paste0(
      "variable_id=",
      c(
        "SV_ECOG_STATUS",
        "SV_NSCLC_HISTOLOGY"
      )
    ) %in%
      parts
  ))
})

test_that("LATEST selector picks the most recent value within the window", {
  hive_path <- file.path(tempdir(), "D4_STUDYVARIABLES_ANCHORED_parquet")
  ecog <- anchoR::get_anchor_result(
    metadata = metadata[variable_id == "SV_ECOG_STATUS"],
    anchor_hive_path = hive_path,
    result_shape = "long"
  )
  data.table::setDT(ecog)
  ecog <- ecog[window_name == "covariate"]

  # p1 has ECOG=0 (2023-11-20) and ECOG=1 (2023-12-15) within [-90, 0] of T0;
  # LATEST must pick 2023-12-15 / value = "1".
  p1 <- ecog[person_id == "p1"]
  expect_equal(nrow(p1), 1L)
  expect_equal(as.character(p1$value), "1")
  expect_equal(as.Date(p1$date), as.Date("2023-12-15"))
})
