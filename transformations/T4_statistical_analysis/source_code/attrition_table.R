# ---------------------------------------------------------------
# Step: attrition_table
#
# Input:  D3_ELIGIBILITY
#
# Output: <DEAP>_D5_attrition_table.csv
#         <DEAP>_D5_attrition_flowchart.csv
# ---------------------------------------------------------------

# --- Initial setup of the environment ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("attrition_table.R")
  lm$start_capturing_prints()
}

logger::log_info("[attrition_table] - START")

# --- Config loading ---
picard::load_config()

deap_name <- config_project$DEAP_configuration$name
cfg <- config_project$attrition_table

# --- Source functions ---
source(file.path(
  config_t4$T4$root,
  config_t4$T4$functions,
  "attrition_table_function.R"
))


# --- Read inputs ---
input_path <- if (isTRUE(cfg$use_synthetic_data)) {
  cfg$synthetic_data
} else {
  cfg$d3_eligibility
}
logger::log_info(paste("Reading D3_ELIGIBILITY from:", input_path))
d3_eligibility <- picard::load(input_path)

# --- Build attrition table ---
attrition <- build_attrition_table(d3_eligibility)

# --- Build flowchart numbers ---
flowchart <- data.table::data.table(
  step = 2:10,
  phase = c(
    "First Exclude", # step 2  -- treatment
    "Second Exclude", # step 3  -- 90-day rule
    "First Exclude", # step 4  -- age
    "First Exclude", # step 5  -- stage IV
    "First Exclude", # step 6  -- PDL1
    "First Exclude", # step 7  -- mutation
    "First Exclude", # step 8  -- previous malignancy
    "Second Exclude", # step 9  -- ECOG
    "Second Exclude" # step 10 -- chemotherapy
  ),
  reason = c(
    "did NOT receive nivolumab + ipilimumab or pembrolizumab",
    "NOT started index or reference drugs within 90 days from diagnosis",
    "were younger than 18 at index",
    "without stage IV",
    "without PDL1 <1%",
    "had EGFR, ALK or ROS1 mutation",
    "had a previous malignancy / cancer treatment",
    "had NO ECOG PS 0/1",
    "did NOT receive chemotherapy between -28 and 0 days"
  ),
  n_excluded = as.integer(-diff(attrition[step <= 10L, n]))
)

# --- Save outputs ---
picard::save(
  data = attrition,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_attrition_table.csv")
)
picard::save(
  data = flowchart,
  file_path = cfg$output_d5,
  file_name = paste0(deap_name, "_D5_attrition_flowchart.csv")
)

# --- Cleanup ---
rm(d3_eligibility, attrition, flowchart)

logger::log_info("[attrition_table] - SUCCEED")

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
