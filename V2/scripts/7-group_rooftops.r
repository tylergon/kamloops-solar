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
    # flat panels have crazy aspects

# an idea Annie had was to use statistical clustering to determine alikeness
# perhaps for each building we cluster pixels based on variables
    # e.g. slope, aspect

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

bldg <- bldg_poly[1,]

# Generate DBSCAN variables
# TODO: Include elevation?
bldg_slope <- crop(slope, bldg, mask = TRUE)
bldg_aspect <- crop(aspect, bldg, mask = TRUE)

# Generate a data frame encoding all our variables for DBSCAN
features <- as.data.frame(c(bldg_slope, bldg_aspect), xy = TRUE)
    na.omit()
# TODO: Do we want XY? Maybe just group based on slope / aspect than separate non-touching px


# Perform DBSCAN

features_scaled <- scale(features)
# db <- dbscan(features_scaled, eps = 0.5, minPts = 5)

d <- dist(features_scaled)
db <- dbscan(d, eps = 0.5, minPts = 5, search = "dist")

#kNNdistplot(features_scaled, k = 4)
#abline(h = 0.5, col = "red")         # adjust h to elbow value





# Define the operation to perform on each building...




# Method

# Performed by looping through each building in the location

# Step 1
    # Take the suitable locations
    # Add their aspect & slope calculated from the DEM

# Step 2
    # Perform clustering

