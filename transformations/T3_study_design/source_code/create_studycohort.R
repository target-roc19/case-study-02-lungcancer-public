# create_studycohort ----
#
# Input:  D3_ELIGIBILITY.parquet
# Output: D4_StudyCohort.parquet

# Initial setup ----
## Script logger ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("create_studycohort")
  lm$start_capturing_prints()
}

## Config loading ----
picard::load_config()

## Audit setup ----
picard::audit_start(
  file_name = "create_studycohort",
  deap_name = config_project$DEAP_configuration$name
)

## Extract config paths ----
dir_d3 <- config_project$outputs$dir_d3
dir_d4 <- config_project$outputs$dir_d4

## Source function ----
source(file.path(
  config_t3$T3$root,
  config_t3$T3$functions,
  "create_studycohort_function.R"
))

# Load input data ----
d3_eligibility <- picard::load(
  file_path = dir_d3,
  file_name = "D3_ELIGIBILITY.parquet"
)
picard::audit_add(paste("Input rows:", nrow(d3_eligibility)))

# Create D4_StudyCohort ----
d4_studycohort <- create_studycohort(d3_eligibility)
picard::audit_add(paste("D4_StudyCohort rows:", nrow(d4_studycohort)))
picard::audit_add(paste(
  "Exposed:",
  sum(d4_studycohort$group == "EXPOSED"),
  "Control:",
  sum(d4_studycohort$group == "CONTROL")
))

# Output ----
picard::save(
  data = d4_studycohort,
  file_path = dir_d4,
  file_name = "D4_StudyCohort.parquet"
)

# Cleanup ----
rm(d3_eligibility, d4_studycohort)
picard::audit_end()

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
