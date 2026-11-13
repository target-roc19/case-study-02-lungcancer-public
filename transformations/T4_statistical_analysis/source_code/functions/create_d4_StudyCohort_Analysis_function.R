#' Assemble the analysis data for outcome analyses
#'
#' @param d4_fup D4_StudyCohort_FUP  -- person_id, T0, group, fup_length_days,
#'   fup_length_pyr, event_death, reason_censoring.
#' @param d4_iptw D4_StudyCohort_IPTW -- person_id, T0, p_score,
#'   include_after_trimming, stabilized_trunc_iptw.
#' @param d4_covariates D4_StudyCohort_Covariates -- used only for the forest
#'   subgroup labels (histology, collapsed CNS metastasis/radiotherapy).
#'
#' @return data.table with one row per person: person_id, group, fup_days, pyr,
#'   event_death, reason_censoring, p_score, include_after_trimming, ip_weight,
#'   the squamous and brain-metastasis forest subgroup labels.
create_d4_studycohort_analysis <- function(d4_fup, d4_iptw, d4_covariates) {
  fup <- data.table::as.data.table(d4_fup)
  iptw <- data.table::as.data.table(d4_iptw)
  cov <- data.table::as.data.table(d4_covariates)

  # Align person_id and T0 types
  for (dt in list(fup, iptw, cov)) {
    dt[, `:=`(person_id = as.character(person_id), T0 = as.Date(T0))]
  }

  # Forest-plot subgroup labels
  brain_labels <- c(
    NO_CNS_MET = "No CNS metastases",
    CNS_NO_RT = "CNS metastases, no radiotherapy",
    CNS_WITH_RT = "CNS metastases, with radiotherapy"
  )
  cov_sub <- cov[, .(
    person_id,
    subgroup_squamous = data.table::fifelse(
      toupper(as.character(SV_NSCLC_HISTOLOGY)) == "SQUAMOUS",
      "Squamous",
      "Non-squamous"
    ),
    subgroup_brain = unname(brain_labels[SV_CNS_MET_RT])
  )]

  # Left join on the followed-up cohort: every FUP person, weights attached
  # where an IPTW row exists. Trimmed persons are kept (flagged by
  # include_after_trimming) and filtered per estimate downstream.
  lookup <- data.table::merge.data.table(
    fup[, .(
      person_id,
      T0,
      group,
      fup_days = fup_length_days,
      pyr = fup_length_pyr,
      event_death,
      reason_censoring
    )],
    iptw[, .(
      person_id,
      p_score,
      include_after_trimming,
      ip_weight = stabilized_trunc_iptw
    )],
    by = "person_id",
    all.x = TRUE,
    all.y = FALSE
  )

  lookup <- data.table::merge.data.table(
    lookup,
    cov_sub,
    by = "person_id",
    all.x = TRUE,
    all.y = FALSE
  )

  data.table::setkey(lookup, person_id)
  lookup[]
}
