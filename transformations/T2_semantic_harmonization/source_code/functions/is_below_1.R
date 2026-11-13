#' Create a new complex concept by applying a threshold (< 1) to an existing
#'  sub-concept partition in a Hive-style directory structure.
#'
#'  The sub-concept is expected to contain numeric values in the `value`
#'  column. Rows with value < 1 are assigned TRUE; all other rows FALSE.
#'
#' @param input_dir Input directory containing partitioned parquet files.
#' @param output_dir Output directory where the new partition will be written.
#' @param complex_concept_name Name of the new complex concept
#'  to create (used as partition value).
#' @param sub_concept_ids Character vector of sub_concept_ids to include
#'  (expected to be a single numeric sub-concept).
#'
#' @returns Invisibly returns a list summarizing the operation,
#'  including matched partitions and output path.
is_below_1 <- function(
    input_dir,
    output_dir,
    complex_concept_name = NULL,
    sub_concept_ids = NULL) {
  # Normalise inputs
  params <- normalise_inputs(
    input_dir = input_dir,
    output_dir = output_dir,
    complex_concept_name = complex_concept_name,
    sub_concept_ids = sub_concept_ids
  )
  # Validate inputs
  validate_inputs(
    input_dir = params$input_dir,
    complex_concept_name = params$complex_concept_name,
    sub_concept_ids = params$sub_concept_ids
  )
  # Clean output directory
  ensure_clean_output_directory(params$output_dir, params$complex_concept_name)

  # Getting existing sub_concept_ids
  existing_sub_concepts <- prepare_sub_concept_ids(
    sub_concept_ids = params$sub_concept_ids,
    input_directory = params$input_dir
  )

  # Open DuckDB connection
  con <- duckdb::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(duckdb::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  concept_id_list <- paste0("'", existing_sub_concepts, "'", collapse = ", ")

  # Threshold: value < 1 -> TRUE, else -> FALSE
  DBI::dbExecute(
    con,
    glue::glue(
      "CREATE OR REPLACE VIEW {params$complex_concept_name} AS
        SELECT
          unique_id,
          ori_table,
          person_id,
          CASE WHEN CAST(value AS DOUBLE) < 1 THEN TRUE ELSE FALSE END AS value,
          date,
          '{params$complex_concept_name}' AS concept_id
        FROM read_parquet(
          ['{params$input_dir}/**/*.parquet'],
          hive_partitioning = true,
          union_by_name     = true
        )
        WHERE concept_id IN ({concept_id_list})"
    )
  )

  tryCatch(
    {
      DBI::dbExecute(
        con,
        glue::glue(
          "COPY (
            SELECT * FROM {params$complex_concept_name}
          ) TO '{params$output_dir}'
          (FORMAT PARQUET, PARTITION_BY (concept_id), APPEND)"
        )
      )
    },
    error = function(e) {
      rlang::abort(
        glue::glue(
          "DuckDB COPY failed for '{params$complex_concept_name}': {conditionMessage(e)}"
        ),
        class = "duckdb_copy_error"
      )
    }
  )

  # Checking rows affected
  counts <- get_counts(
    connection = con,
    complex_concept_name = params$complex_concept_name,
    output_directory = params$output_dir
  )
  logger::log_info(crayon::cyan(
    "Counts:\n",
    paste(capture.output(print(t(counts), sep = ":"))[-1], collapse = "\n")
  ))
}
