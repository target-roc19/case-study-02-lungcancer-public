#' Supplemental survival figures
#'
#' Kaplan-Meier curves (crude + IPTW), Schoenfeld residuals and a log(-log)
#' survival plot, built from D4_StudyCohort_Analysis with survival +
#' ggplot2 only. EXPOSED = nivolumab + ipilimumab, CONTROL = pembrolizumab.

# From config_values in the pipeline; fall back so the functions stay testable.
DAYS_PER_MONTH <- if (exists("config_values")) {
  config_values$month_length
} else {
  30.44
}

.group_factor <- function(dt) {
  data.table::copy(dt)[,
    group := relevel(factor(group), ref = "CONTROL")
  ]
}

# survfit strata -> long data.table with a (0, 1) per group
.tidy_survfit <- function(fit) {
  strata <- rep(names(fit$strata), fit$strata)
  dt <- data.table::data.table(
    time = fit$time,
    surv = fit$surv,
    group = sub("^group=", "", strata)
  )
  anchor <- dt[, .(time = 0, surv = 1), by = group]
  data.table::rbindlist(list(anchor, dt), use.names = TRUE)[order(group, time)]
}

.km_labels <- function(dt) {
  dt[,
    group_label := factor(
      group,
      levels = c("CONTROL", "EXPOSED"),
      labels = c("Pembrolizumab", "Nivolumab + ipilimumab")
    )
  ]
  dt[, time_months := time / DAYS_PER_MONTH]
  dt
}

#' Kaplan-Meier survival curves by group. weighted = TRUE to fit IPTW KM on
#' the trimmed cohort.
plot_km <- function(lookup, weighted = FALSE) {
  dt <- data.table::as.data.table(lookup)
  if (weighted) {
    dt <- dt[include_after_trimming == TRUE]
    fit <- survival::survfit(
      survival::Surv(fup_days, event_death) ~ group,
      data = .group_factor(dt),
      weights = ip_weight
    )
  } else {
    fit <- survival::survfit(
      survival::Surv(fup_days, event_death) ~ group,
      data = .group_factor(dt)
    )
  }

  km <- .km_labels(.tidy_survfit(fit))
  subtitle <- if (weighted) "IPTW-weighted" else "Crude"

  ggplot2::ggplot(
    km,
    ggplot2::aes(x = time_months, y = surv, color = group_label)
  ) +
    ggplot2::geom_step(linewidth = 0.8) +
    ggplot2::scale_color_manual(values = c("darkblue", "darkred")) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.title = ggplot2::element_blank(),
      legend.position = "bottom"
    ) +
    ggplot2::labs(
      x = "Follow-up time (months)",
      y = "Survival probability",
      subtitle = subtitle
    )
}

#' Scaled Schoenfeld residuals from the IPTW-adjusted Cox model
plot_schoenfeld <- function(lookup) {
  dt <- .group_factor(data.table::as.data.table(lookup)[
    include_after_trimming == TRUE
  ])
  fit <- survival::coxph(
    survival::Surv(fup_days, event_death) ~ group,
    data = dt,
    weights = ip_weight,
    cluster = person_id,
    robust = TRUE
  )
  zph <- survival::cox.zph(fit)

  resid <- data.table::data.table(
    time_months = zph$time / DAYS_PER_MONTH,
    residual = as.numeric(zph$y[, 1])
  )

  ggplot2::ggplot(resid, ggplot2::aes(x = time_months, y = residual)) +
    ggplot2::geom_hline(
      yintercept = 0,
      linetype = "dashed",
      color = "grey40"
    ) +
    ggplot2::geom_point(size = 2, alpha = 0.6) +
    ggplot2::geom_smooth(
      method = "loess",
      formula = y ~ x,
      se = TRUE,
      color = "darkblue"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      x = "Follow-up time (months)",
      y = "Scaled Schoenfeld residual (group)"
    )
}

#' log(-log(S(t))) vs log(t) by group
plot_loglog <- function(lookup) {
  dt <- data.table::as.data.table(lookup)
  fit <- survival::survfit(
    survival::Surv(fup_days, event_death) ~ group,
    data = .group_factor(dt)
  )
  ll <- .tidy_survfit(fit)
  ll <- ll[time > 0 & surv > 0 & surv < 1]
  ll[, `:=`(
    log_time = log(time),
    cloglog = log(-log(surv))
  )]
  ll[,
    group_label := factor(
      group,
      levels = c("CONTROL", "EXPOSED"),
      labels = c("Pembrolizumab", "Nivolumab + ipilimumab")
    )
  ]

  ggplot2::ggplot(
    ll,
    ggplot2::aes(x = log_time, y = cloglog, color = group_label)
  ) +
    ggplot2::geom_step(linewidth = 0.8) +
    ggplot2::scale_color_manual(values = c("darkblue", "darkred")) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.title = ggplot2::element_blank(),
      legend.position = "bottom"
    ) +
    ggplot2::labs(
      x = "log(follow-up time in days)",
      y = "log(-log(survival probability))"
    )
}
