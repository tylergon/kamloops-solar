library(tidyverse)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

config <- read_json("config.json")

# Read in the normalized point cloud
norm_path <- paste0(config$scratch_dir, "/normalized/")
ctg_norm <- readLAScatalog(norm_path)

opt_chunk_size(ctg_norm) <- config$chunk_size
opt_chunk_buffer(ctg_norm) <- config$chunk_buffer


# TODO: Do we need to crop to our AOI?


# Adjust catalogue configuration
ctg_norm@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Filter down to buildings & points above 2m
opt_filter(ctg_norm) <- "-keep_class 6 -drop_z_below 2.5"

# Rasterize "building" points
rooftops <- rasterize_canopy(
  ctg_norm,
  config$spatial_resolution,
  algorithm = p2r(0.2) # Doesn't fill gaps between houses
)

# TODO: Perhaps keep as pixels for now -> This can be resolved when
#       we combine all of the tiles

# Convert to sf polygons
bldg_poly <- as.polygons(rooftops > 0) %>%
  st_as_sf() %>%
  st_cast("POLYGON")

# Filter out thin channels between buildings
channel_buffer <- config$spatial_resolution
bldg_fp <- bldg_poly %>%
  st_buffer(-1 * channel_buffer) %>%
  st_buffer(channel_buffer)

# Write results out
st_write(
  bldg_fp,
  paste0(config$output_dir, "/buildings.gpkg"),
  delete_dsn = TRUE
)
