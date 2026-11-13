#' 'create_d4_studycohort'
#
# Selects all eligible individuals and assigns treatment group.
# In the current study (active comparator), we do not use matching,
# but only select all eligible individuals from the eligible population.
#
#' @param d3_eligibility D3_ELIGIBILITY data input
#' @return the D4_StudyCohort data object with columns: person_id, T0, group, start, end

create_studycohort <- function(d3_eligibility) {
  # Select eligible spells (all eligible exposed and control)
  d4_studycohort <- d3_eligibility[
    eligible_exposed == TRUE | eligible_control == TRUE
  ]
  data.table::setDT(d4_studycohort)

  # Since we are looking for the first line treatment regardless of switch,
  # selecting here the first eligible spell to obtain T0 and group.
  data.table::setorder(d4_studycohort, person_id, start_episode)
  d4_studycohort <- d4_studycohort[, .SD[1L], by = person_id]

  d4_studycohort[,
    group := data.table::fifelse(
      eligible_exposed == TRUE,
      "EXPOSED",
      "CONTROL"
    )
  ]

  d4_studycohort[, T0 := start_episode]

  d4_studycohort <- d4_studycohort[, .(
    person_id,
    T0,
    group,
    start = start_episode,
    end = end_episode
  )]

  return(d4_studycohort)
}
