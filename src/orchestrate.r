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
tic("Topography")
rscript("src/scripts/1-topography.r")

toc(log = TRUE)
log_info(tic.log())
tic.clearlog()


# 2. Building Identification
tic("Buildings")
rscript("src/scripts/2-buildings.r")

toc(log = TRUE)
log_info(tic.log())
tic.clearlog()

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
opt_output_files(ctg) <- paste0(retile_dir, "/{XLEFT}_{XRIGHT}_{YBOTTOM}_{YTOP}/tile")
newctg <- catalog_retile(ctg)

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
    "src/scripts/3-solar_modelling.r",
    cmdargs = c(tile)#,
    #stdout = fs::path(logs_dir, tile_no, ext = "log"),
    #stderr = "2>&1"
  )
})

plan(sequential)

toc(log = TRUE)
log_info(tic.log())
tic.clearlog()

# 5. Stitch together the results
tic("Hamronize")

rscript("src/scripts/4-harmonize.r")

toc(log = TRUE)
log_info(tic.log())
tic.clearlog()


tic("Segmentation")

rscript("src/scripts/5-segment.r")

toc(log = TRUE)
log_info(tic.log())
tic.clearlog()


# 6. Suitability analysis
tic("Suitability")

rscript("src/scripts/6-suitability_analysis.r")

toc(log = TRUE)
log_info(tic.log())
tic.clearlog()

# 7. Group rooftops
# rscript("src/scripts/7-group_rooftops.r")
