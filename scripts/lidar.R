library("tidyverse")
library("lidR")
library("lidRviewer")
library("sf")
library("terra")
library("RCSF")
library("dbscan")

# TODO:
#   Take only the top layer of LiDAR points
#   Filtering noise out
#   Identify vegetation


# Setup -------------------------------------------------------------------


# Basic LAS setup
las_og <- readLAS("data/LiDAR/5255C/5255C.las", select = "xyzrnc")
st_crs(las_og) <- 6653

# Load Kamloops footprints
fp_og <- st_read("data/building-footprints.gpkg")
fp_og <- st_transform(fp_og, crs = 6653)
fp_geom <- st_geometry(fp_og)

# Cut down the extent to save processing time
extent <- st_bbox(las_og)
bbox_poly <- st_as_sfc(extent)
grid <- st_make_grid(bbox_poly, n = c(2, 2))

# Clip down images
las <- clip_roi(las_og, grid[1])
fp <- st_crop(fp_geom, st_bbox(las))


# Topographic Models ------------------------------------------------------


# Identify & filter out the ground points
las_gnd <- classify_ground(las, algorithm = csf())
gnd <- filter_poi(las_gnd, Classification == 2L)

# Generate the DTM
dtm <- rasterize_terrain(gnd, res = 1, algorithm = tin())
nlas <- las - dtm

# plot_dtm3d(dtm_tin, bg = "white") 
plot(nlas)
plot(las)


# Building Footprint Identification ---------------------------------------


# Filter out points (over 2m and classified as "Building")
nlas_filter <- filter_poi(nlas, Z >= 2, Classification == 6)

# Cluster point cloud based on proximity
df <- data.frame(nlas_filter$X, nlas_filter$Y, nlas_filter$Z)
dbscan_res <- dbscan(df, eps=1, minPts = 20)

nlas_filter@data$ClusterID <- dbscan_res$cluster
las_clusters <- filter_poi(nlas_filter, ClusterID > 0)

plot(las_clusters, color = "ClusterID")

# Wrap each cluster with a concave hull

bldg_hulls <- st_sfc(crs = 6653)
for (id in unique(las_clusters$ClusterID)) {
  building <- filter_poi(nlas_filter, ClusterID == id)
  bldg_hull <- st_convex_hull(building)
  bldg_hulls <- c(bldg_hulls, bldg_hull)
}

# Filter out polygons w/ less than 20m of area
res_a <- bldg_hulls[(st_area(bldg_hulls) >= units::set_units(20, m^2))]

# Remove thin channels with a series of buffers
res_b <- st_buffer(st_buffer(res_a, -.5), .5)

# Write to file
st_write(res_b, 'output/footprint/5255C/5255C.shp')

plot(las)


# Export Topological Datasets ---------------------------------------------


dem <- rasterize_canopy(las, res = 0.5, algorithm = p2r(0.2, na.fill = tin()))
writeRaster(dem, 'output/DEM/5255C.tif', overwrite=TRUE)
plot(dem)






