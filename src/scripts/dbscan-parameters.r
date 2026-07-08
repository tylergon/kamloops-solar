library(dbscan)
library(dplyr)
library(purrr)
library(terra)
library(sf)

config <- jsonlite::fromJSON("config.json")

# Pull in building data and convert to polygons
bldg_rast <- rast(fs::path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")

# OVERLAID

# GRID BASED

sample(1:nrow(bldg_poly), 12)
