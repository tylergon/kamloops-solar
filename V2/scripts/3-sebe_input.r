library(tidyverse)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

# args <- commandArgs(trailingOnly = TRUE)
# wd <- args[1]
wd <- "C:/Users/Tyler/Desktop/PV/Scratch/SEBE/1"

print(str_glue("Starting.........{wd}"))

config <- read_json("config.json")


# ~~ 1. Building & Ground DSM ~~


ctg <- readLAScatalog(wd)
st_crs(ctg) <- 26910
opt_chunk_size(ctg) <- 0 # Lazy...

ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Filter down to building & ground points

opt_filter(ctg) <- "-keep_class 2 6"

# Generate a DSM using the filtered point cloud
dsm <- rasterize_canopy(
  ctg, config$spatial_resolution,
  algorithm = p2r(0.2, na.fill = tin())
)

# COULD I INSTEAD USE TIN TO INTERPOLATE THESE SURFACES?

# Fill in NA values
w <- 1
while (global(dsm, function(x) any(is.na(x)))[, 1]) {
  w <- w + 2
  dsm <- focal(
    dsm,
    w = w, fun = mean, na.policy = "only", na.rm = TRUE
  )
}

writeRaster(
  dsm,
  paste0(wd, "/dsm.tif"),
  overwrite = TRUE
)


# # ~~ 2. Canopy Height Model ~~


norm_path <- paste0(config$scratch_dir, "/normalized/")
norm_las <- readLAScatalog(norm_path) %>% clip_roi(st_bbox(ctg))

# Filter down to only vegetation classes (above 1m)
norm_las <- filter_poi(norm_las, Classification %in% c(3, 5) & Z >= 1)

# Create a DSM of just the vegetation layer & write it out
chm <- rasterize_canopy(norm_las, res = config$spatial_resolution, p2r(0.2)) %>%
  replace(is.na(.), 0)

writeRaster(
  chm,
  paste0(wd, "/chm.tif"),
  overwrite = TRUE
)

print(str_glue("Complete.........{wd}"))

slope <- terrain(dsm, "slope", neighbors = 8)
writeRaster(
  slope,
  paste0(wd, "/slope.tif"),
  overwrite = TRUE
)

aspect <- terrain(dsm, "aspect", neighbors = 8)
writeRaster(
  aspect,
  paste0(wd, "/aspect.tif"),
  overwrite = TRUE
)
