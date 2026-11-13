#' Baseline characteristics table for TARGET CS02
#'
#' Restricts cohort to `include_after_trimming == TRUE`, calls
#' `DescriptiveTable::DescriptivesTable()` for the unweighted layout
#' (Overall + EXPOSED + CONTROL N/perc/aux, NUM2 median/IQR,
#' expectedCat handling), computes the matching IPTW-weighted N/perc/aux
#' row-by-row (DescriptiveTable's count_* ignore weights), and attaches
#' unweighted + IPTW-weighted aSMD columns from
#' `DescriptiveTable::compute_asd()`.
#'
#' Output columns:
#'   label, var, type,
#'   N/perc/aux unwt × {overall, exposed, control},
#'   N/perc/aux wt   × {overall, exposed, control},
#'   asd_unwt, asd_wt.
#'
#' @param d4_covariates D4_StudyCohort_Covariates.
#' @param d4_iptw D4_StudyCohort_IPTW.
#' @param metadata DescriptiveTable-style metadata; columns
#'   `var; type; expectedCat; label; parent; parent_cat; header`.

GROUPS <- c("OVERALL", "EXPOSED", "CONTROL")

# Display names for the three levels of the collapsed CNS metastasis /
# radiotherapy covariate
CNS_MET_RT_LABELS <- c(
  NO_CNS_MET = "No CNS metastases",
  CNS_NO_RT = "CNS metastases, no radiotherapy",
  CNS_WITH_RT = "CNS metastases, with radiotherapy"
)

# Replaces the raw level codes with those names
.name_cns_levels <- function(out) {
  out[
    var == "SV_CNS_MET_RT" & cat %in% names(CNS_MET_RT_LABELS),
    label := unname(CNS_MET_RT_LABELS[cat])
  ]
}

# Weighted N/perc/aux for a single output row
weighted_row_stats <- function(x, w, type, label, lvl, tw) {
  if (all(is.na(x))) {
    return(rep(NA_real_, 3))
  }
  key <- if (type %in% c("TF", "CAT")) type else label
  switch(
    key,
    TF = {
      n <- sum(w[!is.na(x) & x == TRUE], na.rm = TRUE)
      c(n, 100 * n / tw, NA_real_)
    },
    CAT = {
      n <- sum(w[!is.na(x) & x == lvl], na.rm = TRUE)
      c(n, 100 * n / tw, NA_real_)
    },
    "Median (Q1, Q3)" = {
      q <- Hmisc::wtd.quantile(x, w, c(0.25, 0.5, 0.75), na.rm = TRUE)
      c(q[2], q[1], q[3])
    },
    "Min, Max" = c(
      suppressWarnings(min(x, na.rm = TRUE)),
      suppressWarnings(max(x, na.rm = TRUE)),
      NA_real_
    ),
    "Mean (SD)" = {
      mu <- stats::weighted.mean(x, w, na.rm = TRUE)
      sdw <- sqrt(sum(w * (x - mu)^2, na.rm = TRUE) / sum(w, na.rm = TRUE))
      c(mu, sdw, NA_real_)
    },
    rep(NA_real_, 3)
  )
}

# Round weighted counts to whole numbers so that they still sum to the rounded total
apportion <- function(x) {
  if (anyNA(x)) {
    return(x)
  }
  n <- floor(x)
  short <- round(sum(x)) - sum(n)
  if (short > 0) {
    largest <- order(x - n, decreasing = TRUE)[seq_len(short)]
    n[largest] <- n[largest] + 1
  }
  n
}

# Standardized difference for a binary variable, calculated using non-missing
# values only. For categorical variables separate aSMD calculated for each
# level
#  w = 1 gives the unweighted aSMD; IPT weights give the weighted aSMD.
# denominator is the pooled SD of the two proportions, i.e.
# the square root of the average of the two group variances:
#   |p_exp - p_con| / sqrt((p_exp(1 - p_exp) + p_con(1 - p_con)) / 2)
level_asd <- function(ind, present, group, w) {
  prop <- function(g) {
    keep <- present & group == g
    denom <- sum(w[keep])
    if (denom == 0) NA_real_ else sum(w[keep & ind]) / denom
  }
  pe <- prop("EXPOSED")
  pc <- prop("CONTROL")
  if (is.na(pe) || is.na(pc)) {
    return(NA_real_)
  }
  sd_avg <- sqrt((pe * (1 - pe) + pc * (1 - pc)) / 2)
  if (sd_avg == 0) 0 else abs(pe - pc) / sd_avg
}

