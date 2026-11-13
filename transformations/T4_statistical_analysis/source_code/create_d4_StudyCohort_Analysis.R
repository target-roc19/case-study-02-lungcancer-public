# ---------------------------------------------------------------
# Step: create_d4_StudyCohort_Analysis
#
# Input:  D4_StudyCohort_FUP
#         D4_StudyCohort_IPTW
#         D4_StudyCohort_Covariates
#
# Output: D4_StudyCohort_Analysis.parquet
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
log_starter()

logger::log_info("[create_d4_StudyCohort_Analysis] - START")

# --- Config loading ---
picard::load_config()

cfg <- config_project$create_d4_StudyCohort_Analysis
dir_d4 <- config_project$outputs$dir_d4

# --- Source functions ---
source(file.path(
  config_t4$T4$root,
  config_t4$T4$source_code,
  "functions",
  "create_d4_StudyCohort_Analysis_function.R"
))

# --- Read inputs ---
if (isTRUE(cfg$use_synthetic_data)) {
  fup_path <- cfg$synthetic_fup
  iptw_path <- cfg$synthetic_iptw
  covariates_path <- cfg$synthetic_covariates
} else {
  fup_path <- cfg$d4_fup
  iptw_path <- cfg$d4_iptw
  covariates_path <- cfg$d4_covariates
}
logger::log_info(paste("Reading D4_StudyCohort_FUP from:", fup_path))
d4_fup <- picard::load(fup_path)
logger::log_info(paste("Reading D4_StudyCohort_IPTW from:", iptw_path))
d4_iptw <- picard::load(iptw_path)
logger::log_info(paste(
  "Reading D4_StudyCohort_Covariates from:",
  covariates_path
))
d4_covariates <- picard::load(covariates_path)

# --- Build analysis dataset ---
d4_analysis <- create_d4_studycohort_analysis(
  d4_fup = d4_fup,
  d4_iptw = d4_iptw,
  d4_covariates = d4_covariates
)
logger::log_info(paste(
  "D4_StudyCohort_Analysis:",
  nrow(d4_analysis),
  "rows |",
  sum(d4_analysis$include_after_trimming),
  "after trimming |",
  sum(d4_analysis$event_death),
  "events"
))

# --- Save output ---
picard::save(
  data = d4_analysis,
  file_path = dir_d4,
  file_name = "D4_StudyCohort_Analysis.parquet"
)

# --- Cleanup ---
rm(d4_fup, d4_iptw, d4_covariates, d4_analysis)

logger::log_info("[create_d4_StudyCohort_Analysis] - SUCCEED")

log_ender()
