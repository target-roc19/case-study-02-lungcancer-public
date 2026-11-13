#' Outcome descriptive results for Estimand 1 (HR) and Estimand 2 (RMST)
#'
#' D4_StudyCohort_Analysis as input and producing:
#'   * crude + IPTW-adjusted hazard-ratio table (events, person-years and
#'     person-months, incidence rate per 1000 py and per 1000 pm, Cox HR),
#'   * crude + adjusted RMST table from a Weibull AFT model at 1/2/3 years,
#'   * subgroup-adjusted HRs for the forest plot.
#'
#' EXPOSED = nivolumab + ipilimumab, CONTROL = pembrolizumab (reference).

GROUP_LABELS <- c(
  EXPOSED = "nivolumab + ipilimumab",
  CONTROL = "pembrolizumab"
)

# Time constants come from config_values when the pipeline has loaded it;
# fall back to the standard values so the functions stay unit-testable.
DAYS_PER_YEAR <- if (exists("config_values")) {
  config_values$year_length
} else {
  365.25
}
DAYS_PER_MONTH <- if (exists("config_values")) {
  config_values$month_length
} else {
  30.44
}
RMST_HORIZONS_YEARS <- c(1, 2, 3)

# Format "est (lb-ub)"
.fmt_ci <- function(est, lb, ub, digits = 2) {
  fmt <- paste0("%.", digits, "f")
  out <- sprintf(paste0(fmt, " (", fmt, "-", fmt, ")"), est, lb, ub)
  out[is.na(est) | is.na(lb) | is.na(ub)] <- NA_character_
  out
}

# CONTROL (pembrolizumab) is reference so the group coefficient
# reads as EXPOSED vs CONTROL
.prep <- function(dt, weighted) {
  dt <- data.table::copy(dt)
  dt[, group := relevel(factor(group), ref = "CONTROL")]
  dt[, .w := if (weighted) ip_weight else 1]
  dt
}

#' Cox HR for EXPOSED vs CONTROL. NA when unestimable.
cox_hr <- function(dt) {
  na_out <- c(est = NA_real_, lb = NA_real_, ub = NA_real_)
  if (data.table::uniqueN(dt$group) < 2L) {
    return(na_out)
  }
  if (any(dt[, sum(event_death), by = group]$V1 == 0)) {
    return(na_out)
  }

  fit <- tryCatch(
    survival::coxph(
      survival::Surv(fup_days, event_death) ~ group,
      data = dt,
      weights = .w,
      cluster = person_id,
      robust = TRUE
    ),
    error = function(e) NULL,
    warning = function(w) NULL
  )
  if (is.null(fit)) {
    return(na_out)
  }

  coefs <- summary(fit)$coefficients
  log_hr <- coefs[1, "coef"]
  se <- coefs[1, "robust se"]
  c(
    est = exp(log_hr),
    lb = exp(log_hr + stats::qnorm(0.025) * se),
    ub = exp(log_hr + stats::qnorm(0.975) * se)
  )
}

# Incidence rate per person-years
.incidence_rate <- function(dt, scale) {
  CohortAnalytics::est_inc_prev(
    n_pat = nrow(dt),
    n_out = sum(dt$.w * dt$event_death),
    py = sum(dt$.w * dt$pyr),
    scale_IR = scale,
    type = "incidence"
  )$ir_est
}

