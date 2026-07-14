library(sf)
library(terra)
library(dbscan)
library(future)
library(furrr)
library(purrr)
library(dplyr)
library(fs)

source("src/utils.r")
init_logging("roof_segmentation")

normals_path <- path(config$output_dir, 'normals.tif')
print(rast(normals_path))
quit()


# Pull in building data and convert to polygons
bldg_rast <- rast(path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")


##### Perform segmentation #####


log_info("Beginning segmentation")

# Divide buildings into groups & parallelize
n_bldg <- nrow(bldg_poly)
chunks <- split(1:n_bldg, cut(1:n_bldg, config$workers, labels = FALSE))

plan(multisession, workers = config$workers)

result <- future_map(seq_along(chunks), \(i) {
# result <- map(seq_along(chunks), \(i) {
    chunk <- chunks[i]

    init_logging("rooftop_segmentation")

    # Load in the normals raster
    n_local <- rast(normals_path)

    # Sequentially segment buildings in this group
    map(chunk, \(j) {
        log_info("> Chunk {i}, Building {j} - Begin")

        # Crop out the buildings features
        bldg <- crop(n_local, bldg_poly[j,], mask = TRUE)

        # Generate a data frame encoding our variables for DBSCAN
        features <- as.data.frame(bldg, xy = TRUE) |> na.omit()
        print(head(features))
        return(NULL)

        # Handle edge cases
        # 1. No features are in the area
        # 2. Single column / row
        if (nrow(features) == 0 || length(unique(features$x)) < 2 || length(unique(features$y)) < 2) {
            log_error("> Chunk {i}, Building {j} - Error")
            return(NULL)
        }

        # Perform clustering
        db <- dbscan(features[, c("nx", "ny", "nz")], eps = 0.05, minPts = 6)
        features$cluster <- db$cluster

        print(head(features))

        # Build raster, wrap, and return
        r <- rast(features[, c("x", "y", "cluster")], crs = crs(bldg_j), extent = ext(bldg_j))
        r_wrapped <- wrap(r)

        log_info("> Chunk {i}, Building {j} - Complete")
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
    path(config$output_dir, "segments.tif"),
    overwrite = TRUE
)


segments_rast[segments_rast == 0] <- NA
segments_poly <- segments_rast |> as.polygons() |> st_as_sf() |> st_cast("POLYGON")
st_write(segments_poly, path(config$output_dir, "segments.gpkg"), delete_dsn = T)

log_success()
