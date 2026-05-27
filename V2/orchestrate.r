library(tidyverse)
library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(callr)
library(fs)

config <- fromJSON("config.json")

# 1. Normalize

# Switch to parallel?

rscript("V2/scripts/1-normalize.r")

# 2. Building Identification

rscript("V2/scripts/2-buildings.r")

# ---

# 3. Orchestrate SEBE operation

# Read in relevant LAS data
ctg <- readLAScatalog(
  config$input_dir,
  recursive = TRUE,
  pattern = "*.copc.laz"
)

# Configuration
st_crs(ctg) <- 26910 # TODO: Don't hardcode

opt_chunk_size(ctg) <- config$chunk_size
opt_chunk_buffer(ctg) <- config$chunk_buffer
# TODO: opt_chunk_alignment(ctg) <- c(1000, 1000)


# Retile and create a subdirectory pattern to loop SEBE through
# TODO: Switch to XLEFT YBOTTOM (?)
retile_dir <- paste0(config$scratch_dir, "\\SEBE")
opt_output_files(ctg) <- paste0(retile_dir, "\\{ID}\\retile_{ID}")
newctg <- catalog_retile(ctg)

# Loop through the subdirectories creating SEBE inputs
for (tile in list.files(retile_dir)) {
  wd <- path_abs(str_glue("{retile_dir}\\{tile}"))
  rscript("V2/scripts/3-sebe_input.r", cmdargs = c(wd))
}

# 4. SEBE

for (tile in list.files(retile_dir)) {
  wd <- path_abs(str_glue("{retile_dir}\\{tile}"))
  rscript("V2/scripts/3-sebe_input.r", cmdargs = c(wd))
}

# 5. Suitability analysis
