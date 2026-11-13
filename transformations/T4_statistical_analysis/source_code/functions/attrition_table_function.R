#' Build the study-population attrition table from D3_ELIGIBILITY
#'
#' @param d3_eligibility data.frame or data.table -- D3_ELIGIBILITY
#'   Required columns are the SV_* flags + `eligible_exposed` / `eligible_control` / `in_eligible_pop`
#' @param criteria optional list overriding the default criteria order.
#'
#' @return A data.table with columns step, label, n, pct.

build_attrition_table <- function(
  d3_eligibility,
  criteria = NULL
) {
  dt <- data.table::as.data.table(d3_eligibility)

  if (is.null(criteria)) {
    criteria <- list(
      list(
        label = "All individuals diagnosed with NSCLC between 1-1-2022 and 31-12-2024 and registered in the NCR",
        predicate = quote(SV_NSCLC_DIAGNOSIS == TRUE)
      ),
      list(
        label = "AND started nivolumab + ipilimumab or pembrolizumab",
        predicate = quote(
          SV_NIVOLUMAB_AND_IPILIMUMAB == TRUE | SV_PEMBROLIZUMAB == TRUE
        )
      ),
      list(
        label = "AND started index or reference drugs within 90 days from NSCLC diagnosis",
        predicate = quote(SV_FIRST_NSCLC_DIAGNOSIS == TRUE)
      ),
      list(
        label = "AND are aged ≥ 18 at index",
        predicate = quote(SV_AGE_18_OR_OLDER == TRUE)
      ),
      list(
        label = "AND have a stage IV cancer",
        predicate = quote(SV_CSTAGE4 == TRUE)
      ),
      list(
        label = "AND have a PDL1 expression of < 1%",
        predicate = quote(SV_PDL_BELOW_1 == TRUE)
      ),
      list(
        label = "AND have NO actionable EGFR, ALK or ROS1 mutation",
        predicate = quote(SV_MUTATION_ALK_ROS1_EGFR == FALSE)
      ),
      list(
        label = "AND have NO previous malignancy/ cancer treatment",
        predicate = quote(SV_PREVIOUS_CANCER_DIAGNOSIS == FALSE)
      ),
      list(
        label = "AND have ECOG PS ≤ 1",
        predicate = quote(ECOG_LE_1 == TRUE)
      ),
      list(
        label = "AND started chemotherapy between -28 and 0 days",
        predicate = quote(SV_RECEIVED_CT == TRUE)
      )
    )
  }

  # Iteratively filter spells: count unique persons remaining at each step.
  remaining <- dt
  rows <- vector("list", length(criteria))
  for (i in seq_along(criteria)) {
    remaining <- remaining[eval(criteria[[i]]$predicate)]
    rows[[i]] <- data.table::data.table(
      step = i,
      label = criteria[[i]]$label,
      n = data.table::uniqueN(remaining$person_id)
    )
  }
  out <- data.table::rbindlist(rows)

  # Since we are looking for the first line treatment regardless of switch, selecting here the first eligible spell to obtain T0 and group.
  # this is for edge case where individuals received both nivolumab + ipilimumab and pembrolizuma
  eligible_spells <- dt[eligible_exposed == TRUE | eligible_control == TRUE]
  order_col <- intersect(c("start_episode", "start"), names(eligible_spells))
  if (length(order_col) > 0L) {
    data.table::setorderv(eligible_spells, c("person_id", order_col[1]))
  }
  first_spell <- eligible_spells[, .SD[1L], by = person_id]
  first_spell[,
    arm := data.table::fifelse(eligible_exposed == TRUE, "EXPOSED", "CONTROL")
  ]

  n_total_eligible <- nrow(first_spell)
  n_exposed <- first_spell[arm == "EXPOSED", .N]
  n_control <- first_spell[arm == "CONTROL", .N]

  arm_rows <- data.table::data.table(
    step = c(max(out$step) + 1L, max(out$step) + 2L, max(out$step) + 3L),
    label = c(
      "Total Eligible Cohort",
      "Eligible nivolumab + ipilimumab + chemotherapy",
      "Eligible pembrolizumab + chemotherapy"
    ),
    n = c(n_total_eligible, n_exposed, n_control)
  )

  n_criteria <- length(criteria)
  out <- data.table::rbindlist(list(out, arm_rows))

  # Criteria rows: % of base (step 1). Total + arm rows: % of total eligible.
  base_n <- out[step == 1L, n]
  eligible_n <- out[step == n_criteria, n]
  out[step <= n_criteria, pct := round(100 * n / base_n, 1)]
  out[step > n_criteria, pct := round(100 * n / eligible_n, 1)]
  out[]
}
