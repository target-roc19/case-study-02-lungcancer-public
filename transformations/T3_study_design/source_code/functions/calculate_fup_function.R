#' Compute D4_StudyCohort_FUP from D4_StudyCohort + D3_PERSONS.
#'
#' Based on codebook:
#'   general_end_fup = min(date_death, end_study_period,
#'                         end_of_data_collection, max_fup_date)
#'   reason_censoring hierarchy:
#'     Death > End of max follow-up > End of data collection > End of study period
#'   fup_length_days = general_end_fup - T0 + 1
#'   fup_length_pyr  = fup_length_days / 365.25
#'   event_death     = as.integer(reason_censoring == "Death")
#'
#' @param d4_studycohort data.table -- columns person_id, T0, group.
#' @param d3_persons data.table -- columns person_id, death_date (Date).
#' @param end_study_date Date  (e.g. config_values$end_study_date).
#' @param end_of_data_collection_date Date; default to end_study_date
#'   when not provided.
#' @param max_fup_days integer; default 1491.
calculate_fup <- function(
  d4_studycohort,
  d3_persons,
  end_study_date,
  end_of_data_collection_date = end_study_date,
  max_fup_days = 1491L
) {
  data.table::setDT(d4_studycohort)
  data.table::setDT(d3_persons)

  dt <- d4_studycohort[, .(
    person_id = as.character(person_id),
    T0 = as.Date(T0),
    group
  )]

  persons <- d3_persons[, .(
    person_id = as.character(person_id),
    date_death = as.Date(death_date)
  )]
  dt <- persons[dt, on = "person_id"]

  dt[, end_study_period := as.Date(end_study_date)]
  dt[, end_of_data_collection := as.Date(end_of_data_collection_date)]
  dt[, max_fup_date := T0 + as.integer(max_fup_days)]

  dt[,
    general_end_fup := pmin(
      data.table::fifelse(is.na(date_death), as.Date(NA), date_death),
      end_study_period,
      end_of_data_collection,
      max_fup_date,
      na.rm = TRUE
    )
  ]

  dt[,
    reason_censoring := data.table::fcase(
      !is.na(date_death) & general_end_fup == date_death , "Death"                  ,
      general_end_fup == max_fup_date                    , "End of max follow-up"   ,
      general_end_fup == end_of_data_collection          , "End of data collection" ,
      general_end_fup == end_study_period                , "End of study period"
    )
  ]

  dt[, fup_length_days := as.integer(general_end_fup - T0 + 1L)]
  dt[, fup_length_pyr := fup_length_days / 365.25]
  dt[, event_death := as.integer(reason_censoring == "Death")]

  dt[, .(
    person_id,
    T0,
    group,
    end_study_period,
    end_of_data_collection,
    date_death,
    max_fup_date,
    general_end_fup,
    reason_censoring,
    fup_length_days,
    fup_length_pyr,
    event_death
  )]
}
