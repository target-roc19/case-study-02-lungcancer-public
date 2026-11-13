# ---------------------------------------------------------------
# Step: baseline_table
#
# Input:  D4_StudyCohort_Covariates
#         D4_StudyCohort_IPTW
#
# Output: <DEAP>_D5_baseline_table.csv  -- Baseline characteristics of study population
#
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("baseline_table.R")
  lm$start_capturing_prints()
}

logger::log_info("[baseline_table] - START")

# --- Config loading ---
picard::load_config()

deap_name <- config_project$DEAP_configuration$name
cfg <- config_project$baseline_table

# --- Source functions ---
functions_dir <- file.path(
  config_t4$T4$root,
  config_t4$T4$source_code,
  "functions"
)
source(file.path(functions_dir, "baseline_table_function.R"))

# --- Read inputs ---
if (isTRUE(cfg$use_synthetic_data)) {
  covariates_path <- cfg$synthetic_covariates
  iptw_path <- cfg$synthetic_iptw
} else {
  covariates_path <- cfg$d4_covariates
  iptw_path <- cfg$d4_iptw
}
logger::log_info(paste(
  "Reading D4_StudyCohort_Covariates from:",
  covariates_path
))
d4_covariates <- picard::load(covariates_path)

logger::log_info(paste("Reading D4_StudyCohort_IPTW from:", iptw_path))
d4_iptw <- picard::load(iptw_path)
logger::log_info(paste(
  "Reading variable metadata from:",
  cfg$baseline_metadata
))
baseline_metadata <- picard::load(cfg$baseline_metadata, sep = ";")

# --- Build table ---
baseline <- build_baseline_table(
  d4_covariates = d4_covariates,
  d4_iptw = d4_iptw,
  metadata = baseline_metadata,
  mask = TRUE
)

# --- Save outputs ---
picard::save(
  data = baseline,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_baseline_table.csv")
)

# --- Cleanup ---
rm(d4_covariates, d4_iptw, baseline_metadata, baseline)

logger::log_info("[baseline_table] - SUCCEED")

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
