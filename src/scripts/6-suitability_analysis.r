library(sf)
library(fs)
library(lidR)
library(terra)

source("src/utils.r")
init_logging("suitability_analysis")

# Inputs
bldgs <- rast(fs::path(config$output_dir, "buildings.tif"))
bldg_grnd_dsm <- rast(fs::path(config$output_dir, "buildings_and_ground.tif"))
insolation <- rast(fs::path(config$output_dir, "insolation.tif"))
slope <- rast(fs::path(config$output_dir, "slope.tif"))

log_info("Binning slopes")

# Bin slopes
slope_bins <- matrix(c(
    0, 5, 1, # Flat
    5, 60, 2, # Sloped
    60, 90, 3 # Too steep
), ncol = 3, byrow = TRUE)
slope_cl <- classify(slope, rcl = slope_bins, include.lowest = TRUE, right = TRUE)

log_info("Binning aspects")

# Bin aspects
aspect_bins <- matrix(c(
    0, 45, 1, #N
    45, 135, 2, #E
    135, 225, 3, #S
    225, 315, 4, #W
    315, 360, 1 #N
), ncol=3, byrow = TRUE)
aspect <- terrain(bldg_grnd_dsm, v = "aspect", neighbors = 8, unit="degrees")
aspect_cl <- classify(aspect, rcl = directions, include.lowest = TRUE, right = TRUE)

# Align datasets
bldgs_crop <- crop(bldgs, insolation, extend = TRUE)
slope_crop <- crop(slope_cl, insolation, extend = TRUE)
aspect_crop <- crop(aspect, insolation, extend = TRUE)

log_info("Defining masks")

# Identify locations unsuitable due to slope
slope_mask <- slope_crop != 3
writeRaster(slope_mask, fs::path(config$scratch_dir, "slope_mask.tif"), overwrite=T)

# Identify locations unsuitable due to aspect
aspect_mask <- aspect_crop > 45 & aspect_crop < 315
writeRaster(aspect_mask, fs::path(config$scratch_dir, "aspect_mask.tif"), overwrite=T)

log_info("Applying suitability criteria")

# Apply suitability criteria
suitable_insolation <- insolation |> 
    mask(bldgs_crop, maskvalues = FALSE) |> 
    mask(slope_crop != 3, maskvalues = FALSE) |>
    mask(slope_crop == 1 | (aspect_crop > 45 & aspect_crop < 315), maskvalues = FALSE) |>
    mask(insolation > 800, maskvalues = FALSE)

# Write out
out_path <- fs::path(config$output_dir, "suitable_insolation.tif")
writeRaster(suitable_insolation, out_path, overwrite = TRUE)
  
log_success()