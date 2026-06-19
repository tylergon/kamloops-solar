library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(callr)
library(fs)
library(stringr)
library(future)

config <- fromJSON("config.json")

# TODO: UMEP the input TMY here

# 1. Normalize

# Switch to parallel?

# rscript("V2/scripts/1-normalize.r")

# 2. Building Identification

# rscript("V2/scripts/2-buildings.r")

# ---

# 3. Orchestrate SEBE operation

# Read in relevant LAS data
ctg <- readLAScatalog(
  config$input_dir,
  recursive = TRUE,
  pattern = "*.las" # TODO: Convert to *.copc.las
)

# Configuration

st_crs(ctg) <- config$crs

opt_chunk_size(ctg) <- config$chunk_size
opt_chunk_buffer(ctg) <- config$chunk_buffer

# Retile and create a subdirectory pattern to loop SEBE through

retile_dir <- fs::path(config$scratch_dir, "SEBE")

# opt_output_files(ctg) <- paste0(retile_dir, "/{ID}/retile_{ID}")
# newctg <- catalog_retile(ctg)

# TODO: Record boundaries

# Loop through the subdirectories creating SEBE inputs

tiles <- list.files(retile_dir, full.name = TRUE)




for (tile in list.files(retile_dir)) {
  wd <- path_abs(str_glue("{retile_dir}/{tile}"))
  rscript("V2/scripts/3-sebe_input.r", cmdargs = c(wd))
}

# 4. SEBE

# TODO: Parallelize...
for (tile in list.files(retile_dir)) {
  wd <- path_abs(str_glue("{retile_dir}/{tile}"))
  # rscript("V2/scripts/4-sebe_orchestrator.r", cmdargs = c(wd))
}

# 5. Stitch together the results

rscript("V2/scripts/5-harmonize.r")

# 6. Suitability analysis

rscript("V2/scripts/6-suitability_analysis.r")
