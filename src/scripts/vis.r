library(fs)
library(sf)
library(terra)
library(future)
library(furrr)
library(purrr)

source("src/utils.r")

# TODO: Drop all non-important fields from segments

# TODO: Rename Energyyearroof to something normal




# writeVector(suitable_segments, path(config$output_dir, 'res.gpkg'))


# Load segments & divide into groups
segments_path <- path(config$output_dir, "segments.gpkg")
segments <- st_read(segments_path)
n_segments <- nrow(segments)
chunks <- split(1:n_segments, cut(1:n_segments, config$workers, labels = FALSE))

# Set up parallelism
if (FALSE) { plan(multisession, workers = config$workers) }

# Loop through chunks
result <- future_map(chunks, \(chunk) { 
    segments_local <- vect(segments_path)
    
    suitable_area <- rast(path(config$output_dir, "suitable_insolation.tif"))
    suitable_area[!is.na(suitable_area)] <- TRUE
    names(suitable_area) <- c("is_suitable")
    
    criteria <- rast(path(config$output_dir, c("irr.tif", "terrain.tif")))
    
    map(chunk, \(i) {
        segment <- segments_local[i,]

        suitable_area <- crop(suitable_area, segment) |> as.polygons(dissolve=TRUE)
        segment_suitable <- intersect(segment, suitable_area)

        if (is.empty(segment_suitable)) {
            return(NULL)
        }

        criteria_crop <- crop(criteria, segment_suitable, mask = TRUE)
        segment_criteria <- extract(criteria_crop, segment_suitable, fun=mean, na.rm=TRUE)
        
        wrap(cbind(segment_suitable, segment_criteria[, -1]))
    })
})

tmp <- list_flatten(result) |>
    keep(\(x) is(x, "PackedSpatVector")) |>
    map(\(x) unwrap(x))

tmp

sv <- do.call(rbind, unname(tmp))
writeVector(sv, path(config$output_dir, "sv.gpkg"))


# rasts <- rast(path(config$output_dir, fnames))

# Recalculate metrics
# Perimeter
# Area
# Perimeter to area

