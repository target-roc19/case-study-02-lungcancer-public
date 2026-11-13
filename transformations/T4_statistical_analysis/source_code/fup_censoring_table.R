# ---------------------------------------------------------------
# Step: fup_censoring_table
#
# Input:  D4_StudyCohort_FUP
#
# Output: <DEAP>_D5_fup_censoring_table.csv
# Table X. Follow-up time and censoring overall and by treatment group
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("fup_censoring_table.R")
  lm$start_capturing_prints()
}

logger::log_info("[fup_censoring_table] - START")

# --- Config loading ---
picard::load_config()

deap_name <- config_project$DEAP_configuration$name
cfg <- config_project$fup_censoring_table

# --- Source functions ---
source(file.path(
  config_t4$T4$root,
  config_t4$T4$source_code,
  "functions",
  "fup_censoring_table_function.R"
))

# --- Read inputs ---
input_path <- if (isTRUE(cfg$use_synthetic_data)) {
  cfg$synthetic_fup
} else {
  cfg$d4_fup
}
logger::log_info(paste("Reading D4_StudyCohort_FUP from:", input_path))
d4_fup <- picard::load(input_path)

# --- Build table ---
fup_censoring <- build_fup_censoring_table(d4_fup)

# --- Save outputs ---
picard::save(
  data = fup_censoring,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_fup_censoring_table.csv")
)

# --- Cleanup ---
rm(d4_fup, fup_censoring)

logger::log_info("[fup_censoring_table] - SUCCEED")

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
