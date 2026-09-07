library(fs)
library(sf)
library(terra)
library(dbscan)
library(future)
library(furrr)
library(purrr)
library(dplyr)
library(lwgeom)
library(units)

source("src/utils.r")
init_logging("5-segmentation")

# Inputs
buildings_path <- path(config$output_dir, "buildings.tif")
normals_path <- path(config$output_dir, "normals.tif")


building_polygons_path <- path(config$scratch_dir, "buildings.gpkg")
segments_dir_path <- path(config$scratch_dir, "segments")
if (!dir.exists(segments_dir_path)) dir.create(segments_dir_path)

# Outputs
segments_poly_path <- path(config$output_dir, "segments.gpkg")
segments_rast_path <- path(config$output_dir, "segments.tif")

# If no buildings progress table exists, create it
if (!file.exists(building_polygons_path)) {
  # Pull in building data and convert to polygons
  bldg_rast <- rast(buildings_path)
  bldg_rast[!bldg_rast] <- NA
  bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON") |>
    mutate(id = as.character(row_number()))

  # Write the polygons to file
  st_write(bldg_poly, building_polygons_path)
}

# Check which buildings have been processed
processed_building_ids <- list.files(segments_dir_path) |>
  str_match("(?<id>\\d+).tif") |> # Get building IDs
  (\(x) x[,"id"])() # Extract to list
bldg_poly <- st_read(building_polygons_path)
remaining_building_ids <- setdiff(bldg_poly$id, processed_building_ids)

# Strip the bldg_poly collection down to just rows needing to be processed
remaining_buildings <- bldg_poly[bldg_poly$id %in% remaining_building_ids, ]

# Divide buildings into groups
n_bldg <- nrow(remaining_buildings)
chunks <- split(1:n_bldg, cut(1:n_bldg, config$workers, labels = FALSE))

# Set up parallelism
plan(multisession, workers = config$workers)
bldg_wrapped <- remaining_buildings |> vect() |> wrap()

# Individually cluster each buildings pixels to identify segments
ret <- future_map(chunks, \(chunk) {
  # Load in the normals raster
  n_local <- rast(normals_path)
  bldg_local <- unwrap(bldg_wrapped)
  
  init_logging("5-segmentation")

  # Sequentially segment buildings in this group
  map(chunk, \(i) {
    # Crop out the buildings features
    bldg_i <- crop(n_local, bldg_local[i,], mask = TRUE)
    bldg_id <- bldg_local[i,]$id

    log_info(paste0("Segmenting ", bldg_id))

    # Generate a data frame encoding our variables for DBSCAN
    features <- as.data.frame(bldg_i, xy = TRUE) |> na.omit()

    # Handle edge cases
    # 1. No features are in the area
    # 2. Single column / row
    if (nrow(features) == 0 || length(unique(features$x)) < 2 ||
          length(unique(features$y)) < 2)
      return(NULL)

    # Perform clustering
    db <- dbscan(features[, c("nx", "ny", "nz")], eps = 0.04, minPts = 6)
    features$cluster <- db$cluster

    # Build raster, wrap, and return
    result <- rast(features[, c("x", "y", "cluster")], crs = crs(bldg_i), extent = ext(bldg_i)) |>
      writeRaster(path(segments_dir_path, bldg_id, ext="tiff"))
  })
})

plan(sequential)

log_info("Segmentation complete")

segments_scratch_path <- path(config$scratch_dir, "segments.tiff")

# Massage results into a single raster
segments_rast <- list.files(segments_dir_path, pattern = "\\.tiff$", full.names = TRUE) |>
  lapply(rast) |>
  sprc() |>
  mosaic(fun = "mean", filename = segments_scratch_path)
segments_rast[segments_rast == 0] <- NA
writeRaster(segments_rast, segments_rast_path, overwrite = TRUE)

# Calculate metrics for filtering segments
segment_metrics <- as.polygons(segments_rast) |>
  st_as_sf() |>
  st_cast("POLYGON") |>
  # Generate geometric fields
  mutate(
    area_m2 = st_area(geometry),
    perimeter_m = st_perimeter(geometry),
    para = drop_units(perimeter_m / area_m2)
  ) |>
  # Filter out "obstructions" (area_m2 <= 2 shouldn't exist w/ minPts=6)
  filter(para < 3, area_m2 >= 2)

# Write out results
st_write(segment_metrics, segments_poly_path, delete_dsn = TRUE)
