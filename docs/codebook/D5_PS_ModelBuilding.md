## Metadata

| Table name                | D5_PS_ModelBuilding                                                                                                                                                                                                                                                               |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description               | File that describes the model building procedure for a propensity score model;<br />starting from an initial list of variables to be included in the model, <br />describing if each variable meets different data quality and/or data driven criteria to be included as relevant |
| Source                    | `D4_StudyCohort_Covariates`                                                                                                                                                                                                                                                     |
| Step                      | `transformations/T3_study_design/source_code/compute_d4_StudyCohort_IPTW.R`; written as `<DEAP>_D5_PS_ModelBuilding.csv` in data/D5_results                                                                                                                                       |
| Content                   | In/exclusion criteria assessment for every candidate variable for the final PS models.                                                                                                                                                                                            |
| Population                | Candidate variables to be included in the propensity score model for the study cohort                                                                                                                                                                                             |
| Unit of Observation (UoO) | One row per candidate variable listed in psmodel_variables.csv                                                                                                                                                                                                                    |


## Codebook

| Variable name    | Description                                                                                                                                                                                                                          | Source used for the variable                   | format    | rule_of_calculation                             | vocabulary                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------- | --------- | ----------------------------------------------- | --------------------------------------------------- |
| variable_id      | All candidate variables for the PS model                                                                                                                                                                                             | psmodel_variables.csv::var                     | Character |                                                 |                                                     |
| var_type         | Variable type, determines how the variable is prepared for the model                                                                                                                                                                 | psmodel_variables.csv::vartype                 | Character |                                                 | NUM; CAT; TF                                        |
| force_in         | does psmodel_variables.csv specify to force this variable into the model regardless of any data driven criteria.<br />Only relevant when data driven criteria are used; TRUE for all variables in this study                         | psmodel_variables.csv::force_in                | TF        |                                                 | TRUE, FALSE                                         |
| force_out        | does psmodel_variables.csv specify to force this variable out of the model regardless of meeting data driven inclusion criteria.<br />Not a column of psmodel_variables.csv in this study, so it defaults to FALSE for all variables | psmodel_variables.csv::force_out (optional)    | TF        | FALSE when the column is absent                 | TRUE, FALSE                                         |
| missing_pct      | Missing value percentage for the variable across all individuals. Reported for transparency only: it is not used as an exclusion criterion                                                                                           | D4_StudyCohort_Covariates                      | Numeric   | 100 * sum(is.na(var)) / nrow(data)              | [0, 100]                                            |
| nonzero_variance | does the variable have non-zero variance (i.e., not all individuals have the same covariate value in the cohort)                                                                                                                     | D4_StudyCohort_Covariates                      | TF        | length(unique(non-missing values)) >= 2         | TRUE, FALSE                                         |
| include_r1       | Whether the candidate variable is included in the initial (Round 1) model                                                                                                                                                            | nonzero_variance, force_out                    | TF        | nonzero_variance == TRUE AND force_out == FALSE | TRUE, FALSE                                         |
| included_r2      | Whether the variable is included in the final propensity model. Equals include_r1 when Round 1 fitted cleanly                                                                                                                        | include_r1, reason_excluded                    | TF        | include_r1 == TRUE AND reason_excluded is NA    | TRUE, FALSE                                         |
| reason_excluded  | Reason the variable is not in the final model; NA if included_r2 == TRUE                                                                                                                                                             | nonzero_variance, force_out, model fit round 1 | Character | See Processing Steps                            | zero_variance; force_out; non_convergence; large_se |

## Processing Steps

1. Load `psmodel_variables.csv` to identify candidate variables for the PS model
2. For each candidate variable, compute the data quality checks: `nonzero_variance` (at least two distinct non-missing values) and `missing_pct`
3. Fit the initial PS model (Round 1) with all variables where `include_r1 = TRUE` (`nonzero_variance == TRUE` and `force_out == FALSE`). Variables dropped before Round 1 get `reason_excluded` = `zero_variance` or `force_out`
4. Check the Round 1 fit: if the model did not converge, all Round 1 variables get `reason_excluded` = `non_convergence`; any variable with a coefficient standard error above `se_threshold` (configuration/config_project.yaml, default 10 -- a sign of perfect prediction) gets `reason_excluded` = `large_se`
5. If fit issues were found: drop those variables and refit (Round 2), so `included_r2 = FALSE` for them. If no issues, Round 2 equals Round 1 and all Round 1 variables have `included_r2 = TRUE`

## Example

Output of a clean Round 1 fit: all eight pre-specified variables pass the data quality checks and enter the final model.

| variable_id         | var_type | force_in | force_out | missing_pct | nonzero_variance | include_r1 | included_r2 | reason_excluded |
| ------------------- | -------- | -------- | --------- | ----------- | ---------------- | ---------- | ----------- | --------------- |
| SV_AGE_CAT          | CAT      | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
| SV_SEX              | CAT      | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
| SV_NSCLC_HISTOLOGY  | CAT      | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
| SV_METASTASIS_LIVER | TF       | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
| SV_CNS_MET_RT       | CAT      | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
| SV_METASTASIS_BONE  | TF       | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
| SV_METASTASIS_COUNT | NUM      | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
| SV_ECOG_STATUS      | CAT      | TRUE     | FALSE     | 0           | TRUE             | TRUE       | TRUE        | NA              |
