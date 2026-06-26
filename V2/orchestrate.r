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

config <- fromJSON("config.json")

# TODO: UMEP the input TMY here
# TODO: Record tile boundaries during Retile to smooth reconstruction

# 1. Normalize
# rscript("V2/scripts/1-normalize.r")

# 2. Building Identification
# rscript("V2/scripts/2-buildings.r")


# 3. Orchestrate SEBE operation

tic("Tile Creation")

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

# Retile and create a subdirectory pattern to loop SEBE through
retile_dir <- fs::path(config$scratch_dir, "SEBE")
opt_output_files(ctg) <- paste0(retile_dir, "/{ID}/retile_{ID}")
newctg <- catalog_retile(ctg)

toc()

tic("SEBE Stuff")

logs_dir <- fs::path(config$scratch_dir, "Logs", "4-sebe_orchestrator")
dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

# Prep parallelization
plan(multisession, workers = 21)

# Loop through the subdirectories creating SEBE inputs
tiles <- list.files(retile_dir, full.name = TRUE)
future_map(tiles, \(tile) {
  tile_no <- basename(tile)
  rscript("V2/scripts/3-sebe_input.r", cmdargs = c(tile)) 


  rscript(
    "V2/scripts/4-sebe_orchestrator.r",
    cmdargs = c(tile),
    stdout = fs::path(logs_dir, tile_no, ext = "log"),
    stderr = "2>&1"
  )
})

# Tear down parallelization
plan(sequential)

toc()

quit()

# 5. Stitch together the results
rscript("V2/scripts/5-harmonize.r")

# 6. Suitability analysis
rscript("V2/scripts/6-suitability_analysis.r")

# 7. Group rooftops
rscript("V2/scripts/7-group_rooftops.r")
