library(fs)
library(sf)
library(terra)
library(dbscan)
library(future)
library(furrr)
library(purrr)
library(dplyr)


source("src/utils.r")
init_logging("segmentation")

# Inputs
buildings_path <- path(config$output_dir, "buildings.tif")
normals_path <- path(config$output_dir, "normals.tif")

# Outputs
segments_poly_path <- path(config$output_dir, "segments.gpkg")
segments_rast_path <- path(config$output_dir, "segments.tif")

# Pull in building data and convert to polygons
bldg_rast <- rast(buildings_path)
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")

# Divide buildings into groups
n_bldg <- nrow(bldg_poly)
chunks <- split(1:n_bldg, cut(1:n_bldg, config$workers, labels = FALSE))

# Set up parallelism
plan(multisession, workers = config$workers)
bldg_poly_wrapped <- bldg_poly |> vect() |> wrap()

# TODO: Clean up memory unnecessary for loop

# Individually cluster each buildings pixels to identify segments
result <- future_map(chunks, \(chunk) {
    # Load in the normals raster
    n_local <- rast(normals_path)
    bldg_poly_local <- unwrap(bldg_poly_wrapped)

    # Sequentially segment buildings in this group
    map(chunk, \(i) {
        # Crop out the buildings features
        bldg_i <- crop(n_local, bldg_poly_local[i,], mask = TRUE)

        # Generate a data frame encoding our variables for DBSCAN
        features <- as.data.frame(bldg_i, xy = TRUE) |> na.omit()

        # Handle edge cases
        # 1. No features are in the area
        # 2. Single column / row
        if (nrow(features) == 0 || length(unique(features$x)) < 2 || length(unique(features$y)) < 2) {
            return(NULL)
        }

        # Perform clustering
        db <- dbscan(features[, c("nx", "ny", "nz")], eps = 0.1, minPts = 6)
        features$cluster <- db$cluster

        # Build raster, wrap, and return
        r <- rast(features[, c("x", "y", "cluster")], crs = crs(bldg_i), extent = ext(bldg_i))
        wrap(r)
    })
})

plan(sequential)

# Massage results into a single raster
segments_rast <- result |>
    list_flatten() |>
    keep(\(x) is(x, "PackedSpatRaster")) |>
    map(\(x) unwrap(x)) |>
    sprc() |>
    mosaic()

# Write out
writeRaster(segments_rast, segments_rast_path, overwrite = TRUE)
as.polygons(segments_rast) |>
    st_as_sf() |>
    st_cast("POLYGON") |>
    st_write(segments_poly_path, delete_dsn = TRUE)