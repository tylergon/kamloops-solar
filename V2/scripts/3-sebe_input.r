library(tidyverse)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

config <- read_json("config.json")


# ~~ 1. Building & Ground DSM ~~

ctg <- readLAScatalog(
  config$input_dir,
  recursive = TRUE,
  pattern = "*.copc.laz"
)

# TODO: Switch this out for proper operations
opt_chunk_size(ctg_norm) <- config$chunk_size
opt_chunk_buffer(ctg_norm) <- config$chunk_buffer

# Update configuration
st_crs(ctg) <- 26910
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Filter down to building & ground points
opt_filter(ctg) <- "-keep_class 2 6"

# Generate a DSM using the filtered point cloud
dsm <- rasterize_canopy(
  ctg, config$spatial_resolution,
  algorithm = p2r(0.2, na.fill = tin())
)

# Fill in NA values
w <- 1
while (global(dsm, function(x) any(is.na(x)))[, 1]) {
  w <- w + 2
  dsm <- focal(
    dsm,
    w = w, fun = mean, na.policy = "only", na.rm = TRUE
  )
}

writeRaster(
  dsm,
  paste0(config$scratch_dir, "/dsm.tif"),
  overwrite = TRUE
)


# ~~ 2. Canopy Height Model ~~


norm_path <- paste0(config$scratch_dir, "/normalized/")
ctg_norm <- readLAScatalog(norm_path)

ctg_norm@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# TODO: Update this
opt_chunk_size(ctg_norm) <- config$chunk_size
opt_chunk_buffer(ctg_norm) <- config$chunk_buffer

# Filter down to only vegetation classes (above 1m)
opt_filter(ctg_norm) <- "-keep_class 3 5 -drop_z_below 1"

# Create a DSM of just the vegetation layer & write it out
chm <- rasterize_canopy(ctg_norm, res = config$spatial_resolution, p2r(0.2)) %>%
  replace(is.na(.), 0)

writeRaster(
  chm,
  paste0(config$scratch_dir, "/chm.tif"),
  overwrite = TRUE
)
