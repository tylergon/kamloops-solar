library(terra)
library(stringr)
library(fs)

source("src/utils.r")

# Util Function
# Combine our SEBE inputs/outputs into citywide rasters
harmonize_dataset <- function (file_name) {
    sebe_dir <- path(config$scratch_dir, "SEBE")

    # Read in the dataset
    path_list <- list.files(path = sebe_dir, 
                            pattern = str_glue("{file_name}$"), 
                            recursive = TRUE)
    path_list <- path(sebe_dir, path_list)
    rast_list <- lapply(path_list, rast)

    # Merge files
    src <- sprc(rast_list)
    mosaic(src, fun = "mean")
}

# Merge building & ground DSM
log_info("Merging DSM")
bldg_grnd_dsm <- harmonize_dataset('dsm.tif')
writeRaster(bldg_grnd_dsm, path(config$output_dir, "buildings_and_ground.tif"), overwrite = TRUE)

# Merge rooftop insolation output
log_info("Merging insolation")
insolation <- harmonize_dataset('Energyyearroof.tif')
writeRaster(insolation, path(config$output_dir, "insolation.tif"), overwrite = TRUE)

# Merge CHM results
log_info("Merging CHM")
chm <- harmonize_dataset('chm.tif')
writeRaster(chm, path(config$output_dir, "chm.tif"), overwrite = TRUE)

# Slope
log_info("Calculating slope")
slope <- terrain(bldg_grnd_dsm, v="slope", neighbors=8, unit="degrees")
writeRaster(slope, path(config$output_dir, "slope.tif"), overwrite = TRUE)

# Aspect
log_info("Merging aspect")
aspect <- terrain(bldg_grnd_dsm, v = "aspect", neighbors = 8, unit="degrees")
writeRaster(aspect, path(config$output_dir, "aspect.tif"), overwrite = TRUE)

log_success()
