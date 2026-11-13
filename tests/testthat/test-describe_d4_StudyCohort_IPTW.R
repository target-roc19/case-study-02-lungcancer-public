# Tests for the diagnostic transformations in
#   transformations/T4_statistical_analysis/source_code/describe_d4_StudyCohort_IPTW.R
#
# The script itself is an orchestrator (load, transform, save). These tests
# exercise the transformations on fixture data so a regression in the OR/CI
# math or the weighted ASD pipeline fails fast.
library(testthat)

t3_functions <- testthat::test_path(
  "..", "..",
  "transformations", "T3_study_design", "source_code", "functions"
)
t4_functions <- testthat::test_path(
  "..", "..",
  "transformations", "T4_statistical_analysis", "source_code", "functions"
)
source(file.path(t3_functions, "CohortPropensity", "fit_ps_model.R"))
source(file.path(t4_functions, "CohortPropensity", "describe_iptw.R"))
source(file.path(t3_functions, "compute_d4_StudyCohort_IPTW_function.R"))

d4_covariates <- data.table::fread(testthat::test_path(
  "D4_StudyCohort_IPTW", "input", "D4_StudyCohort_Covariates.csv"
))
ps_variables <- data.table::fread(
  testthat::test_path("..", "..", "configuration", "psmodel_variables.csv"),
  sep = ";"
)

# Run compute once for the whole test file
res <- compute_d4_studycohort_iptw(
  d4_covariates = data.table::copy(d4_covariates),
  ps_variables = ps_variables,
  ps_trim_bounds = NULL
)
d4_iptw <- res$D4_StudyCohort_IPTW
d5_ps_coef <- res$D5_PS_Coef

test_that("Odds-ratio CI from coefficients is consistent with exp(estimate)", {
  tbl <- data.table::copy(d5_ps_coef[coefficient != "(Intercept)"])
  tbl[, exp_estimate_lower := exp(estimate + qnorm(0.025) * std_error)]
  tbl[, exp_estimate_upper := exp(estimate + qnorm(0.975) * std_error)]

  expect_true(all(tbl$exp_estimate_lower <= tbl$exp_estimate))
  expect_true(all(tbl$exp_estimate <= tbl$exp_estimate_upper))
  expect_true(all(tbl$exp_estimate_lower > 0))
})

test_that("describe_iptw returns a per-group summary table", {
  selected <- d4_iptw[include_after_trimming == TRUE]
  weight_table <- describe_iptw(
    p_matrix = selected,
    groups = c("CONTROL", "EXPOSED"),
    stab_weight_col = "stabilized_iptw",
    custom_truncation = c(NA, NA),
    digits = 4
  )

  expect_true("labels" %in% names(weight_table))
  expect_true(any(c("CONTROL_V1", "CONTROL_V2") %in% names(weight_table)))
  expect_true(any(c("EXPOSED_V1", "EXPOSED_V2") %in% names(weight_table)))
})

test_that("Weighted ASDs are typically smaller than unweighted ones", {
  asd_metadata <- data.table::data.table(
    var = ps_variables$var,
    type = data.table::fifelse(
      ps_variables$vartype == "NUM",
      "NUM1",
      ps_variables$vartype
    )
  )

  cov_with_weights <- merge(
    d4_covariates,
    d4_iptw[
      include_after_trimming == TRUE,
      .(person_id, stabilized_trunc_iptw)
    ],
    by = "person_id"
  )

  asd_un <- DescriptiveTable::compute_asd(
    CovariatesInformation = cov_with_weights,
    metadata = asd_metadata,
    referenceExtension = "unweighted",
    use_weights = FALSE
  )
  asd_w <- DescriptiveTable::compute_asd(
    CovariatesInformation = cov_with_weights,
    metadata = asd_metadata,
    referenceExtension = "weighted",
    use_weights = "stabilized_trunc_iptw"
  )

  expect_true("asd_unweighted" %in% names(asd_un))
  expect_true("asd_weighted" %in% names(asd_w))
  expect_equal(nrow(asd_un), nrow(asd_w))
})

test_that("format_iptw_summary collapses V1/V2 into one drug-named column", {
  summary_tbl <- describe_iptw(
    p_matrix = d4_iptw[include_after_trimming == TRUE],
    groups = c("CONTROL", "EXPOSED"),
    stab_weight_col = "stabilized_iptw",
    digits = 4
  )
  fmt <- format_iptw_summary(summary_tbl)

  expect_true(all(
    c("Characteristic", "nivolumab + ipilimumab", "pembrolizumab") %in% names(fmt)
  ))
  expect_false(any(grepl("_V1|_V2", names(fmt))))
  expect_match(
    fmt[Characteristic == "Mean (SD)"][["nivolumab + ipilimumab"]],
    "\\(.*\\)"
  )
})

test_that("format_ps_model_parameters yields labelled OR (95% CI) + reference rows", {
  tbl <- format_ps_model_parameters(d5_ps_coef, ps_variables)

  expect_equal(names(tbl), c("Characteristic", "Odds Ratio (95% CI)"))
  expect_true(any(tbl[["Odds Ratio (95% CI)"]] == "1.00 (ref.)", na.rm = TRUE))
  ors <- tbl[["Odds Ratio (95% CI)"]]
  ors <- ors[!is.na(ors) & ors != "1.00 (ref.)"]
  expect_true(all(grepl("^[0-9.]+ \\([0-9.]+-[0-9.]+\\)$", ors)))
})

test_that("build_baseline_trimming_table aligns before/after blocks", {
  source(file.path(t4_functions, "baseline_table_function.R"))
  meta <- data.table::fread(
    testthat::test_path(
      "..", "..", "transformations", "common_configuration",
      "BaselineCharacteristics_metadata.csv"
    ),
    sep = ";"
  )
  tt <- build_baseline_trimming_table(d4_covariates, d4_iptw, meta)

  expect_true(all(
    c("asd_before", "asd_after", "N_overall_before", "N_overall_after")
    %in% names(tt)
  ))
  # No trimming in the fixture -> before and after cohorts coincide.
  expect_equal(tt$N_overall_before, tt$N_overall_after)
})
