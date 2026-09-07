library(lidR)
library(sf)
library(terra)
library(fs)

source("src/utils.r")
init_logging("2-building_identification")


# Read in the normalized point cloud
norm_path <- path(config$scratch_dir, "normalized")
ctg_norm <- readLAScatalog(norm_path)

# Grid up the data
opt_chunk_size(ctg_norm) <- config$chunk_size
opt_chunk_buffer(ctg_norm) <- config$chunk_buffer

# Adjust catalogue configuration
ctg_norm@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Filter down to buildings & points above 2m
opt_filter(ctg_norm) <- "-keep_class 6 -drop_z_below 2.5"

log_info("Rasterizing building points")

# Rasterize "building" points
rooftops <- rasterize_canopy(
  ctg_norm,
  config$spatial_resolution,
  algorithm = p2r(0.2)
)

log_info("Filter channels")

# 2-step buffer removing thin channels of pixels
is_bldg <- !is.na(rooftops) & (rooftops > 0)
is_bldg_shrunk <- focal(is_bldg, w = 3, fun = "min")
is_bldg_buff <- focal(is_bldg_shrunk, w = 3, fun = "max")

log_info("Write out")

writeRaster(is_bldg_buff, path(config$output_dir, "buildings.tif"), overwrite = T)

log_info("Complete")
