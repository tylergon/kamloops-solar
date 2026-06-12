library(stringr)
library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(dbscan)

config <- fromJSON("config.json")

# Here we're grouping rooftop segments based off similar characteristics
# a couple of things to keep an eye on for optimization
    # edges around rooftop perimiters have HIGH slopes
    # pixels in contiguous panels have similar aspect
    # flat panels have crazy aspects ***** IT BECAME A PROBLEM I KNEW IT DUDDDDDE

# how do we deal with bordering area? assume it's required backoff?


# - - - - - -


# Prepare the main data inputs (aspect and slope)

# TODO: Rather than reading this in, aspect and slope should've been SAVED earlier
bldg_grnd_dsm <- rast(fs::path(config$output_dir, 'buildings_and_ground.tif'))

slope <- terrain(bldg_grnd_dsm, v="slope", neighbors=8, unit="degrees")

# TODO: Convert to a continuous range that works better with DBSCAN
aspect_raw <- terrain(bldg_grnd_dsm, v = "aspect", neighbors = 8, unit="degrees")
aspect_bins <- matrix(c(
    0, 45, 1, #N
    45, 135, 2, #E
    135, 225, 3, #S
    225, 315, 4, #W
    315, 360, 1 #N
), ncol=3, byrow = TRUE)
aspect <- classify(aspect_raw, rcl = aspect_bins, include.lowest = TRUE, right = TRUE)


# - - - - - -


# Pull in building data and convert to polygons

bldg_rast <- rast(fs::path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA

bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")


# - - - - - -


# Crop and mask the raster down to the individual building


# Loop through the buildings and perform the analysis


collection <- sprc()
for (i in seq_len(nrow(bldg_poly))) {
    bldg <- bldg_poly[i,]

    # Crop out the buildings features
    #       ** TODO: Low slope shouldn't have aspect. Reuse class from earlier?
    bldg_slope <- crop(slope, bldg, mask = TRUE)
    bldg_aspect <- crop(aspect, bldg, mask = TRUE)


    # Generate a data frame encoding our variables for DBSCAN
    #       ** TODO... Do we care about XY or pixel height?
    features <- as.data.frame(c(bldg_slope, bldg_aspect), xy = TRUE) |>
        na.omit()


    # Handle edge cases (TODO : Deeper understanding of causes)
    #       1. No features are in the area
    #       2. TODO ~ Scaling error... ?
    if (nrow(features) == 0) {
        next
    }

    message(str_glue(">>> Initiating DBSCAN [{i}/{nrow(bldg_poly)}]"))

    # TODO: Consider scaling our features...
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
r <- mosaic(collection, fun = "mean")
writeRaster(r, fs::path(config$output_dir, "clusters.tif"), overwrite=TRUE)
