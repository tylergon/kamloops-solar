library("terra")
library("lidR")
library("tidyverse")

OUT_DIR <- "data/LiDAR/clean/"

files <- list.files("data/LiDAR/raw", pattern="*.las", full.names = TRUE)

# Read each LAS file and update its header to include a CRS
for (f in files) {
  id <- str_extract(f, '(\\w+).las', group = 1)
  
  # Read LAS & filter duplicates
  las <- readLAS(f)
  las_filtered <- filter_duplicates(las)
  
  # Custom adjustment to 5255D for invalid geometry
  if (id == '5255D') {
    las_filtered <- filter_poi(las_filtered, ReturnNumber != 0)
  }

  # Apply the CRS
  st_crs(las_filtered) <- 26910
  
  # Write the result to file
  writeLAS(las_filtered, paste(OUT_DIR, id, ".las", sep=""))
}
