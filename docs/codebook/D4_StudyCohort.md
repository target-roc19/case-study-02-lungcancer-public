## Metadata

| Table name                | D4_StudyCohort                                                                                                                                                               |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description               | Selected study cohort of eligible individuals                                                                                                                                |
| Source                    | D3_ELIGIBILITY                                                                                                                                                               |
| Step                      | transformations/T3_study_design/source_code/create_studycohort.R                                                                                                             |
| Content                   | Definition of the exposed and control units for the study cohort. Selects all eligible individuals and keeps, per person, the **first** eligible spell (first-line treatment, regardless of later switching).<br />Including person identifiers, group assignment, and time-zero (T0). |
| Population                | Eligible person(-spells) where eligible_exposed == TRUE or eligible_control == TRUE                                                                                          |
| Unit of Observation (UoO) | One row per person: the first eligible spell in which the person is selected as exposed or control.                                                                          |

## Codebook

| variable_in_output | variable(s) needed                                               | retrieved | computed | format    | rule_of_calculation                                                                | description                                                                                                                                                                                           | vocabulary |
| ------------------ | ---------------------------------------------------------------- | --------- | -------- | --------- | ---------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| person_id          | D3_ELIGIBILITY/person_id                                         | x         |          | character | person_id of a spell where eligible_exposed == TRUE OR eligible_control == TRUE    | person_id                                                                                                                                                                                             |            |
| T0                 | D3_ELIGIBILITY/start_episode                                     |           | x        | date      | start_episode of the first (earliest) eligible spell of the person                 | time-zero (moment at which eligibility is assessed, group assigned and follow up starts) - moment of initiation of exposure treatment (nivolumab + ipilimumab) or control treatment (pembrolizumab)   |            |
| group              | D3_ELIGIBILITY/eligible_exposed, D3_ELIGIBILITY/eligible_control |           | x        | character | if eligible_exposed == TRUE -> "EXPOSED" ELSE "CONTROL". Evaluated on the first eligible spell, so a spell that is both exposed and control resolves to EXPOSED | EXPOSED or CONTROL.                                                                                                                                                                                   | EXPOSED, CONTROL |
| start              | D3_ELIGIBILITY/start_episode                                     | x         |          | Date      |                                                                                    | start date of the eligible episode (equal to T0)                                                                                                                                                      |            |
| end                | D3_ELIGIBILITY/end_episode                                       | x         |          | Date      |                                                                                    | end date of the eligible episode                                                                                                                                                                      |            |

## Example

Below eligible EXPOSED or CONTROL individuals selected from D3_ELIGIBILITY.

| person_id | T0         | group   | start      | end        |
| --------- | ---------- | ------- | ---------- | ---------- |
| 1         | 2023-02-01 | CONTROL | 2023-02-01 | 2023-02-01 |
| 2         | 2023-02-15 | EXPOSED | 2023-02-15 | 2023-02-15 |
