# ---------------------------------------------------------------
# Step: compute_d4_StudyCohort_IPTW
#
# Input:  D4_StudyCohort_Covariates
#         psmodel_variables.csv
#
# Output: D4_StudyCohort_IPTW
#         <DEAP>_D5_PS_Coef.csv
#         <DEAP>_D5_PS_ModelBuilding.csv
#
# Orchestrator script to generate a propensity score model and compute IPTW.
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("compute_d4_StudyCohort_IPTW.R")
  lm$start_capturing_prints()
}

logger::log_info("[compute_d4_StudyCohort_IPTW] - START")

# --- Config loading ---
picard::load_config()

deap_name <- config_project$DEAP_configuration$name
cfg <- config_project$compute_d4_StudyCohort_IPTW

# --- Source functions ---
source(file.path(
  config_t3$T3$root,
  config_t3$T3$source_code,
  "functions",
  "CohortPropensity",
  "fit_ps_model.R"
))

source(file.path(
  config_t3$T3$root,
  config_t3$T3$source_code,
  "functions",
  "compute_d4_StudyCohort_IPTW_function.R"
))

# --- Read inputs ---
covariates_path <- if (isTRUE(cfg$use_synthetic_data)) {
  cfg$synthetic_data
} else {
  cfg$d4_covariates
}
logger::log_info(paste(
  "Reading D4_StudyCohort_Covariates from:",
  covariates_path
))
d4_covariates <- picard::load(covariates_path)

logger::log_info("Reading psmodel metadata")
ps_variables <- picard::load(cfg$ps_variables, sep = ";")

# --- Compute ---
results <- compute_d4_studycohort_iptw(
  d4_covariates = d4_covariates,
  ps_variables = ps_variables,
  ps_trim_bounds = cfg$ps_trim_bounds,
  se_threshold = if (is.null(cfg$se_threshold)) 10 else cfg$se_threshold
)

# --- Save outputs ---
# D4 (analytic dataset): no DEAP prefix; each DAP owns its D4 directory
picard::save(
  data = results$D4_StudyCohort_IPTW,
  file_path = cfg$output_d4,
  file_name = "D4_StudyCohort_IPTW.parquet"
)

# D5 (per-DAP results): prefixed with DEAP name for the central meta-analysis
picard::save(
  data = results$D5_PS_Coef,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_PS_Coef.csv")
)

picard::save(
  data = results$D5_PS_ModelBuilding,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_PS_ModelBuilding.csv")
)

logger::log_info(paste(
  "D4_StudyCohort_IPTW:",
  nrow(results$D4_StudyCohort_IPTW),
  "rows"
))

# --- Cleanup ---
rm(d4_covariates, ps_variables, results)

logger::log_info("[compute_d4_StudyCohort_IPTW] - SUCCEED")

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
