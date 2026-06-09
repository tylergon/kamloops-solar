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
  algorithm = p2r(0.2) # Doesn't fill gaps between houses
)

# Perform a 2-step buffer to remove thin channels of pixels
is_bldg <- !is.na(rooftops) & (rooftops > 0)
is_bldg_shrunk <- focal(is_bldg, w = 3, fun = "min")
is_bldg_buff <- focal(is_bldg_shrunk, w = 3, fun = "max")

# Filter out non-building pixels
# is_bldg_buff[!is_bldg_buff] <- NA

# Write output
writeRaster(is_bldg_buff, fs::path(config$output_dir, "buildings.tif"), overwrite = T)

# Optional outputs
#writeRaster(is_bldg, fs::path(config$output_dir, "buildings-original.tif"), overwrite = T)
#writeRaster(is_bldg_shrunk, fs::path(config$output_dir, "buildings-temp.tif"), overwrite = T)


# ---- DEPRECATED POLYGON CODE ----

# Convert to sf polygons
# bldg_poly <- as.polygons(rooftops > 0) |>
#   st_as_sf() |>
#   st_cast("POLYGON")

# Filter out thin channels between buildings
# channel_buffer <- config$spatial_resolution
# bldg_fp <- bldg_poly |>
#   st_buffer(-1 * channel_buffer) |>
#   st_buffer(channel_buffer)

# Write results out
# st_write(
#   bldg_fp,
#   paste0(config$output_dir, "/buildings.gpkg"),
#   delete_dsn = TRUE
# )
