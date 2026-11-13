# calculate_fup ----
#
# Input:  D4_StudyCohort.parquet, D3_PERSONS.parquet, config_values.yaml
# Output: D4_StudyCohort_FUP.parquet

# Initial setup ----
## Script logger ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("calculate_fup")
  lm$start_capturing_prints()
}

## Config loading ----
picard::load_config()

## Audit setup ----
picard::audit_start(
  file_name = "calculate_fup",
  deap_name = config_project$DEAP_configuration$name
)

## Extract config paths ----
cfg <- config_project$calculate_fup
dir_d4 <- config_project$outputs$dir_d4

## Source function ----
source(file.path(
  config_t3$T3$root,
  config_t3$T3$functions,
  "calculate_fup_function.R"
))

# Load input data ----
d4_studycohort <- picard::load(file_path = cfg$d4_studycohort)
d3_persons <- picard::load(file_path = cfg$d3_persons)

# censoring_date is end of follow-up = end of data collection
# Both end_study_period and end_of_data_collection in the FUP object are driven by main_censoring_date
main_censoring_date <- picard::get_date_value(
  config_values$main_censoring_date
)

max_fup_days <- as.integer(config_values$max_fup_days)

picard::audit_add(paste("Study cohort rows:", nrow(d4_studycohort)))
picard::audit_add(paste("censoring_date:", format(main_censoring_date)))
picard::audit_add(paste("max_fup_days:", max_fup_days))

# Build D4_StudyCohort_FUP ----
d4_fup <- calculate_fup(
  d4_studycohort = d4_studycohort,
  d3_persons = d3_persons,
  end_study_date = main_censoring_date,
  end_of_data_collection_date = main_censoring_date,
  max_fup_days = max_fup_days
)
picard::audit_add(paste("D4_StudyCohort_FUP rows:", nrow(d4_fup)))
picard::audit_add(paste("Events (deaths):", sum(d4_fup$event_death)))

# Output ----
picard::save(
  data = d4_fup,
  file_path = dir_d4,
  file_name = "D4_StudyCohort_FUP.parquet"
)

# Cleanup ----
rm(d4_studycohort, d3_persons, d4_fup)
picard::audit_end()

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