#' Unweighted and IPT-weighted aSMD for every metadata variable
#'
#' Continuous variables keep the mean-difference / pooled-SD aSMD from
#' `DescriptiveTable::compute_asd`; categorical and binary variables get one
#' standardized difference per level via `level_asd`. Shared by the baseline
#' table and the Love plot so the two cannot report different aSMDs.
#'
#' @param cohort EXPOSED/CONTROL rows carrying `group`, the metadata variables
#'   and the weight column.
#' @param metadata columns `var; type; expectedCat; label`. CAT levels are taken
#'   from `expectedCat` (declared order), falling back to the observed values.
#' @param weight name of the IPT weight column in `cohort`.
#'
#' @return data.table `var, type, label, cat, asd_unwt, asd_wt` with one row per
#'   continuous variable (`cat = NA`) and one row per level of each CAT/TF
#'   variable, in metadata order.
build_asd_table <- function(cohort, metadata, weight = "w") {
  cohort <- data.table::as.data.table(cohort)
  metadata <- data.table::as.data.table(metadata)[var %in% names(cohort)]

  # One row per level for CAT/TF ("TRUE" is the level DescriptivesTable reports
  # a TF variable under), one row per continuous variable.
  out <- metadata[,
    .(
      cat = switch(
        type,
        TF = "TRUE",
        CAT = {
          declared <- trimws(unlist(strsplit(as.character(expectedCat), ",")))
          if (anyNA(declared)) {
            sort(unique(as.character(cohort[[var]])))
          } else {
            declared
          }
        },
        NA_character_
      )
    ),
    by = .(var, type, label)
  ]
  out[, `:=`(asd_unwt = NA_real_, asd_wt = NA_real_)]

  num_meta <- metadata[type %in% c("NUM1", "NUM2")]
  if (nrow(num_meta) > 0) {
    asd_num <- function(use_weights) {
      round(
        as.numeric(
          DescriptiveTable::compute_asd(
            CovariatesInformation = cohort,
            metadata = num_meta[, .(var, type)],
            group_names = c("EXPOSED", "CONTROL"),
            referenceExtension = "x",
            use_weights = use_weights
          )$asd_x
        ),
        3
      )
    }
    out[
      match(num_meta$var, out$var),
      `:=`(asd_unwt = asd_num(FALSE), asd_wt = asd_num(weight))
    ]
  }

  w <- as.numeric(cohort[[weight]])
  unit_w <- rep(1, nrow(cohort))
  for (r in which(out$type %in% c("CAT", "TF"))) {
    x <- cohort[[out$var[r]]]
    present <- !is.na(x) & trimws(as.character(x)) != ""
    ind <- present &
      (if (out$type[r] == "TF") {
        as.logical(x)
      } else {
        as.character(x) == out$cat[r]
      })
    out[
      r,
      `:=`(
        asd_unwt = round(level_asd(ind, present, cohort$group, unit_w), 3),
        asd_wt = round(level_asd(ind, present, cohort$group, w), 3)
      )
    ]
  }
  out[]
}

