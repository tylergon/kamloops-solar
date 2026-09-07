library(fs)
library(callr)
library(jsonlite)
library(future)
library(furrr)
library(purrr)
library(dplyr)
library(stringr)
library(progressr)
source("src/utils.r")

start <- Sys.time()
sebe_dir <- path(config$scratch_dir, "SEBE")

# Get current status and remaining tiles
all_tiles <- list.files(sebe_dir)
existing_outputs <- list.files(sebe_dir, pattern = "Energyyearroof.tif", recursive = TRUE) |>
    str_extract("\\d+_\\d+")
remaining <- setdiff(all_tiles, existing_outputs)

# Initialize logging
init_logging("track_sebe.r")
log_info(paste0("Processing skipped tiles"))
log_info(paste0("Workers: ", config$workers))
log_info(paste0(length(remaining), " files remain (", round(length(remaining) / length(all_tiles) * 100), "%)"))

# Spin up parallelization
plan(multisession, workers = config$workers)

# Loop through tiles
tiles <- path(sebe_dir, remaining)
with_progress({
    p <- progressor(steps = len(remaining))
    result_df <- future_map_dfr(tiles, \(tile) {
        is_success <- FALSE
        init_logging("track_sebe.r")
        tryCatch(
        {
            rscript("src/scripts/3-solar_modelling.r", cmdargs = c(tile), fail_on_status = TRUE)
            log_success(paste0(basename(tile), " - Complete"))
            is_success <- TRUE
        },
        error = \(e) log_error(paste0(basename(tile), " - Failed"))
        )
        p(message = basename(tile))
        tibble(tile = basename(tile), is_success)
    })
})

failed <- result_df |> filter(!is_success)
if (nrow(failed) > 0) {
    message(nrow(failed), " tile(s) failed: ", paste(failed$tile, collapse = ", "))
    log_error(paste0(nrow(failed), " tile(s) failed: ", paste(failed$tile, collapse = ", ")))
}
