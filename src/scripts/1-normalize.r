library(sf)
library(terra)
library(lidR)

source("src/utils.r")
init_logging("normalization")

# Create a catalogue for our point cloud data
ctg <- readLAScatalog(
  config$input_dir,
  recursive = TRUE,
  pattern = "*.copc.laz"
)

st_crs(ctg) <- 26910

# Configure chunking
opt_chunk_size(ctg) <- config$chunk_size
opt_chunk_buffer(ctg) <- config$chunk_buffer

log_info("Generating DEM")

# Generate a DEM of the study area
dem <- rasterize_terrain(
  ctg,
  config$spatial_resolution,
  tin()
)

log_info("Writing DEM")

# Save the DEM
dem_path <- fs::path(config$output_dir, "dem.tif")
writeRaster(dem, dem_path, overwrite = TRUE)

# Set up the output for the normalized point clouds
opt_output_files(ctg) <- fs::path(config$scratch_dir, "normalized/norm_{ID}")
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE

log_info("Normalizing point cloud")

# Normalize the point cloud
normalize_height(ctg, dem)

log_info("Complete")
