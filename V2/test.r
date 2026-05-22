library(tidyverse)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

config <- read_json("config.json")

test_path <- "C:/Users/Tyler/Desktop/5255C/5255C.copc.laz"

test_ctg <- readLAScatalog(test_path)
st_crs(test_ctg) <- 26910


# test_clip <- clip_rectangle(test_las, test_ext$xmin, test_ext$ymin,
#   test_ext$xmin + config$chunk_size, test_ext$ymin + config$chunk_size)

# 1. Get the extremities of the bounding box


# ~~ NOTE ~~

# For the POC, we can switch the municipal boundaries for a (-) buffer on the
# LAS catalogue, I guess 2x the size of the buffer for safety? Or just rip it.

test_bbox_vect <- st_bbox(test_ctg) %>%
  st_as_sfc() %>%
  st_buffer(-1 * config$chunk_buffer)

plot(test_bbox_vect, axes = TRUE)

# ~~  ~~  ~~


# Define a grid within our AOI. Loop through it

test_bbox <- st_bbox(test_bbox_vect %>% pluck(1))
cols <- ((test_bbox$xmax - test_bbox$xmin) / config$chunk_size) %>% ceiling()
rows <- ((test_bbox$ymax - test_bbox$ymin) / config$chunk_size) %>% ceiling()

aoi <- list()
for (i in 1:rows) {
  for (j in 1:cols) {
    # Define the tile AOI
    xmin <- as.numeric(test_bbox$xmin) + ((j - 1) * config$chunk_size)
    ymin <- as.numeric(test_bbox$ymin) + ((i - 1) * config$chunk_size)

    # Switch to min b/w this and the AOI maxes?
    xmax <- xmin + config$chunk_size
    ymax <- ymin + config$chunk_size

    # Create a bounding box for our tile (excluding the buffer)
    aoi_bbox <- c(xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax) %>%
      st_bbox(crs = 26910)

    # Include the chunk buffer into the bounding box
    tile_bbox <- aoi_bbox %>%
      st_as_sfc() %>%
      st_buffer(config$chunk_buffer) %>%
      st_bbox()

    # Clip out our tile's point cloud
    clip_roi(test_ctg, aoi_bbox)

    # TODO ~ Ensure the tile is within the AOI (municipal boundaries)
    # TODO ~ Write this to the metadata file for the tile

    # - - Validation Stuff - -

    # Append the tile AOI to our list
    ind <- ((i - 1) * cols) + j
    aoi[[ind]] <- tile_bbox %>%
      st_as_sfc() %>%
      pluck(1)

    # ------------------------
  }
}

# QUESTION: Do we normalize the point cloud on a tile vs. catalogue basis?
#           We could technically just leverage catalogues to tile it naturally.




aoi_sfc <- aoi %>% st_as_sfc()

plot(test_bbox_vect, axes = TRUE)
plot(aoi_sfc, add = TRUE)
plot(aoi[[27]], fill = "yellow", border = "yellow", add = TRUE)


aoi_temp <- aoi %>% filter(!map_lgl(geometry, ~ any(is.infinite(.x))))

# TODO: My operations such that I can answer the action items from Annie.
