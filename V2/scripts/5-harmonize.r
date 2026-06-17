# Question... Is this performant at cityscale?

library(jsonlite)
library(fs)
library(terra)

config <- fromJSON("config.json")

# Utility function to combine our SEBE inputs/outputs into citywide rasters
harmonize_dataset <- function (file_name) {

    # Read in the dataset
    prefix <- fs::path(config$scratch_dir, "SEBE")
    path_list <- list.files(path = prefix, 
                            pattern = file_name, 
                            recursive = TRUE)
    path_list <- fs::path(prefix, path_list)
    rast_list<- lapply(path_list, rast)

    # TODO: Handle buffer pixels. Use VRTs?

    # Merge files
    src <- sprc(rast_list)
    mosaic(src, fun = "mean")
}


# Merge building & ground DSM
bldg_grnd_dsm <- harmonize_dataset('dsm.tif')
writeRaster(bldg_grnd_dsm, fs::path(config$output_dir, "buildings_and_ground.tif"), overwrite = TRUE)

# Merge rooftop insolation output
insolation <- harmonize_dataset('Energyyearroof.tif')
writeRaster(insolation, fs::path(config$output_dir, "insolation.tif"), overwrite = TRUE)

# Merge CHM results
chm <- harmonize_dataset('chm.tif')
writeRaster(chm, fs::path(config$output_dir, "chm.tif"), overwrite = TRUE)

# Slope
slope <- terrain(bldg_grnd_dsm, v="slope", neighbors=8, unit="degrees")
writeRaster(slope, fs::path(config$output_dir, "slope.tif"), overwrite = TRUE)

# Aspect
aspect <- terrain(bldg_grnd_dsm, v = "aspect", neighbors = 8, unit="degrees")
writeRaster(aspect, fs::path(config$output_dir, "aspect.tif"), overwrite = TRUE)
