# ---------------------------------------------------------------
# Step: survival_supplement
#
# Input:  D4_StudyCohort_Analysis
#
# Output: <DEAP>_D5_km_crude_plot.png    -- crude Kaplan-Meier curves
#         <DEAP>_D5_km_iptw_plot.png     -- IPTW-weighted Kaplan-Meier curves
#         <DEAP>_D5_schoenfeld_plot.png  -- scaled Schoenfeld residuals
#         <DEAP>_D5_loglog_plot.png      -- log(-log) survival plot
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
log_starter()

library(ggplot2)

logger::log_info("[survival_supplement] - START")

# --- Config loading ---
picard::load_config()

deap_name <- config_project$DEAP_configuration$name
cfg <- config_project$survival_supplement

# --- Source functions ---
source(file.path(
  config_t4$T4$root,
  config_t4$T4$source_code,
  "functions",
  "survival_supplement_function.R"
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

# --- Build + save figures ---
save_fig <- function(plot, name, width = 18, height = 14) {
  ggsave(
    filename = paste0(deap_name, "_D5_", name, ".png"),
    path = cfg$output_d5,
    plot = plot,
    width = width,
    height = height,
    dpi = 300,
    units = "cm"
  )
}

save_fig(plot_km(lookup, weighted = FALSE), "km_crude_plot")
save_fig(plot_km(lookup, weighted = TRUE), "km_iptw_plot")
save_fig(plot_schoenfeld(lookup), "schoenfeld_plot")
save_fig(plot_loglog(lookup), "loglog_plot")
logger::log_info("Supplemental survival figures saved to D5_results/")

# --- Cleanup ---
rm(lookup)

logger::log_info("[survival_supplement] - SUCCEED")

log_ender()
