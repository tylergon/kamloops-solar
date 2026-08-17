library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(callr)
library(fs)
library(stringr)
library(future)
library(furrr)
library(purrr)
library(tictoc)
library(logger)
library(dplyr)

source("src/utils.r")
init_logging("orchestrate.r")

# Record session
# log_info(sessionInfo())

# # Generate topographic datasets
rscript("src/scripts/1-topography.r")

# # Building Identification
rscript("src/scripts/2-buildings.r")


# Orchestrate solar radiation modelling

retile_dir <- path(config$scratch_dir, "SEBE")

# Retiling LiDAR to align solar modelling tiling w/ lidR outputs
if (FALSE) {
  # Read in LiDAR
  ctg <- readLAScatalog(
    config$input_dir,
    recursive = TRUE,
    pattern = "*.copc.laz"
  )

  # Update catalog config
  st_crs(ctg) <- config$crs
  opt_chunk_size(ctg) <- config$chunk_size
  opt_chunk_buffer(ctg) <- config$chunk_buffer
  opt_laz_compression(ctg) <- TRUE

  # Perform retile
  opt_output_files(ctg) <- path(retile_dir, "{XLEFT}_{YBOTTOM}", "tile")
  catalog_retile(ctg)
}


# Spin up parallelization
plan(multisession, workers = config$workers)
log_info("Beginning solar radiation modelling")

# Loop through tiles
tiles <- list.files(retile_dir, full.name = TRUE)
results <- future_map(tiles, \(tile) {
  init_logging(basename(tile), "3-solar_modelling")

  # Attempt to perform solar modelling
  is_success <- FALSE
  tryCatch(
    {
      log_info("ORCHESTRATION - Initializing")
      rscript("src/scripts/3-solar_modelling.r", cmdargs = c(tile), fail_on_status = TRUE)
      log_success("ORCHESTRATION - Complete")
      is_success <- TRUE
    },
    error = \(e) {
      log_error(skip_formatter(paste0("Condition: ", conditionMessage(e))))
      log_error(skip_formatter(paste0("stdout: ", e$stdout)))
      log_error(skip_formatter(paste0("stderr: ", e$stderr)))
    }
  )

  tibble(tile = basename(tile), is_success)
}) |> list_rbind()

plan(sequential)

results[results$is_success,] |> pwalk(\(tile, is_success) log_success("[{tile}] Solar modelling complete"))
results[!results$is_success,] |> pwalk(\(tile, is_success) log_error("[{tile}] Solar modelling failed"))

# 5. Stitch together the results
rscript("src/scripts/4-harmonize.r")

# 5. Segment individual rooftops
# TODO: Move to be adjacent to rooftop identification
rscript("src/scripts/5-segment.r")

# 6. Suitability analysis
rscript("src/scripts/6-suitability_analysis.r")

# 7. Group rooftops
# rscript("src/scripts/7-group_rooftops.r")