#' Per-group crude + adjusted incidence rate and Cox HR table.
build_outcome_hr_table <- function(lookup, ir_scale = 1000) {
  dt <- data.table::as.data.table(lookup)
  crude <- .prep(dt, weighted = FALSE)
  adj <- .prep(dt[include_after_trimming == TRUE], weighted = TRUE)

  hr_crude <- cox_hr(crude)
  hr_adj <- cox_hr(adj)

  rows <- lapply(c("EXPOSED", "CONTROL"), function(g) {
    is_ref <- g == "CONTROL"
    pyr_crude <- crude[group == g, sum(pyr)]
    pyr_adj <- adj[group == g, sum(pyr)]
    ir_crude <- .incidence_rate(crude[group == g], ir_scale)
    ir_adj <- .incidence_rate(adj[group == g], ir_scale)
    data.table::data.table(
      outcome = "Death",
      treatment_group = GROUP_LABELS[[g]],
      n_crude = crude[group == g, .N],
      n_events_crude = crude[group == g, sum(event_death)],
      person_years_crude = round(pyr_crude, 1),
      person_months_crude = round(pyr_crude * 12, 1),
      crude_ir_per_1000py = round(ir_crude, 1),
      crude_ir_per_1000pm = round(ir_crude / 12, 1),
      crude_hr = if (is_ref) {
        "ref"
      } else {
        .fmt_ci(hr_crude[1], hr_crude[2], hr_crude[3])
      },
      n_adj = adj[group == g, .N],
      n_events_adj = adj[group == g, sum(event_death)],
      person_years_adj = round(pyr_adj, 1),
      person_months_adj = round(pyr_adj * 12, 1),
      adj_ir_per_1000py = round(ir_adj, 1),
      adj_ir_per_1000pm = round(ir_adj / 12, 1),
      adj_hr = if (is_ref) "ref" else .fmt_ci(hr_adj[1], hr_adj[2], hr_adj[3])
    )
  })
  data.table::rbindlist(rows)
}

# ---------------------------------------------------------------
# Estimand 2: Weibull AFT RMST at fixed horizons
#
# Per the SAP: fit a Weibull AFT model and report the RMST at 1/2/3 years plus the EXPOSED - CONTROL difference
# ---------------------------------------------------------------

.fit_weibull_aft <- function(dt) {
  tryCatch(
    flexsurv::flexsurvreg(
      survival::Surv(fup_days, event_death) ~ group,
      data = dt,
      dist = "weibull",
      weights = .w
    ),
    error = function(e) NULL
  )
}

#' Fit the crude and IPTW-weighted Weibull AFT models used for Estimand 2
fit_weibull_models <- function(lookup) {
  dt <- data.table::as.data.table(lookup)
  list(
    crude = .fit_weibull_aft(.prep(dt, weighted = FALSE)),
    adj = .fit_weibull_aft(.prep(
      dt[include_after_trimming == TRUE],
      weighted = TRUE
    ))
  )
}

# RMST for CONTROL, EXPOSED and their difference, formatted in
# months
# Protocol does not specify method for computing CIs, using delta  method  here
.rmst_by_horizon <- function(fit, taus) {
  na_vec <- rep(NA_character_, length(taus))
  if (is.null(fit)) {
    return(list(CONTROL = na_vec, EXPOSED = na_vec, DIFF = na_vec))
  }
  ss <- data.table::as.data.table(suppressMessages(flexsurv::standsurv(
    fit,
    type = "rmst",
    t = taus,
    at = list(list(group = "CONTROL"), list(group = "EXPOSED")),
    contrast = "difference",
    ci = TRUE
  )))
  ss <- ss[match(taus, time)]
  fmt_months <- function(est, lb, ub) {
    .fmt_ci(est / DAYS_PER_MONTH, lb / DAYS_PER_MONTH, ub / DAYS_PER_MONTH)
  }
  list(
    CONTROL = fmt_months(ss$at1, ss$at1_lci, ss$at1_uci),
    EXPOSED = fmt_months(ss$at2, ss$at2_lci, ss$at2_uci),
    DIFF = fmt_months(ss$contrast2_1, ss$contrast2_1_lci, ss$contrast2_1_uci)
  )
}

#' RMST table from fitted Weibull AFT models at 1/2/3 years, crude + adjusted
#' (months).
build_rmst_table <- function(models, horizons_years = RMST_HORIZONS_YEARS) {
  taus <- horizons_years * DAYS_PER_YEAR

  rmst_crude <- .rmst_by_horizon(models$crude, taus)
  rmst_adj <- .rmst_by_horizon(models$adj, taus)

  rows <- lapply(seq_along(horizons_years), function(i) {
    yr <- horizons_years[i]
    label <- paste0(yr, if (yr == 1) " year" else " years")
    data.table::rbindlist(lapply(c("EXPOSED", "CONTROL"), function(g) {
      is_ref <- g == "CONTROL"
      data.table::data.table(
        outcome = "Death",
        time_horizon = label,
        treatment_group = GROUP_LABELS[[g]],
        rmst_months = rmst_crude[[g]][i],
        rmst_diff_months = if (is_ref) "ref" else rmst_crude$DIFF[i],
        adj_rmst_months = rmst_adj[[g]][i],
        adj_rmst_diff_months = if (is_ref) "ref" else rmst_adj$DIFF[i]
      )
    }))
  })
  data.table::rbindlist(rows)
}