build_baseline_table <- function(
  d4_covariates,
  d4_iptw,
  metadata,
  mask = FALSE
) {
  metadata <- data.table::as.data.table(metadata)
  cov_dt <- data.table::as.data.table(d4_covariates)
  iptw <- data.table::as.data.table(d4_iptw)
  cov_dt[, `:=`(person_id = as.character(person_id), T0 = as.Date(T0))]
  iptw[, `:=`(person_id = as.character(person_id), T0 = as.Date(T0))]

  # cohort and iptw
  cohort <- merge(
    cov_dt,
    iptw[
      include_after_trimming == TRUE,
      .(person_id, T0, w = as.numeric(stabilized_trunc_iptw))
    ],
    by = c("person_id", "T0")
  )
  cohort <- cohort[,
    intersect(c("group", "w", metadata$var), names(cohort)),
    with = FALSE
  ]

  # Normalize weights within arm so the weighted N sums to the arm headcount
  cohort[, w := w * (.N / sum(w)), by = "group"]

  # Coerce each metadata column to the type that DescriptivesTable expects
  for (i in seq_len(nrow(metadata))) {
    v <- metadata$var[i]
    if (!v %in% names(cohort)) {
      next
    }
    coerce <- switch(
      metadata$type[i],
      TF = as.logical,
      CAT = as.character,
      NUM1 = ,
      NUM2 = function(x) suppressWarnings(as.numeric(x)),
      identity
    )
    data.table::set(cohort, j = v, value = coerce(cohort[[v]]))
  }

  # Create group = "OVERALL" so DescriptivesTable creates
  # V*_OVERALL
  pop <- data.table::rbindlist(list(
    cohort,
    data.table::copy(cohort)[, group := "OVERALL"]
  ))
  out <- data.table::as.data.table(DescriptiveTable::DescriptivesTable(
    popdf = pop,
    table_metadata = metadata,
    groupcol = "group",
    output_format = "processed",
    calculate_asd = FALSE,
    keep_varinfo = TRUE,
    control_types = FALSE,
    round_decimals = 3,
    output_asd = FALSE
  ))

  # Weighted N/perc/aux per row
  pop_by_g <- list(
    OVERALL = cohort,
    EXPOSED = cohort[group == "EXPOSED"],
    CONTROL = cohort[group == "CONTROL"]
  )
  total_w <- sapply(pop_by_g, function(p) sum(p$w, na.rm = TRUE))
  for (g in GROUPS) {
    out[, paste0("W", 1:3, "_", g) := NA_real_]
  }

  for (r in seq_len(nrow(out))) {
    v <- out$var[r]
    if (is.na(v)) {
      next
    } # header row
    if (v == "Total") {
      for (g in GROUPS) {
        out[r, (paste0("W1_", g)) := round(total_w[[g]])]
      }
      next
    }
    if (!v %in% names(cohort)) {
      next
    }
    for (g in GROUPS) {
      p <- pop_by_g[[g]]
      s <- weighted_row_stats(
        p[[v]],
        p$w,
        out$type[r],
        out$label[r],
        out$cat[r],
        total_w[[g]]
      )
      # TF/CAT counts stay fractional until the rounding pass below
      s <- if (out$type[r] %in% c("TF", "CAT")) {
        c(s[1], round(s[2], 3), s[3])
      } else {
        round(s, 3)
      }
      out[r, (paste0("W", 1:3, "_", g)) := as.list(s)]
    }
  }

  # The reported weighted counts need to add up in both directions. So rounded
  # within an arm by largest remainder (to sum to the arm total), and take
  # OVERALL as the sum of the two arms
  count_rows <- out$type %in% c("TF", "CAT")
  for (g in c("EXPOSED", "CONTROL")) {
    out[
      count_rows,
      (paste0("W1_", g)) := apportion(get(paste0("W1_", g))),
      by = var
    ]
  }
  out[count_rows, W1_OVERALL := W1_EXPOSED + W1_CONTROL]

  # Weighted percentages as counts that are actually printed, can be recumpoted
  for (g in GROUPS) {
    out[
      count_rows,
      (paste0("W2_", g)) := round(
        100 * get(paste0("W1_", g)) / round(total_w[[g]]),
        1
      )
    ]
  }

  # aSMDs. Categorical/binary variables report one standardized difference per
  # level, placed on the level row; continuous variables keep the
  # mean-difference / pooled-SD aSMD on the variable's header row.
  asd <- build_asd_table(cohort, metadata)
  out[, `:=`(asd_unwt = NA_real_, asd_wt = NA_real_)]

  num_asd <- asd[type %in% c("NUM1", "NUM2")]
  out[
    match(num_asd$label, out$label),
    `:=`(asd_unwt = num_asd$asd_unwt, asd_wt = num_asd$asd_wt)
  ]
  out[
    asd[type %in% c("CAT", "TF")],
    on = c("var", "cat"),
    `:=`(asd_unwt = i.asd_unwt, asd_wt = i.asd_wt)
  ]

  # mask the unweighted EXPOSED/CONTROL cell counts
  # + percentages
  if (isTRUE(mask)) {
    out <- data.table::as.data.table(DescriptiveTable::mask_vector_wrapper(
      out,
      threshold = 5,
      count.names = c("V1_CONTROL", "V1_EXPOSED"),
      pct.names = c("V2_CONTROL", "V2_EXPOSED"),
      table_metadata = metadata
    ))

    out <- data.table::as.data.table(DescriptiveTable::mask_vector_wrapper(
      out,
      threshold = 5,
      count.names = c("W1_CONTROL", "W1_EXPOSED"),
      pct.names = c("W2_CONTROL", "W2_EXPOSED"),
      table_metadata = metadata
    ))
  }

  .name_cns_levels(out)

  # Drop DescriptiveTable varinfo
  out[, c("id", "cat", "parentv", "parent_catv", "m_id") := NULL]
  for (g in GROUPS) {
    data.table::setnames(
      out,
      c(paste0("V", 1:3, "_", g), paste0("W", 1:3, "_", g)),
      c(
        paste0(c("N", "perc", "aux"), "_unwt_", tolower(g)),
        paste0(c("N", "perc", "aux"), "_wt_", tolower(g))
      )
    )
  }
  data.table::setcolorder(
    out,
    c(
      "label",
      "var",
      "type",
      "N_unwt_overall",
      "perc_unwt_overall",
      "aux_unwt_overall",
      "N_unwt_exposed",
      "perc_unwt_exposed",
      "aux_unwt_exposed",
      "N_unwt_control",
      "perc_unwt_control",
      "aux_unwt_control",
      "N_wt_overall",
      "perc_wt_overall",
      "aux_wt_overall",
      "N_wt_exposed",
      "perc_wt_exposed",
      "aux_wt_exposed",
      "N_wt_control",
      "perc_wt_control",
      "aux_wt_control",
      "asd_unwt",
      "asd_wt"
    )
  )
  out[]
}

