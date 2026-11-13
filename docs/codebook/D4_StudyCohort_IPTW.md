## Metadata

| Table name                | D4_StudyCohort_IPTW                                                    |
| ------------------------- | ---------------------------------------------------------------------- |
| Description               | Dataset consisting of propensity scores and IP weights for the study cohort  |
| Source                    | `D4_StudyCohort_Covariates`; configuration/`psmodel_variables.csv` |
| Step                      | `transformations/T3_study_design/source_code/compute_d4_StudyCohort_IPTW.R` |
| Content                   | Propensity scores and IP weights                                       |
| Population                | Selected study cohort (exposed and control units)                      |
| Unit of Observation (UoO) | One row per person in the study cohort                                 |

## Codebook

| variable name          | Description                                                                                                                       | variable(s) needed                   | retrieved | computed | format    | rule_of_calculation                                                                                                                | vocabulary       |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | --------- | -------- | --------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| person_id              |                                                                                                                                   | D4_StudyCohort_Covariates::person_id | x         |          | Character |                                                                                                                                    |                  |
| match_id               | ID of the matching pair. No matching is used in this study, so this column is always NA                                           |                                      |           | x        | Character | NA_character_                                                                                                                      |                  |
| T0                     |                                                                                                                                   | D4_StudyCohort_Covariates::T0        | x         |          | Date      |                                                                                                                                    |                  |
| group                  | Group identifier: EXPOSED and CONTROL                                                                                             | D4_StudyCohort_Covariates::group     | x         |          | Character |                                                                                                                                    | EXPOSED, CONTROL |
| group_binary           | Binary version of group (exposed = 1, control = 0)                                                                                | group                                |           | x        | Integer   | IF group == "EXPOSED" THEN 1 ELSE 0                                                                                                | 0, 1             |
| p_score                | Predicted probability of exposure from the final PS model                                                                         | model_final, D4_StudyCohort_Covariates |           | x        | Numeric   | predict(model_final, newdata = model_data, type = "response"): P(group_binary = 1 \| covariates). NA when a covariate used in the model is missing | [0, 1]           |
| include_after_trimming | indicator variable; whether this individual is selected into the weighted analysis                                                | p_score, ps_trim_bounds              |           | x        | Logical   | IF ps_trim_bounds given: TRUE if p_score is non-missing AND >= lower AND <= upper, else FALSE.<br />If no trimming (default, ps_trim_bounds is ~): TRUE where p_score is non-missing | TRUE, FALSE      |
| raw_iptw               | Inverse probability of treatment weights (raw/untruncated). Computed according to protocol (ATE weights)                          | p_score, group_binary                |           | x        | Numeric   | IF group_binary == 1 THEN 1 / p_score ELSE 1 / (1 - p_score)                                                                       | > 0              |
| stabilized_iptw        | Stabilized version of `raw_iptw` (multiply by marginal probability of being assigned to the group you are assigned to)            | raw_iptw, group_binary               |           | x        | Numeric   | IF group_binary == 1 THEN P(A=1) * raw_iptw ELSE P(A=0) * raw_iptw, with P(A) the proportion of the group in the population where include_after_trimming == TRUE | > 0              |
| stabilized_trunc_iptw  | Truncated stabilized IPTW (truncated at 1st and 99th percentile)                                                                  | stabilized_iptw                      |           | x        | Numeric   | Per group: values below 1st percentile set to P1; values above 99th percentile set to P99. Percentiles computed within each group. | > 0              |

## Processing Steps

iptw estimation:

1. Extract predicted probabilities of exposed group membership from the model
2. If trimming of propensity score required, input lower and upper bound of propensity score values (provided by metadata/global parameter). If supplied, select only units who have `p_score` within the trimming bounds, record in `include_after_trimming` who meets these criteria
3. Compute raw IPT weights from `p_score` for individuals with `include_after_trimming == TRUE`. IPTW-ATE weights given by `A*(1/p_score) + (1-A)*(1/1-p_score)`.
4. Compute stabilized IPT weights using the marginal probability of the treatment actually received, by `A*(sum(A == 1)/N) * iptw_raw + (1-A)*(sum(A == 0)/N)*iptw_raw`, where `N` is the number of individuals with `include_after_trimming == TRUE`
5. Calculate truncated stabilized IPT weights; compute 1st and 99th percentile; all values lower than 1st percentile get set to 1st percentile, all values higher than 99th percentile get set to 99th percentile.

## Example

| person_id | match_id | T0         | group   | group_binary | p_score | include_after_trimming | raw_iptw | stabilized_iptw | stabilized_trunc_iptw |
| --------- | -------- | ---------- | ------- | ------------ | ------- | ---------------------- | -------- | --------------- | --------------------- |
| 1         | NA       | 2023-02-01 | CONTROL | 0            | 0.42    | TRUE                   | 1.72     | 1.03            | 1.03                  |
| 2         | NA       | 2023-02-15 | EXPOSED | 1            | 0.78    | TRUE                   | 1.28     | 0.51            | 0.51                  |
| 5         | NA       | 2023-06-20 | CONTROL | 0            | 0.31    | TRUE                   | 1.45     | 0.87            | 0.87                  |
