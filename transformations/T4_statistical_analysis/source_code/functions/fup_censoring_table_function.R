#' Build the follow-up & censoring table from D4_StudyCohort_FUP
#'
#' Returns one row per metric/reason with formatted strings for the Overall,
#' EXPOSED (nivolumab + ipilimumab) and CONTROL (pembrolizumab) columns.
#'
#' Person-months are computed as `fup_length_pyr * 12`. Censoring rows cover
#' all four `reason_censoring` levels listed in the D4_StudyCohort_FUP codebook;
#' each reason reports n (%) and the median (Q1, Q3) and min, max time in months
#' to that event
#'
#' @param d4_fup data.frame or data.table -- D4_StudyCohort_FUP object.
#'   Required columns: `person_id`, `group`, `fup_length_pyr`, `reason_censoring`.
#'
#' @return A data.table with columns `label`, `overall`, `exposed`, `control`.
build_fup_censoring_table <- function(d4_fup) {
  dt <- data.table::as.data.table(d4_fup)

  reasons <- c(
    "Death",
    "End of max follow-up",
    "End of data collection",
    "End of study period"
  )

  months_overall <- dt$fup_length_pyr * 12
  months_exposed <- dt[group == "EXPOSED", fup_length_pyr * 12]
  months_control <- dt[group == "CONTROL", fup_length_pyr * 12]

  fmt_total <- function(x) sprintf("%.1f", sum(x))
  fmt_median <- function(x) {
    if (length(x) == 0) {
      return(NA_character_)
    }
    q <- stats::quantile(x, c(0.25, 0.5, 0.75), na.rm = TRUE)
    sprintf("%.1f (%.1f, %.1f)", q[2], q[1], q[3])
  }
  fmt_range <- function(x) {
    if (length(x) == 0) {
      return(NA_character_)
    }
    sprintf("%.1f, %.1f", min(x), max(x))
  }
  fmt_n_pct <- function(idx, n_total) {
    n <- sum(idx)
    pct <- if (n_total > 0) 100 * n / n_total else 0
    sprintf("%d (%.1f%%)", n, pct)
  }

  n_overall <- nrow(dt)
  n_exposed <- nrow(dt[group == "EXPOSED"])
  n_control <- nrow(dt[group == "CONTROL"])

  fup_rows <- data.table::data.table(
    label = c(
      "Person-months of follow-up",
      "Median (Q1, Q3)",
      "Min, Max"
    ),
    overall = c(
      fmt_total(months_overall),
      fmt_median(months_overall),
      fmt_range(months_overall)
    ),
    exposed = c(
      fmt_total(months_exposed),
      fmt_median(months_exposed),
      fmt_range(months_exposed)
    ),
    control = c(
      fmt_total(months_control),
      fmt_median(months_control),
      fmt_range(months_control)
    )
  )

  censoring_header <- data.table::data.table(
    label = "Censoring, n (%)",
    overall = NA_character_,
    exposed = NA_character_,
    control = NA_character_
  )

  # n (%) plus the time to the event that ended follow-up, among the subjects
  # who experienced that event.
  reason_block <- function(r) {
    is_r <- dt$reason_censoring == r
    stats_for <- function(idx, n_total) {
      c(
        fmt_n_pct(idx, n_total),
        fmt_median(months_overall[idx]),
        fmt_range(months_overall[idx])
      )
    }
    data.table::data.table(
      label = c(r, "Median time to event (Q1, Q3)", "Min, Max"),
      overall = stats_for(is_r, n_overall),
      exposed = stats_for(is_r & dt$group == "EXPOSED", n_exposed),
      control = stats_for(is_r & dt$group == "CONTROL", n_control)
    )
  }

  censoring_rows <- data.table::rbindlist(lapply(reasons, reason_block))

  data.table::rbindlist(list(fup_rows, censoring_header, censoring_rows))[]
}
