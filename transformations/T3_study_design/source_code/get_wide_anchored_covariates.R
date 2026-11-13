# get_wide_anchored_covariates ----
#
# Input:  D4_STUDYVARIABLES_ANCHORED_parquet/, D4_StudyCohort.parquet,
#         combined_anchor_metadata.csv
# Output: D4_StudyCohort_Covariates.parquet

# Initial setup ----
## Script logger ----
if (
  !base::exists("lm", inherits = TRUE) ||
    !base::inherits(lm, "LoggerManager")
) {
  lm <- NULL
}
if (!base::is.null(lm)) {
  lm$start_script("get_wide_anchored_covariates")
  lm$start_capturing_prints()
}

## Config loading ----
picard::load_config()

## Audit setup ----
picard::audit_start(
  file_name = "get_wide_anchored_covariates",
  deap_name = config_project$DEAP_configuration$name
)

## Extract config paths ----
cfg <- config_project$get_wide_anchored_covariates
dir_d4 <- config_project$outputs$dir_d4

# Load input data ----
d4_studycohort <- picard::load(file_path = cfg$d4_studycohort)
d4_studycohort[, T0 := base::as.Date(T0)]

metadata <- picard::load(file_path = cfg$combined_anchor_metadata)

# Build wide covariate table ----
# impute_missing = TRUE: anchoR replaces NA cells per the bridge rules carried
# in variable_type + is_expected_missing (BOOL -> FALSE, CAT -> 0 when
# missing_set_to != NULL). See anchoR::imputing_missing.
covariate_meta <- metadata[covariate == TRUE & window_name == "covariate"]
d4_studycohort_covariates <- anchoR::get_anchor_result(
  metadata = covariate_meta,
  anchor_hive_path = cfg$anchor_hive,
  result_shape = "wide",
  population = d4_studycohort,
  impute_missing = TRUE
)
data.table::setDT(d4_studycohort_covariates)

# Tidy wide output ----
date_cols <- grep("^date_", names(d4_studycohort_covariates), value = TRUE)
drop_cols <- c(
  date_cols,
  intersect("window_name", names(d4_studycohort_covariates))
)
if (length(drop_cols) > 0L) {
  d4_studycohort_covariates[, (drop_cols) := NULL]
}

value_cols <- grep("^value_", names(d4_studycohort_covariates), value = TRUE)
if (length(value_cols) > 0L) {
  data.table::setnames(
    d4_studycohort_covariates,
    value_cols,
    sub("^value_", "", value_cols)
  )
}

# anchoR only imputes BOOL to FALSE / CAT to 0 and skips CHARACTER, so character covariates stay NA and would drop the person from the PS
# model
impute_meta <- covariate_meta[missing_set_to != "NULL"]
for (i in seq_len(nrow(impute_meta))) {
  v <- impute_meta$variable_id[i]
  if (!v %in% names(d4_studycohort_covariates)) {
    next
  }
  if (!anyNA(d4_studycohort_covariates[[v]])) {
    next
  }
  d4_studycohort_covariates[
    is.na(get(v)),
    (v) := impute_meta$missing_set_to[i]
  ]
}

# anchoR returns concept values as character (the hive holds mixed types under
# one value column). Cast INTEGER-typed covariates so T4 doesn't have to.
int_vars <- covariate_meta[
  data_type == "INTEGER" & variable_id %in% names(d4_studycohort_covariates),
  variable_id
]
for (v in int_vars) {
  d4_studycohort_covariates[, (v) := as.integer(get(v))]
}

# SV_SEX and SV_AGE are person-level statics that aren't written to
# D3_CONCEPTS by T2 (sex lives in D3_PERSONS; age is derived from birth_date).
# Anchoring them returns NA, so we overwrite from D3_PERSONS here.
d3_persons <- picard::load(file_path = cfg$d3_persons)
data.table::setDT(d3_persons)
d4_studycohort_covariates <- merge(
  d4_studycohort_covariates,
  d3_persons[, .(
    person_id,
    .sex = sex_at_instance_creation,
    .birth = birth_date
  )],
  by = "person_id",
  all.x = TRUE
)
d4_studycohort_covariates[, SV_SEX := .sex]
d4_studycohort_covariates[,
  SV_AGE := as.integer(floor(as.numeric(T0 - .birth) / 365.25))
]
# Categorical age for the PS model (continuous SV_AGE does not balance under
# IPTW). Continuous SV_AGE is kept for the baseline table; SV_AGE_CAT is the
# PS-model covariate (see psmodel_variables.csv).
d4_studycohort_covariates[,
  SV_AGE_CAT := as.character(cut(
    SV_AGE,
    breaks = c(-Inf, 65, 76, Inf),
    labels = c("<65", "65-75", ">75"),
    right = FALSE
  ))
]
d4_studycohort_covariates[, c(".sex", ".birth") := NULL]

# Collapse CNS metastasis + CNS radiotherapy into one 3-level PS-model covariate.

d4_studycohort_covariates[,
  SV_CNS_MET_RT := data.table::fcase(
    is.na(SV_METASTASIS_CNS) | !as.logical(SV_METASTASIS_CNS)                            , "NO_CNS_MET" ,
    is.na(SV_RT_CNS) | toupper(trimws(as.character(SV_RT_CNS))) %in% c("NONE", "NA", "") , "CNS_NO_RT"  ,
    default = "CNS_WITH_RT"
  )
]

picard::audit_add(paste(
  "D4_StudyCohort_Covariates rows:",
  nrow(d4_studycohort_covariates)
))

# Output ----
picard::save(
  data = d4_studycohort_covariates,
  file_path = dir_d4,
  file_name = "D4_StudyCohort_Covariates.parquet"
)

# Cleanup ----
rm(
  d4_studycohort,
  d3_persons,
  metadata,
  covariate_meta,
  d4_studycohort_covariates
)
picard::audit_end()

if (!base::is.null(lm)) {
  lm$stop_capturing_prints()
  lm$end_script()
}
