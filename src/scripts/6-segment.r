library(stringr)
library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(dbscan)

config <- fromJSON("config.json")

args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

##### Prepare Inputs #####

# Read in building / ground DSM
bldg_grnd_dsm <- rast(fs::path(config$output_dir, 'buildings_and_ground.tif'))

# Calculate slope & aspect
slope <- terrain(bldg_grnd_dsm, v="slope", neighbors=8, unit="radians")
aspect <- terrain(bldg_grnd_dsm, v = "aspect", neighbors = 8, unit="radians")

# Calculate each pixel's normal vector
nx <- sin(aspect) * sin(slope)
ny <- cos(aspect) * sin(slope)
nz <- cos(slope)
n <- c(nx, ny, nz)
names(n) <- c("nx", "ny", "nz")

# Pull in building data and convert to polygons
bldg_rast <- rast(fs::path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")

##### Perform segmentation

# Setup output
segments <- sprc()

# Loop through each identified building
for (i in seq_len(nrow(bldg_poly))) {
    bldg <- bldg_poly[i,]

    # Crop out the buildings features
    bldg_n <- crop(n, bldg, mask = TRUE)

    # Generate a data frame encoding our variables for DBSCAN
    features <- as.data.frame(bldg_n, xy = TRUE) |>
        na.omit()

    # Handle edge cases
    # 1. No features are in the area
    # 2. Single column / row
    if (nrow(features) == 0 || length(unique(features$x)) < 2 || length(unique(features$y)) < 2) {
        next
    }

    # Perform scan
    db <- dbscan(features[, c("nx", "ny", "nz")], eps = 0.5, minPts = 5)

    # Assign our features their cluster number and rebuild a raster
    features$cluster <- db$cluster
    add(segments) <- rast(
        features[, c("x", "y", "cluster")],
        crs = crs(bldg_n),
        extent = ext(bldg_n)
    )
}


res <- mosaic(segments)

# Write out our collection
writeRaster(res, fs::path(config$output_dir, "segments.tif"), overwrite = TRUE)
writeRaster(n, fs::path(config$output_dir, "normal.tif"), overwrite = TRUE)
