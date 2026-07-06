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
bldg_grnd_dsm <- rast(fs::path(wd, 'dsm.tif'))

# Calculate & bin slopes
slope_raw <- terrain(bldg_grnd_dsm, v="slope", neighbors=8, unit="degrees")
slope_bins <- matrix(c(00, 10, 1,
                       10, 35, 2,
                       35, 45, 3,
                       45, 60, 4,
                       60, 99, 5), ncol=3, byrow = TRUE)
slope <- classify(slope_raw, rcl = slope_bins, include.lowest = TRUE, right = TRUE)

# Calculate aspect & convert to radians
aspect_raw <- terrain(bldg_grnd_dsm, v = "aspect", neighbors = 8, unit="degrees")
aspect_bins <- matrix(c(
    0, 45, 1, #N
    45, 135, 2, #E
    135, 225, 3, #S
    225, 315, 4, #W
    315, 360, 1 #N
), ncol=3, byrow = TRUE)
aspect <- classify(aspect_raw, rcl = aspect_bins, include.lowest = TRUE, right = TRUE)

# Pull in building data and convert to polygons
bldg_rast <- rast(fs::path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")

##### Perform segmentation

# Setup output
collection <- sprc()

# Loop through each identified building
for (i in seq_len(nrow(bldg_poly))) {
    bldg <- bldg_poly[i,]

    # Crop out the buildings features
    bldg_slope <- crop(slope, bldg, mask = TRUE)
    bldg_aspect <- crop(aspect, bldg, mask = TRUE)

    # Generate a data frame encoding our variables for DBSCAN
    features <- as.data.frame(c(bldg_slope, bldg_aspect), xy = TRUE) |>
        na.omit()

    # Handle edge cases
    # 1. No features are in the area
    # 2. Single column / row
    if (nrow(features) == 0 || length(unique(features$x)) < 2 || length(unique(features$y)) < 2) {
        next
    }

    # Perform scan
    db <- dbscan(features[, c("slope", "aspect")], eps = 0.5, minPts = 5)

    # Assign our features their cluster number and rebuild a raster
    features$cluster <- db$cluster
    add(collection) <- rast(
        features[, c("x", "y", "cluster")],
        crs = crs(bldg_slope),
        extent = ext(bldg_slope),
    )
}

# Write out our collection
res <- mosaic(collection, fun = "mean")
writeRaster(res, fs::path(config$output_dir, "segments.tif"), overwrite = TRUE)
