library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(callr)
library(fs)
library(stringr)
library(future)
library(furrr)
library(tictoc)
library(logger)


source("src/utils.r")
init_logging("orchestrate.r")

# Record session
# log_info(sessionInfo())

# 1. Generate topographic datasets
# rscript("V2/scripts/1-topography.r")

# 2. Building Identification
# rscript("V2/scripts/2-buildings.r")

# 3. Orchestrate SEBE operation

# Read in LiDAR
ctg <- readLAScatalog(
  config$input_dir,
  recursive = TRUE,
  pattern = "*.copc.laz" # TODO: Convert to *.copc.las
)

# Update catalog config
st_crs(ctg) <- config$crs
opt_chunk_size(ctg) <- config$chunk_size
opt_chunk_buffer(ctg) <- config$chunk_buffer
opt_laz_compression(ctg) <- TRUE

# Retile and create a subdirectory pattern to loop SEBE through
retile_dir <- path(config$scratch_dir, "SEBE")
# opt_output_files(ctg) <- paste0(retile_dir, "/{XLEFT}_{XRIGHT}_{YBOTTOM}_{YTOP}/tile")
# newctg <- catalog_retile(ctg)

tic("Solar Radiation Modelling")
plan(multisession, workers = config$workers)

log_info("Beginning solar radiation modelling")

logs_dir <- path(config$scratch_dir, "Logs", "4-sebe_orchestrator")
dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

# Loop through the subdirectories creating SEBE inputs
tiles <- list.files(retile_dir, full.name = TRUE)
future_map(tiles, \(tile) {
  tile_no <- basename(tile)
  rscript(
    "src/scripts/4-sebe_orchestrator.r",
    cmdargs = c(tile)#,
    #stdout = fs::path(logs_dir, tile_no, ext = "log"),
    #stderr = "2>&1"
  )
})

plan(sequential)
toc()

quit()

# 5. Stitch together the results
rscript("V2/scripts/5-harmonize.r")

# 6. Suitability analysis
rscript("V2/scripts/6-suitability_analysis.r")

# 7. Group rooftops
rscript("V2/scripts/7-group_rooftops.r")
