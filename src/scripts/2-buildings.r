library(stringr)
library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(fs)

config <- read_json("config.json")

# Read in the normalized point cloud
norm_path <- paste0(config$scratch_dir, "/normalized/")
ctg_norm <- readLAScatalog(norm_path)

# Grid up the data
opt_chunk_size(ctg_norm) <- config$chunk_size
opt_chunk_buffer(ctg_norm) <- config$chunk_buffer

# Adjust catalogue configuration
ctg_norm@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Filter down to buildings & points above 2m
opt_filter(ctg_norm) <- "-keep_class 6 -drop_z_below 2.5"

# Rasterize "building" points
rooftops <- rasterize_canopy(
  ctg_norm,
  config$spatial_resolution,
  algorithm = p2r(0.2)
)

# Perform a 2-step buffer to remove thin channels of pixels
is_bldg <- !is.na(rooftops) & (rooftops > 0)
is_bldg_shrunk <- focal(is_bldg, w = 3, fun = "min")
is_bldg_buff <- focal(is_bldg_shrunk, w = 3, fun = "max")

# Write output
writeRaster(is_bldg_buff, fs::path(config$output_dir, "buildings.tif"), overwrite = T)