# ---------------------------------------------------------------
# Subgroup-adjusted HRs for the forest plot
# ---------------------------------------------------------------

FOREST_SUBGROUPS <- list(
  list(var = "subgroup_squamous", levels = c("Non-squamous", "Squamous")),
  list(var = "subgroup_brain", levels = c(
    "No CNS metastases",
    "CNS metastases, no radiotherapy",
    "CNS metastases, with radiotherapy"
  ))
)

#' Adjusted HR overall and within each forest subgroup stratum.
build_forest_data <- function(lookup) {
  adj <- .prep(
    data.table::as.data.table(lookup)[include_after_trimming == TRUE],
    weighted = TRUE
  )

  stratum_row <- function(sdt, label) {
    hr <- cox_hr(sdt)
    data.table::data.table(
      subgroup = label,
      n = nrow(sdt),
      n_events = sum(sdt$event_death),
      hr = hr[["est"]],
      lb = hr[["lb"]],
      ub = hr[["ub"]]
    )
  }

  rows <- list(stratum_row(adj, "Overall"))
  for (sg in FOREST_SUBGROUPS) {
    vals <- as.character(adj[[sg$var]])
    for (lv in sg$levels) {
      rows <- c(rows, list(stratum_row(adj[which(vals == lv)], lv)))
    }
  }
  data.table::rbindlist(rows)
}

#' ggplot forest of the adjusted subgroup HRs.
plot_forest <- function(forest_data) {
  pd <- data.table::as.data.table(forest_data)
  pd[, subgroup := factor(subgroup, levels = rev(subgroup))]
  ggplot2::ggplot(pd[!is.na(hr)], ggplot2::aes(x = hr, y = subgroup)) +
    ggplot2::geom_vline(xintercept = 1, linetype = "dashed", color = "grey40") +
    ggplot2::geom_linerange(ggplot2::aes(xmin = lb, xmax = ub)) +
    ggplot2::geom_point(size = 2.5) +
    ggplot2::scale_x_log10() +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text = ggplot2::element_text(size = 10),
      axis.title = ggplot2::element_text(size = 10)
    ) +
    ggplot2::labs(
      x = "Adjusted hazard ratio (nivo+ipi vs pembro), log scale",
      y = NULL
    )
}

# DescriptiveTable::mask_vector. Person-time of a masked estimate becomes "NR" so the incidence rate + CI can still be reported

.is_masked <- function(x) grepl("[", x, fixed = TRUE)

.mask_counts <- function(x, total = NULL) {
  as.character(suppressWarnings(DescriptiveTable::mask_vector(
    as.numeric(x),
    threshold = 5,
    total = total
  )))
}

#' Mask the crude and adjusted count columns of the HR table; person-years and
#' person-months of a masked estimate become "NR".
mask_hr_table <- function(hr_table) {
  dt <- data.table::copy(data.table::as.data.table(hr_table))
  for (sfx in c("crude", "adj")) {
    n <- .mask_counts(dt[[paste0("n_", sfx)]])
    ev <- .mask_counts(dt[[paste0("n_events_", sfx)]])
    masked <- .is_masked(n) | .is_masked(ev)
    py <- as.character(dt[[paste0("person_years_", sfx)]])
    pm <- as.character(dt[[paste0("person_months_", sfx)]])
    py[masked] <- "NR"
    pm[masked] <- "NR"
    dt[,
      paste0(
        c("n_", "n_events_", "person_years_", "person_months_"),
        sfx
      ) := list(n, ev, py, pm)
    ]
  }
  dt[]
}
