library(sf)
library(fs)
library(lidR)
library(terra)

source("src/utils.r")
init_logging("6-suitability_analysis")

# Inputs
segments <- st_read(path(config$output_dir, "segments.gpkg"))
insolation <- rast(path(config$output_dir, "irr.tif"))
terrain <- rast(path(config$output_dir, "terrain.tif")) * (180 / pi)
slope <- terrain$slope
aspect <- terrain$aspect

# Align datasets
slope_crop <- crop(slope, insolation, extend = TRUE)
aspect_crop <- crop(aspect, insolation, extend = TRUE)

log_info("Defining masks")

# Identify locations unsuitable due to slope
slope_mask <- slope <= 60
writeRaster(slope_mask, path(config$scratch_dir, "slope_mask.tif"), overwrite=T)

# Identify locations unsuitable due to aspect
aspect_mask <- slope <= 10 | (aspect_crop > 45 & aspect_crop < 315)
writeRaster(aspect_mask, path(config$scratch_dir, "aspect_mask.tif"), overwrite=T)

log_info("Applying suitability criteria")

# Apply suitability criteria
suitable_insolation <- insolation |> 
    mask(segments) |> 
    mask(slope_mask, maskvalues = FALSE) |>
    mask(aspect_mask, maskvalues = FALSE) |>
    mask(insolation > 800, maskvalues = FALSE)

# Write out
out_path <- path(config$output_dir, "suitable_insolation.tif")
writeRaster(suitable_insolation, out_path, overwrite = TRUE)
  
log_success()