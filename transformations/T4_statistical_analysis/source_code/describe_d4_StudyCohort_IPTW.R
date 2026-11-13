# ---------------------------------------------------------------
# Step: describe_d4_StudyCohort_IPTW
#
# Input:  D4_StudyCohort_IPTW
#         D4_StudyCohort_Covariates
#         <DEAP>_D5_PS_Coef.csv
#         psmodel_variables.csv
#         BaselineCharacteristics_metadata.csv
#
# Output: <DEAP>_D5_PS_density_plot.png
#         <DEAP>_D5_PS_distribution.csv
#         <DEAP>_D5_IPTW_distribution.csv
#         <DEAP>_D5_PS_model_parameters.csv
#         <DEAP>_D5_baseline_trimming_table.csv
#         <DEAP>_D5_weighting_asd.csv
#         <DEAP>_D5_weighting_asd_plot.png
#         <DEAP>_D5_IPTW_density_plot.png
#
# Diagnostics for propensity scores and IPT weights.
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("describe_d4_StudyCohort_IPTW.R")
  lm$start_capturing_prints()
}

library(ggplot2)

logger::log_info("[describe_d4_StudyCohort_IPTW] - START")

# --- Config loading ---
picard::load_config()

deap_name <- config_project$DEAP_configuration$name
cfg <- config_project$describe_d4_StudyCohort_IPTW

# --- Source functions ---
functions_dir <- file.path(
  config_t4$T4$root,
  config_t4$T4$source_code,
  "functions"
)

source(file.path(functions_dir, "CohortPropensity", "describe_iptw.R"))
source(file.path(functions_dir, "baseline_table_function.R"))

# --- Read inputs ---
logger::log_info("Reading inputs for PS diagnostics")

covariates_path <- if (isTRUE(cfg$use_synthetic_data)) {
  cfg$synthetic_data
} else {
  cfg$d4_covariates
}

d4_iptw <- picard::load(cfg$d4_iptw)
d4_covariates <- picard::load(covariates_path)

# The two producers can emit person_id with different types (e.g. anchoR writes
# character, the IPTW step integer); align before any join.
data.table::setDT(d4_iptw)
data.table::setDT(d4_covariates)
d4_iptw[, person_id := as.character(person_id)]
d4_covariates[, person_id := as.character(person_id)]

d5_ps_coef <- picard::load(
  file.path(cfg$d5_dir, paste0(deap_name, "_D5_PS_Coef.csv"))
)
ps_variables <- picard::load(cfg$ps_variables, sep = ";")
baseline_metadata <- picard::load(cfg$baseline_metadata, sep = ";")

ps_trim_bounds <- cfg$ps_trim_bounds

# ================================================================
# 1. Plot densities of propensity score in control vs exposed group
# before and after trimming, with trim bounds drawn on the before panel.
# ================================================================
logger::log_info("Creating PS density plot")

# IF trimming configured the before/after panels are identical, only create the "after" panel + trim bounds when trimming is actually applied.
trimming_applied <- !is.null(ps_trim_bounds)

stage_levels <- c("Before trimming", "After trimming")
plot_data <- if (trimming_applied) {
  data.table::rbindlist(list(
    data.table::copy(d4_iptw)[, stage := stage_levels[1]],
    data.table::copy(d4_iptw)[
      include_after_trimming == TRUE
    ][, stage := stage_levels[2]]
  ))
} else {
  data.table::copy(d4_iptw)[, stage := stage_levels[1]]
}
plot_data[,
  group_label := factor(
    group,
    levels = c("CONTROL", "EXPOSED"),
    labels = c("Control", "Exposed")
  )
]
plot_data[, stage := factor(stage, levels = stage_levels)]

fig_ps_density <- ggplot(plot_data, aes(x = p_score)) +
  geom_density(
    aes(color = group_label, fill = group_label),
    linewidth = 0.8,
    alpha = 0.1
  ) +
  scale_fill_manual(values = c("darkblue", "darkred")) +
  scale_color_manual(values = c("darkblue", "darkred")) +
  scale_x_continuous(breaks = seq(0, 1, 0.2)) +
  theme_minimal() +
  theme(
    legend.title = element_blank(),
    legend.position = "bottom",
    legend.text = element_text(size = 10),
    axis.text = element_text(size = 10),
    axis.title = element_text(size = 10)
  ) +
  labs(x = "Propensity Score", y = "Density")

if (trimming_applied) {
  vline_data <- data.table::data.table(
    stage = factor(stage_levels[1], levels = stage_levels),
    xintercept = ps_trim_bounds
  )
  fig_ps_density <- fig_ps_density +
    facet_wrap(~stage, ncol = 1) +
    geom_vline(
      data = vline_data,
      aes(xintercept = xintercept),
      linetype = "dashed",
      color = "grey40",
      linewidth = 0.5
    )
}

