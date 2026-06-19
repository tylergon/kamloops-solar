library(stringr)
library(jsonlite)
library(lidR)
library(sf)
library(terra)

# Configuration

config <- read_json("config.json")

# Fetch working directory from arguments

args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

message(str_glue("> SEBE::INPUTS::BEGIN ~ {wd}"))


# ~~ 1. Building & Ground DSM ~~


ctg <- readLAScatalog(wd)
st_crs(ctg) <- config$crs

opt_chunk_size(ctg) <- 0 # TODO Fix this lazy code

ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Create a grid for the outputs

extent_raw <- ext(ctg)
extent_adj <- c(
  xmin = floor(extent_raw$xmin),
  xmax = ceiling(extent_raw$xmax),
  ymin = floor(extent_raw$ymin),
  ymax = ceiling(extent_raw$ymax)
)

# Filter down to building & ground points

opt_filter(ctg) <- "-keep_class 2 6"

# Generate a DSM using the filtered point cloud

message(">>> GENERATING B&G DSM")

dsm <- rasterize_canopy(
  ctg, config$spatial_resolution,
  algorithm = p2r(0.2, na.fill = tin())
)

message(">>> COMPLETE B&G DSM")



# Fill in NA values
# TODO: Tin interpolate surface instead?
w <- 1
while (global(dsm, function(x) any(is.na(x)))[, 1]) {
  message(str_glue(">>> Filling Pixels ~ R{ceiling(w/2)}"))
  w <- w + 2
  dsm <- focal(
    dsm,
    w = w, fun = mean, na.policy = "only", na.rm = TRUE
  )
}


# # ~~ 2. Canopy Height Model ~~


norm_path <- paste0(config$scratch_dir, "/normalized/")
norm_las <- readLAScatalog(norm_path) |> clip_roi(st_bbox(ctg))

# Filter down to only vegetation classes (above 1m)
norm_las <- filter_poi(norm_las, Classification %in% c(3, 5) & Z >= 1)

# Create a DSM of just the vegetation layer & write it out
# message(">>> Generating CHM")
chm <- rasterize_canopy(
  norm_las,
  res = config$spatial_resolution,
  algorithm = p2r(0.2)
)

chm[is.na(chm)] <- 0


# Make sure edges match & write to file

# TODO: This method should instead find the correct tile extent
#            and use the extent to define the tile size, interpolating / filling as needed
#            logistically the DSM should always be bigger.... right?

ext_dsm <- ext(dsm)
ext_chm <- ext(chm)
if (ext_dsm != ext_chm) {
  bounds <- c(
    xmin = max(ext_dsm$xmin, ext_chm$xmin),
    xmax = min(ext_dsm$xmax, ext_chm$xmax),
    ymin = max(ext_dsm$ymin, ext_chm$ymin),
    ymax = min(ext_dsm$ymax, ext_chm$ymax)
  )

  dsm <- crop(dsm, bounds)
  chm <- crop(chm, bounds)
}


message(">>> Writing DSM")
writeRaster(
  dsm,
  paste0(wd, "/dsm.tif"),
  overwrite = TRUE
)

# message(">>> Writing CHM")
writeRaster(
  chm,
  paste0(wd, "/chm.tif"),
  overwrite = TRUE
)

message(str_glue("> SEBE::INPUTS::COMPLETE"))
