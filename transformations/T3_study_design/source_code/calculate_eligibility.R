# calculate_eligibility ---
#
# Input files: ---
# - D3_MULTIVARIATE_EPISODES.parquet
#
# Output:
# D3_ELIGIBILITY.parquet

# Initial setup ----
## Script logger ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("calculate_eligibility")
  lm$start_capturing_prints()
}

## Config loading ----
picard::load_config()

## Audit setup ----
picard::audit_start(
  file_name = "calculate_eligibility",
  deap_name = config_project$DEAP_configuration$name
)

## Extract config paths ----
dir_d3 <- config_project$outputs$dir_d3

## Source function ----
source(file.path(
  "transformations",
  "T3_study_design",
  "source_code",
  "functions",
  "calculate_eligibility_function.R"
))

# Load input data ----
# d3_multivariate_episodes <- picard::load(
#   file_path = dir_d3,
#   file_name = "D3_MULTIVARIATE_EPISODES.parquet"
# )
# If multivariate stored in batches
possible_batching_dir <- "data/D3_study_variables/D3_MULTIVARIATE_EPISODES"
if (dir.exists(possible_batching_dir)) {
  d3_multivariate_episodes <- data.table::as.data.table(arrow::open_dataset(
    possible_batching_dir,
  ))
}
picard::audit_add(paste("Input rows:", nrow(d3_multivariate_episodes)))

# Calculate eligibility ----
d3_eligibility <- calculate_eligibility(d3_multivariate_episodes)
picard::audit_add(paste("Output rows:", nrow(d3_eligibility)))
picard::audit_add(paste(
  "Eligible exposed spells:",
  sum(d3_eligibility$eligible_exposed)
))
picard::audit_add(paste(
  "Eligible control spells:",
  sum(d3_eligibility$eligible_control)
))

# Output ----
## Save output ----
picard::save(
  data = d3_eligibility,
  file_path = dir_d3,
  file_name = "D3_ELIGIBILITY.parquet"
)

# Cleanup ----
rm(d3_multivariate_episodes, d3_eligibility)
picard::audit_end()

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
