## Metadata

| Table name                | configuration/psmodel_variables.csv (semicolon-separated)                                            |
| ------------------------- | ---------------------------------------------------------------------------------------------------- |
| Description               | Configuration file specifying which covariates enter the propensity score model and how to code them |
| Source                    | Protocol Table 9 (pre-specified confounders for covariate adjustment)                                |
| Step                      | Manual -- maintained by researcher; read by transformations/T3_study_design/source_code/compute_d4_StudyCohort_IPTW.R |
| Content                   | One row per candidate covariate with variable type, reference category, label, and inclusion flag. The eight rows below are the full file |
| Population                | N/A (metadata, not patient-level)                                                                    |
| Unit of Observation (UoO) | covariate (one row per variable to be considered for the PS model)                                   |

## Codebook

| variable_in_output | format    | description                                                                                                             | vocabulary   |
| ------------------ | --------- | ----------------------------------------------------------------------------------------------------------------------- | ------------ |
| var                | Character | variable name -- must match a column name in D4_StudyCohort_Covariates                                                  |              |
| vartype            | Character | variable type, determines how the compute script prepares the variable for the model                                    | NUM, CAT, TF |
| reference_category | Character | reference level for CAT/TF variables (absorbed in dummy coding); NA for NUM variables. Applied with relevel(), and silently ignored if the value is not an observed level |              |
| label              | Character | human-readable label used in diagnostic tables and plots. Kept in step with BaselineCharacteristics_metadata.csv        |              |
| force_in           | Logical   | if TRUE, variable is pre-specified by the protocol and should not be removed by data-driven selection; always TRUE here | TRUE, FALSE  |

## Example

The complete file as used in this study:

| var                 | vartype | reference_category | label                           | force_in |
| ------------------- | ------- | ------------------ | ------------------------------- | -------- |
| SV_AGE_CAT          | CAT     | <65                | Age category (years)            | TRUE     |
| SV_SEX              | CAT     | M                  | Sex                             | TRUE     |
| SV_NSCLC_HISTOLOGY  | CAT     | ADENO              | Histological subtype            | TRUE     |
| SV_METASTASIS_LIVER | TF      | FALSE              | Liver metastases                | TRUE     |
| SV_CNS_MET_RT       | CAT     | NO_CNS_MET         | CNS metastases and radiotherapy | TRUE     |
| SV_METASTASIS_BONE  | TF      | FALSE              | Bone metastases                 | TRUE     |
| SV_METASTASIS_COUNT | NUM     | NA                 | Number of metastatic sites      | TRUE     |
| SV_ECOG_STATUS      | CAT     | 0                  | ECOG performance status         | TRUE     |
