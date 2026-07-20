library(terra)
library(stringr)
library(fs)

source("src/utils.r")
init_logging("harmonizing")

log_info("Merging insolation")

# Read in the dataset
sebe_dir <- path(config$scratch_dir, "SEBE")
path_list <- list.files(path = sebe_dir,
                        pattern = "irr.tif", 
                        recursive = TRUE)
path_list <- path(sebe_dir, path_list)
rast_list <- lapply(path_list, rast)

# Merge files
src <- sprc(rast_list)
irr <- mosaic(src, fun = "mean")

writeRaster(irr, path(config$output_dir, "irr.tif"), overwrite = TRUE)

log_success("Merge complete")
