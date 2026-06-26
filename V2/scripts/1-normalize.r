library(stringr)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

config <- read_json("config.json")

# Create a catalogue for our point cloud data
ctg <- readLAScatalog(
  config$input_dir,
  recursive = TRUE,
  pattern = "*.copc.laz" # TODO: Convert to copc
)

st_crs(ctg) <- 26910

# Configure chunking
# TODO: Chunk alignment?
opt_chunk_size(ctg) <- config$chunk_size
opt_chunk_buffer(ctg) <- config$chunk_buffer

# Generate a DEM of the study area
dem <- rasterize_terrain(
  ctg,
  config$spatial_resolution,
  tin()
)

# Save the DEM - is this necessary / should it be chunked?
dem_path <- paste(config$output_dir, "dem.tif", sep = "/")
message(str_glue(">>> OUTPUT DEM @ {dem_path}"))
writeRaster(dem, dem_path, overwrite = TRUE)

# Set up the output for the normalized point clouds
opt_output_files(ctg) <- paste0(config$scratch_dir, "/normalized/norm_{ID}")
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Normalize the point cloud
normalize_height(ctg, dem)
