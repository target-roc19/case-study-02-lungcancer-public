#' Combine study_variables.csv into anchoR metadata.
#'
#' Drops rows that are purely eligibility variables (no covariate flag) since
#' they are already evaluated as a status in D3_ELIGIBILITY. Variables that
#' are both eligibility and covariate (e.g. SV_ECOG_STATUS) are kept because
#' they still need to be anchored at T0 for D4_StudyCohort_Covariates.
#'
#' Adds `variable_type` and `is_expected_missing` so anchoR::get_anchor_result(
#' impute_missing = TRUE) can fill NA cells per the bridge's `missing_set_to`.
#'
#' @param study_vars data.table - RWE-BRIDGE study_variables.csv
#' @return data.table satisfying anchoR::validate_anchor_inputs()
#' @export
combine_metadata <- function(study_vars) {
  data.table::setDT(study_vars)
  sv <- data.table::copy(study_vars)

  n_before <- nrow(sv)
  # Drop eligibility-only rows (evaluated in D3_ELIGIBILITY) and outcome rows
  # (SV_DEATH_DATE is read from D3_PERSONS in D4_StudyCohort_FUP, and has no
  # look-back window to anchor on).
  sv <- sv[(eligibility != TRUE | covariate == TRUE) & outcome != TRUE]
  logger::log_info(
    "Kept {n_after} of {n_before} study variable(s) (dropped eligibility-only and outcome).",
    n_after = nrow(sv),
    n_before = n_before
  )

  sv <- anchoR::filter_supported_metadata(
    sv,
    selector_col = "data_extraction_func"
  )

  sv[, .(
    variable_id,
    concept_id,
    window_name = "covariate",
    constructor = "GENERIC",
    selector = toupper(data_extraction_func),
    start_offset = as.integer(start_look_back),
    end_offset = as.integer(end_look_back),
    data_type,
    variable_type = data_type,
    missing_set_to,
    is_expected_missing = missing_set_to == "NULL",
    covariate,
    eligibility,
    exposure,
    outcome
  )]
}
