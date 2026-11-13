## Metadata

| Table name                | D3_MULTIVARIATE_EPISODES                                                                                                                                         |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description               | The univariate episodes of all eligibility study variables combined into one time line per person: a new row starts whenever any of the variables changes value. |
| Source                    | D3_UNIVARIATE_EPISODES; D3_SPELLS; RWE-BRIDGE study_variables.csv                                                                                                |
| Step                      | transformations/T3_study_design/source_code/create_multivariate_episodes.R (episodeR::multivariate_episodes_pipeline)                                            |
| Content                   | One row per person and period, with one column per eligibility study variable                                                                                    |
| Population                | All persons in D3_SPELLS                                                                                                                                         |
| Unit of Observation (UoO) | Spell/Status; one or more rows per person (key: person_id, start_episode)                                                                                        |
| File format               | Parquet file (data/D3_study_variables/D3_MULTIVARIATE_EPISODES.parquet)                                                                                          |

## Codebook

| variable_in_output           | variable(s) needed                                              | retrieved | computed | format    | rule_of_calculation                                                                        | description                                    | vocabulary    |
| ---------------------------- | --------------------------------------------------------------- | --------- | -------- | --------- | ------------------------------------------------------------------------------------------ | ---------------------------------------------- | ------------- |
| person_id                    | D3_UNIVARIATE_EPISODES:person_id                                | x         |          | Integer   |                                                                                            | key identifier                                 |               |
| start_episode                | D3_UNIVARIATE_EPISODES:start_episode                            |           | x        | Date      | start of the period during which every study variable holds the same combination of values | start date of the episode                      |               |
| end_episode                  | D3_UNIVARIATE_EPISODES:end_episode                              |           | x        | Date      | end of that period                                                                         | end date of the episode                        |               |
| SV_AGE_18_OR_OLDER           | D3_UNIVARIATE_EPISODES/variable_id=SV_AGE_18_OR_OLDER           | x         |          | Boolean   | value of SV_AGE_18_OR_OLDER during the episode                                             | age of 18 years or older                       | TRUE, FALSE   |
| SV_CSTAGE4                   | D3_UNIVARIATE_EPISODES/variable_id=SV_CSTAGE4                   | x         |          | Boolean   | value of SV_CSTAGE4 during the episode                                                     | cancer diagnosis is stage 4 (IV)               | TRUE, FALSE   |
| SV_ECOG_STATUS               | D3_UNIVARIATE_EPISODES/variable_id=SV_ECOG_STATUS               | x         |          | Character | value of SV_ECOG_STATUS during the episode                                                 | latest ECOG performance status                 | 0, 1, 2, 3, 4 |
| SV_FIRST_NSCLC_DIAGNOSIS     | D3_UNIVARIATE_EPISODES/variable_id=SV_FIRST_NSCLC_DIAGNOSIS     | x         |          | Boolean   | value of SV_FIRST_NSCLC_DIAGNOSIS during the episode                                       | first NSCLC diagnosis in the previous 90 days  | TRUE, FALSE   |
| SV_MUTATION_ALK_ROS1_EGFR    | D3_UNIVARIATE_EPISODES/variable_id=SV_MUTATION_ALK_ROS1_EGFR    | x         |          | Boolean   | value of SV_MUTATION_ALK_ROS1_EGFR during the episode                                      | recorded EGFR, ALK or ROS1 mutation            | TRUE, FALSE   |
| SV_NIVOLUMAB_AND_IPILIMUMAB  | D3_UNIVARIATE_EPISODES/variable_id=SV_NIVOLUMAB_AND_IPILIMUMAB  | x         |          | Boolean   | value of SV_NIVOLUMAB_AND_IPILIMUMAB during the episode                                    | receives nivolumab and ipilimumab on this date | TRUE, FALSE   |
| SV_NSCLC_DIAGNOSIS           | D3_UNIVARIATE_EPISODES/variable_id=SV_NSCLC_DIAGNOSIS           | x         |          | Boolean   | value of SV_NSCLC_DIAGNOSIS during the episode                                             | has an NSCLC diagnosis                         | TRUE, FALSE   |
| SV_PDL_BELOW_1               | D3_UNIVARIATE_EPISODES/variable_id=SV_PDL_BELOW_1               | x         |          | Boolean   | value of SV_PDL_BELOW_1 during the episode                                                 | PD-L1 tumour expression < 1%                   | TRUE, FALSE   |
| SV_PEMBROLIZUMAB             | D3_UNIVARIATE_EPISODES/variable_id=SV_PEMBROLIZUMAB             | x         |          | Boolean   | value of SV_PEMBROLIZUMAB during the episode                                               | receives pembrolizumab on this date            | TRUE, FALSE   |
| SV_PREVIOUS_CANCER_DIAGNOSIS | D3_UNIVARIATE_EPISODES/variable_id=SV_PREVIOUS_CANCER_DIAGNOSIS | x         |          | Boolean   | value of SV_PREVIOUS_CANCER_DIAGNOSIS during the episode                                   | any non-NSCLC cancer diagnosis                 | TRUE, FALSE   |
| SV_RECEIVED_CT               | D3_UNIVARIATE_EPISODES/variable_id=SV_RECEIVED_CT               | x         |          | Boolean   | value of SV_RECEIVED_CT during the episode                                                 | chemotherapy initiated in the previous 28 days | TRUE, FALSE   |

## Processing Steps

1. Select the rows of `study_variables.csv` with `eligibility == TRUE`.
2. `episodeR::multivariate_episodes_pipeline` explodes the univariate episodes onto a shared time line per person, combines them, and merges consecutive periods that carry the same combination of values.

This table is the input of `calculate_eligibility.R`, which adds the eligibility flags; see [D3_ELIGIBILITY](D3_ELIGIBILITY.md).