ggsave(
  filename = paste0(deap_name, "_D5_PS_density_plot.png"),
  path = cfg$output_d5,
  plot = fig_ps_density,
  width = 18,
  height = if (trimming_applied) 18 else 10,
  dpi = 300,
  units = "cm"
)
logger::log_info("PS density plot saved to D5_results/")


# ================================================================
# 2. Table to for description and diagnostics for propensity scores
# and stabilized IPT weights
# ================================================================
logger::log_info("Creating weight description table")

# describe_iptw() produces a summary table of the stabilized weights per group.
# Manually including the truncation per group
selected_iptw <- d4_iptw[include_after_trimming == TRUE]

trunc_cutoffs <- selected_iptw[,
  .(
    P1 = round(quantile(stabilized_iptw, 0.01), 4),
    P99 = round(quantile(stabilized_iptw, 0.99), 4)
  ),
  by = group
]

weight_table <- describe_iptw(
  p_matrix = selected_iptw,
  groups = c("CONTROL", "EXPOSED"),
  stab_weight_col = "stabilized_iptw",
  custom_truncation = c(NA, NA),
  digits = 4
)

# Patch in per-group truncation cutoffs
weight_table[
  weight_table$labels == "If truncated, cut-offs",
  c("CONTROL_V1", "CONTROL_V2")
] <- trunc_cutoffs[group == "CONTROL", .(P1, P99)]
weight_table[
  weight_table$labels == "If truncated, cut-offs",
  c("EXPOSED_V1", "EXPOSED_V2")
] <- trunc_cutoffs[group == "EXPOSED", .(P1, P99)]

picard::save(
  data = format_iptw_summary(weight_table),
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_IPTW_distribution.csv")
)
logger::log_info("IPTW distribution table saved to D5_results/")

# Per-group summary of propensity scores on the full (pre-trim) cohort.
ps_description <- describe_iptw(
  p_matrix = d4_iptw[!is.na(p_score)],
  groups = c("CONTROL", "EXPOSED"),
  stab_weight_col = "p_score",
  custom_truncation = if (is.null(ps_trim_bounds)) {
    c(NA, NA)
  } else {
    ps_trim_bounds
  },
  digits = 4
)

picard::save(
  data = format_iptw_summary(ps_description),
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_PS_distribution.csv")
)
logger::log_info("PS distribution table saved to D5_results/")


# ================================================================
# 3. Table describing the parameters of the fitted propensity score
#    model in terms of odds ratio
# ================================================================
logger::log_info("Creating PS model parameters (OR) table")

ps_model_parameters <- format_ps_model_parameters(d5_ps_coef, ps_variables)

# The OR table names the CNS levels by their raw code, both on the reference
# row and on the coefficient rows. Name them as the baseline table and the
# love plot
ps_model_parameters[
  trimws(Characteristic) %in% names(CNS_MET_RT_LABELS),
  Characteristic := paste0(
    "  ",
    unname(CNS_MET_RT_LABELS[trimws(Characteristic)])
  )
]

picard::save(
  data = ps_model_parameters,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_PS_model_parameters.csv")
)
logger::log_info("PS model parameters table saved to D5_results/")


# ================================================================
# 3b. Baseline characteristics before vs after PS trimming + aSMD
# ================================================================
logger::log_info("Creating baseline before/after trimming table")

baseline_trimming_table <- build_baseline_trimming_table(
  d4_covariates = d4_covariates,
  d4_iptw = d4_iptw,
  metadata = baseline_metadata
)

picard::save(
  data = baseline_trimming_table,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_baseline_trimming_table.csv")
)
logger::log_info("Baseline trimming table saved to D5_results/")


# ================================================================
# 4. Weighted ASDs, one per categorical level
# ================================================================
logger::log_info("Computing weighted ASDs")

# DescriptiveTable expects type NUM1/NUM2 instead of NUM and levels from the baseline metadata
asd_metadata <- ps_variables[, .(
  var,
  type = data.table::fifelse(vartype == "NUM", "NUM1", vartype),
  label
)]
asd_metadata[baseline_metadata, on = "var", expectedCat := i.expectedCat]

# Merge covariates with truncated weights for the included population
cov_with_weights <- merge(
  d4_covariates,
  d4_iptw[
    include_after_trimming == TRUE,
    .(person_id, w = stabilized_trunc_iptw)
  ],
  by = "person_id"
)

asd_combined <- build_asd_table(cov_with_weights, asd_metadata)

