library("terra")
library("lidR")
library("tidyverse")

files <- list.files("data/LiDAR/raw", pattern="*.las", full.names = TRUE)

# Read each LAS file and update its header to include a CRS
for (f in files) {
  id <- str_extract(f, '(\\w+).las', group = 1)
  
  # Read LAS & filter duplicates
  las <- readLAS(f)
  las_filtered <- filter_duplicates(las)
  
  
  if (id == '5255D') {
    las_filtered <- filter_poi(las_filtered, ReturnNumber != 0)
  }
  
  # Write the result to file
  writeLAS(las, paste("data/LiDAR/clean/", id, ".las", sep=""))
}


ins <- rast("output/temp/rooftop-insolation.tif")
plot(ins)
ins



dem <- rast("D:/Dev/Geomatics/kamloops-solar/output/kamloops-dem.tif")
# WRONG

dsm <- rast("D:/Dev/Geomatics/kamloops-solar/output/kamloops-dsm.tif")
# WRONG

veg <- rast("D:/Dev/Geomatics/kamloops-solar/output/kamloops-dsm-veg.tif")
# WRONG

fps <- st_read("D:/Dev/Geomatics/kamloops-solar/output/kamloops-fp.gpkg")
# RIGHT

