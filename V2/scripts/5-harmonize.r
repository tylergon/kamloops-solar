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

    for (i in path_list) {
        print(stringr::str_glue("\nPath: {i}"))
        print(stringr::str_glue("Res: {res(rast(i))}"))
    }

    # TODO: Handle buffer pixels. Use VRTs?

    # Merge files
    src <- sprc(rast_list)
    mosaic(src, fun = "mean")
}


# Merge building & ground DSM
message(">>> Merging DSM")
bldg_grnd_dsm <- harmonize_dataset('dsm.tif')
writeRaster(bldg_grnd_dsm, fs::path(config$output_dir, "buildings_and_ground.tif"), overwrite = TRUE)

# Merge rooftop insolation output
message(">>> Merging Insolation")
insolation <- harmonize_dataset('Energyyearroof.tif')
writeRaster(insolation, fs::path(config$output_dir, "insolation.tif"), overwrite = TRUE)

# Merge CHM results
message(">>> Merging CHM")
chm <- harmonize_dataset('chm.tif')
writeRaster(chm, fs::path(config$output_dir, "chm.tif"), overwrite = TRUE)

# Slope
message(">>> Calculating slope")
slope <- terrain(bldg_grnd_dsm, v="slope", neighbors=8, unit="degrees")
writeRaster(slope, fs::path(config$output_dir, "slope.tif"), overwrite = TRUE)

# Aspect
message(">>> Calculating aspect")
aspect <- terrain(bldg_grnd_dsm, v = "aspect", neighbors = 8, unit="degrees")
writeRaster(aspect, fs::path(config$output_dir, "aspect.tif"), overwrite = TRUE)
