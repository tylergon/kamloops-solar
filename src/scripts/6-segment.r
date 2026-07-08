library(stringr)
library(jsonlite)
library(lidR)
library(sf)
library(terra)
library(dbscan)
library(future)
library(furrr)
library(purrr)
library(dplyr)

config <- fromJSON("config.json")

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

# Define the normal vector
n <- c(nx, ny, nz)
names(n) <- c("nx", "ny", "nz")

normals_path <- fs::path(config$output_dir, "normals.tif")
writeRaster(n, normals_path, overwrite = TRUE)

# Clean up big files
rm(bldg_grnd_dsm, slope, aspect, nx, ny, nz, n)
gc()

# Pull in building data and convert to polygons
bldg_rast <- rast(fs::path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")

##### Perform segmentation #####

plan(multisession, workers = config$workers)

# Divide buildings into groups & parallelize
n_bldg <- nrow(bldg_poly)
chunks <- split(1:n_bldg, cut(1:n_bldg, config$workers, labels = FALSE))
result <- future_map(chunks, \(chunk) {
    # Load in the normals raster
    n_local <- rast(normals_path)

    # Sequentially segment buildings in this group
    map(chunk, \(i) {
        # Crop out the buildings features
        bldg_i <- crop(n_local, bldg_poly[i,])

        # Generate a data frame encoding our variables for DBSCAN
        features <- as.data.frame(bldg_i, xy = TRUE) |> na.omit()

        # Handle edge cases
        # 1. No features are in the area
        # 2. Single column / row
        if (nrow(features) == 0 || length(unique(features$x)) < 2 || length(unique(features$y)) < 2) {
            return(NULL)
        }

        print(features)

        # Perform clustering
        db <- dbscan(features[, c("nx", "ny", "nz")], eps = 0.5, minPts = 6)
        features$cluster <- db$cluster

        # Build raster, wrap, and return
        r <- rast(features[, c("x", "y", "cluster")], crs = crs(bldg_i), extent = ext(bldg_i))
        wrap(r)
    })
})

# Massage results into a single raster
segments_rast <- result |>
    list_flatten() |>
    keep(\(x) is(x, "PackedSpatRaster")) |>
    map(\(x) unwrap(x)) |>
    sprc() |>
    mosaic()

# Tear down & write out
plan(sequential)
writeRaster(
    segments_rast,
    fs::path(config$output_dir, "segments.tif"),
    overwrite = TRUE
)
