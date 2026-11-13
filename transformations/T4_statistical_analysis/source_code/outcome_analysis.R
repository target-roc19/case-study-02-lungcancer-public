# ---------------------------------------------------------------
# Step: outcome_analysis
#
# Input:  D4_StudyCohort_Analysis
#
# Output: <DEAP>_D5_outcome_hr_table.csv     -- Estimand 1: crude/adj HR
#         <DEAP>_D5_outcome_rmst_table.csv    -- Estimand 2: Weibull AFT RMST
#         <DEAP>_D5_outcome_forest_plot.png   -- adjusted subgroup HRs
#         <DEAP>_D5_outcome_forest_data.csv   -- HRs/CIs used for forest plot
#         D4_StudyCohort_WeibullAFT_models.rds -- save models
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
log_starter()

logger::log_info("[outcome_analysis] - START")

# --- Config loading ---
picard::load_config()

deap_name <- config_project$DEAP_configuration$name
cfg <- config_project$outcome_analysis
dir_d4 <- config_project$outputs$dir_d4

# --- Source functions ---
source(file.path(
  config_t4$T4$root,
  config_t4$T4$source_code,
  "functions",
  "outcome_analysis_function.R"
))

# --- Read inputs ---
lookup_path <- if (isTRUE(cfg$use_synthetic_data)) {
  cfg$synthetic_analysis
} else {
  cfg$d4_analysis
}
logger::log_info(paste(
  "Reading D4_StudyCohort_Analysis from:",
  lookup_path
))
lookup <- picard::load(lookup_path)

# --- Build outputs ---
# The HR count table is masked (disclosure control) before saving. The forest
# data saved alongside the figure carries only the plotted HRs/CIs
weibull_models <- fit_weibull_models(lookup)
hr_table <- mask_hr_table(build_outcome_hr_table(lookup))
rmst_table <- build_rmst_table(weibull_models)
forest_data <- build_forest_data(lookup)
forest_plot <- plot_forest(forest_data)

# --- Save outputs ---
picard::save(
  data = hr_table,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_outcome_hr_table.csv")
)
picard::save(
  data = rmst_table,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_outcome_rmst_table.csv")
)
ggplot2::ggsave(
  filename = paste0(deap_name, "_D5_outcome_forest_plot.png"),
  path = cfg$output_d5,
  plot = forest_plot,
  width = 20,
  height = 12,
  dpi = 300,
  units = "cm"
)
# Only the plotted quantities (subgroup HR + CI) not saving counts
picard::save(
  data = forest_data[, .(subgroup, hr, lb, ub)],
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_outcome_forest_data.csv")
)
logger::log_info("Outcome analysis outputs saved to D5_results/")

# Save  Weibull AFT models object
saveRDS(
  weibull_models,
  file.path(dir_d4, "D4_StudyCohort_WeibullAFT_models.rds")
)
logger::log_info("Weibull AFT models saved to D4_analytic_datasets/")

# --- Cleanup ---
rm(lookup, weibull_models, hr_table, rmst_table, forest_data, forest_plot)

logger::log_info("[outcome_analysis] - SUCCEED")

log_ender()
