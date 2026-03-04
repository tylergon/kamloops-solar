library('terra')
library('tidyverse')

DIR <- "D:/Dev/Geomatics/kamloops-solar/output/01-base-geospatial/"

nbhds <- read_csv("D:/Dev/Geomatics/kamloops-solar/scratch/neighbourhood_tiles.csv") %>% 
  select("neighbourhood")

for (i in 1:nrow(nbhds)) {
  curr <- print(nbhds[i,])
  
  # Read in the models
  CHM <- rast(paste0(DIR, curr, "/", curr, "-CHM.tif", sep=""))
  DSM <- rast(paste0(DIR, curr, "/", curr, "-DSM.tif", sep=""))
  
  # Find the smaller extent
  xmin <- max(ext(CHM)$xmin, ext(DSM)$xmin)
  xmax <- min(ext(CHM)$xmax, ext(DSM)$xmax)
  ymin <- max(ext(CHM)$ymin, ext(DSM)$ymin)
  ymax <- min(ext(CHM)$ymax, ext(DSM)$ymax)
  
  # Crop both rasters
  trg_ext <- ext(xmin, xmax, ymin, ymax)
  chm_cropped <- crop(CHM, trg_ext)
  dsm_cropped <- crop(DSM, trg_ext)
  
  # Save the files
  writeRaster(chm_cropped, paste0(DIR, curr, "/", curr, "-ADJUSTED-CHM.tif", sep=""))
  writeRaster(dsm_cropped, paste0(DIR, curr, "/", curr, "-ADJUSTED-DSM.tif", sep=""))
}

# Check you work
test_chm <- rast("D:/Dev/Geomatics/kamloops-solar/output/01-base-geospatial/SAGEBRUSH/SAGEBRUSH-ADJUSTED-CHM.tif")
test_dsm <- rast("D:/Dev/Geomatics/kamloops-solar/output/01-base-geospatial/SAGEBRUSH/SAGEBRUSH-ADJUSTED-DSM.tif")

ext(test_chm) == ext(test_dsm)
