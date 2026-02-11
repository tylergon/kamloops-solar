library("lidR")
library("tidyverse")

files <- list.files("data/LiDAR/source", pattern="*.las", full.names = TRUE)

# Read each LAS file and update its header to include a CRS
# for (f in files) {
#   las <- readLAS(f)
#   id <- str_extract(f, '(\\w+).las', group = 1)
#   writeLAS(las, paste("data/LiDAR/clean/", id, ".las", sep=""))
# }

# Identify corrupt tile
# for (f in files) {
#   id <- str_extract(f, '(\\w+).las', group = 1)
#   header <- readLASheader(f)
#   if (header$`Min X` < 1) {
#     print(id)
#   }
# }


cat <- readLAScatalog("data/LiDAR/clean")



