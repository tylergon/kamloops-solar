library(sf)
library(terra)
library(lidR)

args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

source("src/utils.r")
init_logging("sebe_inputs - {wd}")


##### 1. Building & Ground DSM #####




##### 2. Canopy Height Model #####




##### 3. Write out #####

log_info("Writing results")

# Align output extents
ext_out <- intersect(ext(dsm), ext(chm))
dsm <- crop(dsm, ext_out)
chm <- crop(chm, ext_out)

# Write results
writeRaster(dsm, fs::path(wd, "dsm.tif"), overwrite = TRUE)
writeRaster(chm, fs::path(wd, "chm.tif"), overwrite = TRUE)

log_success("Complete")