#' Unweighted Overall/EXPOSED/CONTROL N/perc/aux + aSMD for one cohort
#'
#' Shared unweighted layout used by the trimming comparison. `suffix` is
#' appended to every statistic column so two blocks can sit side by side.
#' aSMDs come from `build_asd_table()`, so they are per level for categorical
#' variables, as in the baseline table.
.descriptives_block <- function(cohort, metadata, suffix) {
  for (i in seq_len(nrow(metadata))) {
    v <- metadata$var[i]
    if (!v %in% names(cohort)) {
      next
    }
    coerce <- switch(
      metadata$type[i],
      TF = as.logical,
      CAT = as.character,
      NUM1 = ,
      NUM2 = function(x) suppressWarnings(as.numeric(x)),
      identity
    )
    data.table::set(cohort, j = v, value = coerce(cohort[[v]]))
  }
  pop <- data.table::rbindlist(list(
    cohort,
    data.table::copy(cohort)[, group := "OVERALL"]
  ))
  out <- data.table::as.data.table(DescriptiveTable::DescriptivesTable(
    popdf = pop,
    table_metadata = metadata,
    groupcol = "group",
    output_format = "processed",
    calculate_asd = FALSE,
    keep_varinfo = TRUE,
    control_types = FALSE,
    round_decimals = 3,
    output_asd = FALSE
  ))
  # Same aSMD as the baseline table, unweighted (w = 1 for everyone)
  cohort[, w := 1]
  asd_tbl <- build_asd_table(cohort, metadata)
  out[, asd := NA_real_]
  num_asd <- asd_tbl[type %in% c("NUM1", "NUM2")]
  out[match(num_asd$label, out$label), asd := num_asd$asd_unwt]
  out[
    asd_tbl[type %in% c("CAT", "TF")],
    on = c("var", "cat"),
    asd := i.asd_unwt
  ]
  .name_cns_levels(out)
  out[, c("id", "cat", "parentv", "parent_catv", "m_id") := NULL]
  for (g in GROUPS) {
    data.table::setnames(
      out,
      paste0("V", 1:3, "_", g),
      paste0(c("N", "perc", "aux"), "_", tolower(g))
    )
  }
  stat_cols <- setdiff(names(out), c("label", "var", "type"))
  data.table::setnames(out, stat_cols, paste0(stat_cols, "_", suffix))
  out
}

#' Baseline characteristics before vs after PS trimming, with aSMDs (#71 Table 3)
#'
#' Same unweighted layout as `build_baseline_table`, computed on the pre-trim
#' cohort (everyone with a propensity score) and the post-trim cohort
#' (`include_after_trimming == TRUE`) and placed side by side.
#'
#' @param d4_covariates D4_StudyCohort_Covariates.
#' @param d4_iptw D4_StudyCohort_IPTW.
#' @param metadata DescriptiveTable-style metadata (as for `build_baseline_table`).
build_baseline_trimming_table <- function(d4_covariates, d4_iptw, metadata) {
  metadata <- data.table::as.data.table(metadata)
  cov_dt <- data.table::as.data.table(d4_covariates)
  iptw <- data.table::as.data.table(d4_iptw)
  cov_dt[, `:=`(person_id = as.character(person_id), T0 = as.Date(T0))]
  iptw[, `:=`(person_id = as.character(person_id), T0 = as.Date(T0))]

  cohort_for <- function(keep) {
    cohort <- merge(cov_dt, keep, by = c("person_id", "T0"))
    cohort[, intersect(c("group", metadata$var), names(cohort)), with = FALSE]
  }
  before <- .descriptives_block(
    cohort_for(iptw[!is.na(p_score), .(person_id, T0)]),
    metadata,
    "before"
  )
  after <- .descriptives_block(
    cohort_for(iptw[include_after_trimming == TRUE, .(person_id, T0)]),
    metadata,
    "after"
  )
  after[, c("label", "var", "type") := NULL]
  out <- cbind(before, after)
  col_order <- c("label", "var", "type")
  for (suffix in c("before", "after")) {
    for (g in c("overall", "exposed", "control")) {
      col_order <- c(
        col_order,
        paste0(c("N", "perc", "aux"), "_", g, "_", suffix)
      )
    }
    col_order <- c(col_order, paste0("asd_", suffix))
  }
  data.table::setcolorder(out, col_order)
  out[]
}
