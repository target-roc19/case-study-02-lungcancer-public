## Metadata

| Table name                | D4_STUDYVARIABLES_ANCHORED                                                                                                                                                                                                    |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description               | For every person in the study cohort and every anchored study variable, the single concept record selected from the look-back window around T0. Sparse long format: when no record is found in the window, no row is written. |
| Source                    | D3_CONCEPTS; D4_StudyCohort; combined_anchor_metadata.csv (generated from RWE-BRIDGE study_variables.csv)                                                                                                                     |
| Step                      | transformations/T3_study_design/source_code/anchor_studyvariables.R (anchoR::anchor_by_variable)                                                                                                                              |
| Content                   | The selected record per person, T0 and study variable, in long format                                                                                                                                                         |
| Population                | The unique person_id and T0 combinations in D4_StudyCohort                                                                                                                                                                    |
| Unit of Observation (UoO) | One row per person, T0 and variable_id                                                                                                                                                                                        |
| File format               | Hive-partitioned parquet (`data/D4_analytic_datasets/D4_STUDYVARIABLES_ANCHORED_parquet/variable_id=<variable_id>/`)                                                                                                          |

## Codebook

| variable_in_output | variable(s) needed                        | retrieved | computed | format    | rule_of_calculation                                                                      | description                                | vocabulary                            |
| ------------------ | ----------------------------------------- | --------- | -------- | --------- | ---------------------------------------------------------------------------------------- | ------------------------------------------ | ------------------------------------- |
| anchor_row_id      |                                           |           | x        | Integer   | row number of the person/T0 combination in the anchor population                         | identifier of the anchored unit            |                                       |
| person_id          | D4_StudyCohort:person_id                  | x         |          | Integer   |                                                                                          | key identifier                             |                                       |
| T0                 | D4_StudyCohort:T0                         | x         |          | Date      |                                                                                          | anchor date; time-zero of the study cohort |                                       |
| window_name        | combined_anchor_metadata.csv::window_name | x         |          | Character |                                                                                          | name of the look-back window               | covariate                             |
| value              | D3_CONCEPTS:value                         |           | x        | Character | value of the record picked by the selector; the number of records for the COUNT selector | value of the study variable at T0          |                                       |
| date               | D3_CONCEPTS:date                          |           | x        | Date      | date of the record picked by the selector                                                | date of the selected record                |                                       |
| n                  | D3_CONCEPTS                               |           | x        | Integer   | number of records found in the window                                                    | how many records the selector chose from   |                                       |
| variable_id        | combined_anchor_metadata.csv::variable_id |           | x        | Character | hive partition key                                                                       | study variable the row belongs to          | the combined_anchor_metadata.csv rows |

## Processing Steps

1. `combine_metadata()` turns `study_variables.csv` into the anchor metadata: it drops eligibility-only and outcome rows, sets `window_name` to `covariate` and `constructor` to `GENERIC`, renames the look-back columns to `start_offset` / `end_offset`, and drops variables whose selector `anchoR` does not support. The result is written to `transformations/T3_study_design/configuration/combined_anchor_metadata.csv`.
2. The anchor population is the unique `person_id` and `T0` combinations of D4_StudyCohort.
3. For each metadata row and each unit, the window is `[T0 + start_offset, T0 + end_offset]` (constructor `GENERIC`). The records of `concept_id` inside that window are collapsed with the selector: `LATEST` and `EARLIEST` take the last and first record in time, `COUNT` returns the number of records.
4. When no record is found in the window, no row is written. Missing values are filled in later, when the wide covariate table is built; see [D4_StudyCohort_Covariates](D4_StudyCohort_Covariates.md).

## Example

| anchor_row_id | person_id | T0         | window_name | value | date       | n | variable_id        |
| ------------- | --------- | ---------- | ----------- | ----- | ---------- | - | ------------------ |
| 1             | 1         | 2023-02-01 | covariate   | true  | 2023-01-14 | 1 | SV_METASTASIS_CNS  |
| 1             | 1         | 2023-02-01 | covariate   | ADENO | 2023-01-08 | 2 | SV_NSCLC_HISTOLOGY |
| 2             | 2         | 2023-02-15 | covariate   | 1     | 2023-02-02 | 1 | SV_ECOG_STATUS     |
