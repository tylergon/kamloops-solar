library(stringr)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

config <- read_json("config.json")

# ARG1: Working directory
args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

##### 1. Building & Ground DSM #####

# Read & configure point cloud
ctg <- readLAScatalog(wd)
st_crs(ctg) <- config$crs
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE
opt_chunk_size(ctg) <- 0 # Perform operation over the whole tile

# Filter down to building & ground points
opt_filter(ctg) <- "-keep_class 2 6"

# Generate a DSM using the filtered point cloud
dsm <- rasterize_canopy(
  ctg, config$spatial_resolution,
  algorithm = p2r(0.2, na.fill = tin())
)

# Fill in NA values
w <- 1
while (global(dsm, function(x) any(is.na(x)))[, 1]) {
  w <- w + 2
  dsm <- focal(
    dsm,
    w = w,
    fun = mean,
    na.policy = "only",
    na.rm = TRUE
  )
}

##### 2. Canopy Height Model #####

# Load normalized point cloud for AOI
norm_path <- paste0(config$scratch_dir, "/normalized/")
norm_las <- readLAScatalog(norm_path) |> clip_roi(st_bbox(ctg))

# Filter down to vegetation classes (above 1m)
norm_las <- filter_poi(norm_las, Classification %in% c(3, 5) & Z >= 1)

# Generate CHM
chm <- rasterize_canopy(
  norm_las,
  res = config$spatial_resolution,
  algorithm = p2r(0.2)
)

# Replace NA pixels w/ 0 -- required for SEBE
chm[is.na(chm)] <- 0

##### 3. Write out #####

# Align output extents
ext_out <- intersect(ext(dsm), ext(chm))
dsm <- crop(dsm, ext_out)
chm <- crop(chm, ext_out)

# Write results
writeRaster(dsm, fs::path(wd, "dsm.tif"), overwrite = TRUE)
writeRaster(chm, fs::path(wd, "chm.tif"), overwrite = TRUE)
