library(sf)
library(terra)
library(lidR)
library(fs)
library(future)
library(future.apply)

source("src/utils.r")
init_logging("1-topography")

plan(multisession, workers = config$workers)

# Create a catalogue for our point cloud data
ctg <- readLAScatalog(config$input_dir, recursive = TRUE, pattern = "*.copc.laz")
st_crs(ctg) <- 26910
opt_chunk_size(ctg) <- config$chunk_size
opt_chunk_buffer(ctg) <- config$chunk_buffer
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE


##### DEM #####


# log_info("DEM: Generating")

# # Configure temporary storage
dem_ctg <- ctg
# opt_output_files(dem_ctg) <- path(config$scratch_dir, "dem/dem_{XLEFT}_{YBOTTOM}")

# # Generate DEM
# dem <- rasterize_terrain(dem_ctg, config$spatial_resolution, tin())

# log_info("DEM: Writing")

# dem_path <- path(config$output_dir, "dem.tif")
# writeRaster(dem, dem_path, overwrite = TRUE)

# log_success("DEM: Complete")

# rm(dem_ctg, dem, dem_path); gc()


# ##### Normalized Catalogue #####


# log_info("nLAS: Generating")

# # Set up the output for the normalized point clouds
# opt_output_files(ctg) <- path(config$scratch_dir, "normalized/norm_{ID}")

# # Normalize the point cloud
# norm_ctg <- normalize_height(ctg, dem)

# log_success("nLAS: Complete")


##### CHM #####


# log_info("CHM: Generating")

# # Configure temporary storage
# chm_ctg <- norm_ctg
# opt_output_files(chm_ctg) <- path(config$scratch_dir, "chm/chm_{XLEFT}_{YBOTTOM}")

# # Filter down to vegetation classes (above 1m)
# opt_filter(norm_ctg) <- "-keep_class 3 5 -drop_z_below 1"

# # Generate CHM
# chm <- rasterize_canopy(
#   norm_ctg,
#   res = config$spatial_resolution,
#   algorithm = p2r(0.2)
# )

# # Write out
# chm_path <- path(config$output_dir, "chm.tif")
# writeRaster(chm, chm_path, overwrite = TRUE)

# log_success("CHM: Complete")

# rm(chm_ctg, norm_ctg, chm, chm_path); gc()


##### B&G DSM #####


# log_info("DSM: Generating")
# dsm_ctg <- ctg
# opt_output_files(dsm_ctg) <- path(config$scratch_dir, "dsm/dsm_{XLEFT}_{YBOTTOM}")

# # Filter down to buildings/ground
# opt_filter(dsm_ctg) <- "-keep_class 2 6"

# # Generate a DSM using the filtered point cloud
# dsm <- rasterize_canopy(
#   dsm_ctg, config$spatial_resolution,
#   algorithm = p2r(0.2, na.fill = tin())
# )

# log_info("DSM: Generated")

# writeRaster(dsm, path(config$output_dir, "dsm.tif"), overwrite = TRUE)

# log_success("DSM: Complete")


##### Slope & Aspect #####

dsm <- rast(path(config$output_dir, "dsm.tif"))

log_info("TERRAIN: Generating")

# Generate terrain information
terrain_out <- tile_apply(
  dsm,
  function (r) terrain(r, v = c("slope","aspect"), neighbors = 8, unit = "radians"),
  cores = "future",
  buffer = 1,
  filename = path(config$scratch_dir, "terrain_tmp.tif"),
  overwrite = TRUE,
  wopt = list(datatype = "FLT4S")
)

# Rename layers and write out
names(terrain_out) <- c("slope", "aspect")
writeRaster(terrain_out, path(config$output_dir, "terrain.tif"), overwrite=TRUE)

log_success("TERRAIN: Complete")


##### Normal Surface #####


log_info("NORMAL: Generating")

plan(sequential)
terraOptions(parallel = TRUE, threads = config$workers)

slope <- terrain_out$slope
aspect <- terrain_out$aspect

# Calculate each pixel's normal vector
nx <- sin(aspect) * sin(slope)
ny <- cos(aspect) * sin(slope)
nz <- cos(slope)

# Define the normal vector
n <- c(nx, ny, nz)
names(n) <- c("nx", "ny", "nz")

# Write out
writeRaster(n, path(config$output_dir, "normals.tif"), overwrite = TRUE)

log_success("NORMAL: Complete")
