library(stringr)
library(lidR)
library(sf)
library(terra)
library(dbscan)
library(future)
library(furrr)
library(purrr)
library(dplyr)

source("src/utils.r")
init_logging("roof_segmentation")


##### Prepare Inputs #####


log_info("Generating normal vectors")

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

log_success("Completed normal vector generation")

# Pull in building data and convert to polygons
bldg_rast <- rast(fs::path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")


##### Perform segmentation #####


log_info("Beginning segmentation")

plan(multisession, workers = config$workers)

# Divide buildings into groups & parallelize
n_bldg <- nrow(bldg_poly)
chunks <- split(1:n_bldg, cut(1:n_bldg, config$workers, labels = FALSE))

result <- future_map(seq_along(chunks), \(i) {
    chunk <- chunks[i]

    init_logging("rooftop_segmentation")

    # Load in the normals raster
    n_local <- rast(normals_path)

    # Sequentially segment buildings in this group
    map(chunk, \(j) {
        log_info("> Chunk ", i, ", Building ", j, " ] - Begin")

        # Crop out the buildings features
        bldg_j <- crop(n_local, bldg_poly[j,], mask = TRUE)

        # Generate a data frame encoding our variables for DBSCAN
        features <- as.data.frame(bldg_j, xy = TRUE) |> na.omit()

        # Handle edge cases
        # 1. No features are in the area
        # 2. Single column / row
        if (nrow(features) == 0 || length(unique(features$x)) < 2 || length(unique(features$y)) < 2) {
            log_error("> Chunk ", i, ", Building ", j, " ] - Error")
            return(NULL)
        }

        # Perform clustering
        db <- dbscan(features[, c("nx", "ny", "nz")], eps = 0.05, minPts = 10)
        features$cluster <- db$cluster

        # Build raster, wrap, and return
        r <- rast(features[, c("x", "y", "cluster")], crs = crs(bldg_j), extent = ext(bldg_j))
        r_wrapped <- wrap(r)

        log_info("> Chunk ", i, ", Building ", j, " ] - Complete")
        r_wrapped
    })
})

log_info("Rooftop segmentation - Successful")

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


segments_rast[segments_rast == 0] <- NA
segments_poly <- segments_rast |> as.polygons() |> st_as_sf() |> st_cast("POLYGON")
st_write(segments_poly, fs::path(config$output_dir, "segments.gpkg"), delete_dsn = T)

log_success()
