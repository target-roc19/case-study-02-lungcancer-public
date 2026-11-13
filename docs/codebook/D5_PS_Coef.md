## Metadata

| Table name                | D5_PS_Coef                                                                                                                                                                                               |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description               | List of point estimates and standard errors of coefficients for the final propensity score model.<br />Key output of the glm() used to fit the ps model, but can be saved without also sharing data etc. |
| Source                    | `D4_StudyCohort_Covariates`; configuration/`psmodel_variables.csv`                                                                                                                                       |
| Step                      | `transformations/T3_study_design/source_code/compute_d4_StudyCohort_IPTW.R`; written as `<DEAP>_D5_PS_Coef.csv` in data/D5_results                                                                       |
| Content                   | Coefficients, standard errors, test statistics, and odds ratios from the final propensity model fit                                                                                                      |
| Population                | Study cohort used to fit the final propensity score model                                                                                                                                                |
| Unit of Observation (UoO) | model terms (one row per coefficient, including intercept and each dummy level for categorical vars)                                                                                                     |

## Codebook

| Variable name | Description                                                         | Format                            | Vocabulary | Variables from source used for the variable | Principles for coding |
| ------------- | ------------------------------------------------------------------- | --------------------------------- | ---------- | ------------------------------------------- | --------------------- |
| coefficient   | Model term: `<variable><category_value>` for CAT/TF variables (the reference category from psmodel_variables.csv is absorbed), the bare variable name for NUM variables, plus `(Intercept)` | Character                         |            | psmodel_variables.csv::var, reference_category |                       |
| estimate      | Point estimate of the coefficient                                   | Numeric                           |            |                                             |                       |
| std_error     | Standard error                                                      | Numeric                           |            |                                             |                       |
| z_score       | z value for significance test                                       | Numeric                           |            |                                             |                       |
| p_value       | P-value for significance test                                       | Numeric                           | [0, 1]     |                                             |                       |
| exp_estimate  | exponential of the `estimate` column, representing the odds ratio | Numeric                           | > 0        |                                             |                       |

## Processing Steps

1. Fit the final propensity score model (after any variable exclusions)
2. Extract coefficient table from `summary(model_fit)$coefficients`

## Example

Example coefficients from a hypothetical final PS model fit, using the term names produced by the variables in `psmodel_variables.csv`.

| coefficient                | estimate | std_error | z_score | p_value | exp_estimate |
| -------------------------- | -------- | --------- | ------- | ------- | ------------ |
| (Intercept)                | -1.20    | 0.45      | -2.67   | 0.008   | 0.30         |
| SV_AGE_CAT65-75            | 0.15     | 0.18      | 0.83    | 0.406   | 1.16         |
| SV_AGE_CAT>75              | 0.32     | 0.22      | 1.45    | 0.147   | 1.38         |
| SV_SEXF                    | -0.35    | 0.18      | -1.94   | 0.052   | 0.70         |
| SV_NSCLC_HISTOLOGYSQUAMOUS | 0.41     | 0.22      | 1.86    | 0.063   | 1.51         |
| SV_NSCLC_HISTOLOGYOTHER    | -0.15    | 0.30      | -0.50   | 0.617   | 0.86         |
| SV_METASTASIS_LIVERTRUE    | 0.28     | 0.20      | 1.40    | 0.162   | 1.32         |
| SV_CNS_MET_RTCNS_NO_RT     | 0.53     | 0.25      | 2.12    | 0.034   | 1.70         |
| SV_CNS_MET_RTCNS_WITH_RT   | 0.62     | 0.30      | 2.07    | 0.039   | 1.86         |
| SV_METASTASIS_BONETRUE     | 0.18     | 0.19      | 0.95    | 0.342   | 1.20         |
| SV_METASTASIS_COUNT        | 0.12     | 0.08      | 1.50    | 0.134   | 1.13         |
| SV_ECOG_STATUS1            | 0.30     | 0.17      | 1.76    | 0.078   | 1.35         |