# One row per level, so the label has to name the level. CNS_MET_RT_LABELS
# comes from baseline_table_function.R, so the plot and the table agree.
asd_combined[,
  label := data.table::fcase(
    var == "SV_CNS_MET_RT" , unname(CNS_MET_RT_LABELS[cat]) ,
    type == "CAT"          , paste0(label, ": ", cat)       ,
    default = label
  )
]

picard::save(
  data = asd_combined,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_weighting_asd.csv")
)
logger::log_info("Weighting ASD table saved to D5_results/")


# ================================================================
# 5. Plot of weighed vs unweighted ASDs
# ================================================================
logger::log_info("Creating ASD comparison plot")

asd_plot_data <- data.table::melt(
  asd_combined,
  id.vars = c("var", "type", "label", "cat"),
  measure.vars = c("asd_unwt", "asd_wt"),
  variable.name = "method",
  value.name = "asd"
)
asd_plot_data[,
  method := factor(
    method,
    levels = c("asd_unwt", "asd_wt"),
    labels = c("Before weighting", "After weighting")
  )
]

# Keep the levels of a variable together: metadata order top to bottom, which
# coord_flip() reverses.
asd_plot_data[, label := factor(label, levels = rev(asd_combined$label))]

fig_asd <- ggplot(
  asd_plot_data[!is.na(asd)],
  aes(x = label, y = asd, color = method, shape = method)
) +
  geom_point(size = 3) +
  geom_hline(
    yintercept = 0.1,
    linetype = "dashed",
    color = "black",
    linewidth = 0.5
  ) +
  coord_flip() +
  scale_shape_manual(values = c(1, 16)) +
  scale_color_manual(values = c("darkblue", "darkblue")) +
  theme_minimal() +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 10),
    axis.text = element_text(size = 10),
    axis.title = element_text(size = 10)
  ) +
  labs(x = NULL, y = "Absolute Standardised Difference")

ggsave(
  filename = paste0(deap_name, "_D5_weighting_asd_plot.png"),
  path = cfg$output_d5,
  plot = fig_asd,
  width = 20,
  height = 14,
  dpi = 300,
  units = "cm"
)
logger::log_info("ASD comparison plot saved to D5_results/")


# ================================================================
# 6. Plot densities of stabilized IPT weights before vs after
#    truncation at P1/P99, by group, on the post-trim cohort.
# ================================================================
logger::log_info("Creating IPTW density plot")

iptw_stage_levels <- c("Before truncation", "After truncation at P1/P99")
iptw_plot_data <- data.table::melt(
  d4_iptw[include_after_trimming == TRUE],
  id.vars = c("person_id", "group"),
  measure.vars = c("stabilized_iptw", "stabilized_trunc_iptw"),
  variable.name = "stage",
  value.name = "weight"
)
iptw_plot_data[,
  stage := factor(
    stage,
    levels = c("stabilized_iptw", "stabilized_trunc_iptw"),
    labels = iptw_stage_levels
  )
]
iptw_plot_data[,
  group_label := factor(
    group,
    levels = c("CONTROL", "EXPOSED"),
    labels = c("Control", "Exposed")
  )
]

fig_iptw_density <- ggplot(iptw_plot_data, aes(x = weight)) +
  geom_histogram(
    aes(color = group_label, fill = group_label),
    bins = 30,
    position = "identity",
    alpha = 0.4
  ) +
  scale_fill_manual(values = c("darkblue", "darkred")) +
  scale_color_manual(values = c("darkblue", "darkred")) +
  facet_wrap(~stage, ncol = 1, scales = "free_y") +
  theme_minimal() +
  theme(
    legend.title = element_blank(),
    legend.position = "bottom",
    legend.text = element_text(size = 10),
    axis.text = element_text(size = 10),
    axis.title = element_text(size = 10)
  ) +
  labs(x = "Stabilized IPT weight", y = "Frequency")

ggsave(
  filename = paste0(deap_name, "_D5_IPTW_density_plot.png"),
  path = cfg$output_d5,
  plot = fig_iptw_density,
  width = 18,
  height = 18,
  dpi = 300,
  units = "cm"
)
logger::log_info("IPTW density plot saved to D5_results/")


# --- Cleanup ---
rm(
  d4_iptw,
  d4_covariates,
  d5_ps_coef,
  ps_variables,
  selected_iptw,
  plot_data,
  fig_ps_density,
  trunc_cutoffs,
  weight_table,
  ps_description,
  ps_model_parameters,
  baseline_metadata,
  baseline_trimming_table,
  asd_metadata,
  cov_with_weights,
  asd_combined,
  asd_plot_data,
  fig_asd,
  iptw_plot_data,
  fig_iptw_density
)

logger::log_info("[describe_d4_StudyCohort_IPTW] - SUCCEED")

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
