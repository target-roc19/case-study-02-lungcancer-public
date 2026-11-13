#' 'calculate_eligibility'
#
# Reduces D3_MULTIVARIATE_EPISODES to the eligibility study variables and
# computes the spell-level AND-of-criteria flags for the target population.
#
#' @param d3_multivariate_episodes time-varying spells (one row per
#'   person_id x start) with one boolean column per study variable
#' @return D3_ELIGIBILITY data.table: person_id, start, end, the eligibility
#'   SVs, plus in_eligible_pop / eligible_exposed / eligible_control
#'
#' @details The `SV_NSCLC_DIAGNOSIS` obtained using flag read from D3_CONCEPTS to reflect the 2022-2024 inclusion
#'   window and feeds `in_eligible_pop`
calculate_eligibility <- function(d3_multivariate_episodes) {
  d3_eligibility <- d3_multivariate_episodes

  if (exists("config_project", inherits = TRUE)) {
    nsclc_records <- data.table::as.data.table(as.data.frame(
      arrow::open_dataset(file.path(
        config_project$episodes_and_eligibility$d3_all_concepts,
        "concept_id=NSCLC_DIAGNOSIS"
      ))
    ))
    # Coerce person_id to character on both sides
    nsclc_persons_in_window <- unique(nsclc_records[
      as.Date(date) >= as.Date(config_values$start_study_date) &
        as.Date(date) <= as.Date(config_values$end_study_date),
      as.character(person_id)
    ])
    d3_eligibility[,
      SV_NSCLC_DIAGNOSIS := as.character(person_id) %in% nsclc_persons_in_window
    ]
  }

  d3_eligibility[, ECOG_LE_1 := SV_ECOG_STATUS <= 1]

  d3_eligibility[,
    in_eligible_pop := SV_NSCLC_DIAGNOSIS &
      SV_AGE_18_OR_OLDER &
      SV_FIRST_NSCLC_DIAGNOSIS &
      SV_CSTAGE4 &
      SV_PDL_BELOW_1 &
      SV_RECEIVED_CT &
      ECOG_LE_1 &
      !SV_MUTATION_ALK_ROS1_EGFR &
      !SV_PREVIOUS_CANCER_DIAGNOSIS &
      (SV_NIVOLUMAB_AND_IPILIMUMAB | SV_PEMBROLIZUMAB)
  ]

  d3_eligibility[,
    eligible_exposed := in_eligible_pop & SV_NIVOLUMAB_AND_IPILIMUMAB
  ]
  d3_eligibility[, eligible_control := in_eligible_pop & SV_PEMBROLIZUMAB]

  return(d3_eligibility)
}
