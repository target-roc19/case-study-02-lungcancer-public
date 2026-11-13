# anchor_studyvariables ----
#
# Input:  D4_StudyCohort.parquet, D3_CONCEPTS_parquet, study_variables.csv
# Output: D4_STUDYVARIABLES_ANCHORED_parquet (hive, partitioned by variable_id)

# Initial setup ----
## Script logger ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("anchor_studyvariables")
  lm$start_capturing_prints()
}

## Config loading ----
picard::load_config()

## Audit setup ----
picard::audit_start(
  file_name = "anchor_studyvariables",
  deap_name = config_project$DEAP_configuration$name
)

## Extract config paths ----
cfg <- config_project$anchor_studyvariables
dir_d4 <- config_project$outputs$dir_d4

## Source function ----
source(file.path(
  config_t3$T3$root,
  config_t3$T3$functions,
  "anchor_studyvariables_function.R"
))

# Load input data ----
d4_studycohort <- picard::load(file_path = cfg$d4_studycohort)
study_vars <- picard::load(
  file_path = config_pipeline$common$dir_bridge,
  file_name = "study_variables.csv"
)
picard::audit_add(paste("Study cohort rows:", nrow(d4_studycohort)))

# Build anchor population (person_id, T0) ----
population <- unique(
  d4_studycohort[, .(person_id, T0 = base::as.Date(T0))]
)
picard::audit_add(paste("Anchor population rows:", nrow(population)))

# Combine metadata ----
metadata <- combine_metadata(study_vars)
picard::audit_add(paste("Anchored variables:", nrow(metadata)))

picard::save(
  data = metadata,
  file_path = file.path(config_t3$T3$root, config_t3$T3$config),
  file_name = "combined_anchor_metadata.csv"
)

# Anchor ----
anchor_hive_path <- file.path(dir_d4, cfg$output_hive)
anchoR::anchor_by_variable(
  population = population,
  metadata = metadata,
  concepts = cfg$d3_concepts,
  anchor_col = "T0",
  anchor_hive_path = anchor_hive_path
)

# Cleanup ----
rm(d4_studycohort, study_vars, population, metadata)
picard::audit_end()

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
