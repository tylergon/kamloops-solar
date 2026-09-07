library(dbscan)
library(dplyr)
library(purrr)
library(terra)
library(sf)
library(ggplot2)
library(tibble)

config <- jsonlite::fromJSON("config.json")

minPts <- 6

# Pull in building data and convert to polygons
bldg_rast <- rast(fs::path(config$output_dir, 'buildings.tif'))
bldg_rast[!bldg_rast] <- NA
bldg_poly <- as.polygons(bldg_rast) |>
    st_as_sf() |>
    st_cast("POLYGON")

# Load in normals
normals_path <- fs::path(config$output_dir, "normals.tif")
normals <- rast(normals_path)

# Loop through buildings and calculate KNN distance
df <- map(1:nrow(bldg_poly), \(i) {
    bldg_i <- crop(normals, bldg_poly[i,])
    features <- as.data.frame(bldg_i, xy = TRUE) |> na.omit()
    if (nrow(features) < minPts || length(unique(features$x)) < 2 || length(unique(features$y)) < 2) {
        return(NULL)
    }

    d <- sort(kNNdist(features[, c("nx", "ny", "nz")], k = minPts))
    tibble(
        bldg_id = as.character(i),
        proportion = seq_along(d) / length(d),
        dist = d,
    )
}) |> compact() |> bind_rows()

# Overlay individual building plots
ggplot(df, aes(x = proportion, y = dist, group = bldg_id)) +
  geom_line(alpha = 0.05, color = "steelblue") +
  labs(x = "Proportion of points sorted by distance",
       y = "Points sorted by distance") +
  theme_minimal()

