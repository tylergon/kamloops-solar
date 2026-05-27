library(tidyverse)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

config <- fromJSON("config.json")

# Read in relevant LAS data
ctg <- readLAScatalog(
  config$input_dir,
  recursive = TRUE,
  pattern = "*.copc.laz"
)

# Configuration
st_crs(test_ctg) <- 26910 # TODO: Don't hardcode

# 1. Grid our AOI

# ~ TEMPORARY - This is just for writing the code ~
#   TODO: Switch this to the boundary shape file
bbox_vect <- st_bbox(test_ctg) %>%
  st_as_sfc() %>%
  st_buffer(-1 * config$chunk_buffer)
bbox <- st_bbox(bbox_vect %>% pluck(1))

cols <- ((bbox$xmax - bbox$xmin) / config$chunk_size) %>% ceiling()
rows <- ((bbox$ymax - bbox$ymin) / config$chunk_size) %>% ceiling()

# 2. Loop through the AOI performing our operations

# aoi <- list()
for (i in 1:rows) {
  for (j in 1:cols) {
    # Define tile bounds
    xmin <- (bbox$xmin + ((j - 1) * config$chunk_size)) %>% as.numeric()
    xmax <- xmin + config$chunk_size
    ymin <- (bbox$ymin + ((j - 1) * config$chunk_size)) %>% as.numeric()
    ymax <- ymin + config$chunk_size

    # Create a bounding box
    aoi_bbox <- c(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax) %>%
      st_bbox(crs = 26910)

    # Pad with our tile buffers
    tile_bbox <- aoi_bbox %>%
      st_as_sfc() %>%
      st_buffer(config$buffer_size) %>%
      st_bbox()

    # Clip out tile from the greater point cloud
    tile_ctg <- clip_roi(ctg, tile_bbox)
  }
}
