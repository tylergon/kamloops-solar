library("tidyverse")
library("lidR")
library("lidRviewer")
library("sf")
library("terra")
library("RCSF")
library("dbscan")


# TODO & stuff

# - New script: slope, azimuth, & > 800 kwh/m^2
#   ***

# - Statistical analysis

# - Implement Toula's least squares algorithm for wrapping
#   **
# - Fiddle with DB scan optimization
#   **
# - Fiddle with building wrapping parameters (more square)
#   **

# - Filter out powerlines (& other noise filtering)
#   ***

# POST INITIAL RESULTS

# - Add in a vegetation layer
# - Explore further UMEP parameters


# IF THERE IS A CHANCE

# - Explore coplanarity and its usefulness (otherwise QGIS)
#   *

# - Classify the ground data myself
#   *



# Setup -------------------------------------------------------------------


# Basic LAS setup
las_init <- readLAS("data/LiDAR/5255C/5255C.las", select = "xyzrnc")
st_crs(las_init) <- 6653

# Load Kamloops footprints
fp_init <- st_read("data/building-footprints.gpkg") %>% 
  st_transform(crs = 6653) %>% 
  st_geometry()

# Load the tile's orthophoto
rgb <- rast('data/Orthophoto/5255C.tif')
crs(rgb) <- "epsg:6653"

# Create smaller extent to cut down on processing during development phase
extent <- st_bbox(las_init)
bbox_poly <- st_as_sfc(extent)
grid <- st_make_grid(bbox_poly, n = c(2, 2))

# Clip down images
las <- clip_roi(las_init, grid[1])
fp <- st_crop(fp_init, st_bbox(las))
rgb <- terra::crop(rgb, st_bbox(las))

# Plot to validate results
#plot(las)
#plot(fp)
plotRGB(rgb)



# Filtering & Cleaning ----------------------------------------------------


# TODO: Try to remove the powerlines


# Topographic Models ------------------------------------------------------


# Classify ground & compare to vendor classification
# TODO: Return and attempt to tune CSF (or other classifiers) to match vendor
# TODO: Use ONLY last return for ground classification

#las_gnd <- classify_ground(las, algorithm = csf())
#csf_gnd <- filter_poi(las_gnd, Classification == 2L)
#vnd_gnd <- filter_poi(las, Classification == 2L)
#plot(csf_gnd)
#plot(vnd_gnd)

# Filter to only ground points
gnd <- filter_poi(las, Classification == 2L)

# Generate the DTM
dem <- rasterize_terrain(gnd, res = 0.5, algorithm = tin())
nlas <- las - dem

# TODO: Compare the DEM to an aerial photo

plot(dem)
plot_dtm3d(dem, bg = "white") 
plot(nlas)
plot(las)


# Building Footprint Identification ---------------------------------------


# 1) Filter down our point cloud
# We **don't** use ReturnNumber == 1 as we might filter out occluded buildings

nlas_filter <- filter_poi(nlas, Z >= 2, Classification == 6)

# TODO: Figure out how we can use NumberOfReturns & ReturnNumber for:
#         a) DEM creation
#         b) Building identification (clean up the point cloud (?))
#         c) Powerline filtering
#nlas_test <- filter_poi(nlas, ReturnNumber != NumberOfReturns)


# 2) Cluster point cloud based on proximity
# TODO: Optimize dbscan parameters

df <- data.frame(nlas_filter$X, nlas_filter$Y)
dbscan_res <- dbscan(df, eps=1, minPts = 20)

nlas_filter@data$ClusterID <- dbscan_res$cluster
las_clusters <- filter_poi(nlas_filter, ClusterID > 0)

plot(las_clusters, color = "ClusterID")


# 3) Wrap each cluster with a concave hull
# TODO: Bump up tightness to get better wrapped angles
#       AKA solve hull for minimum area full encasement

bldg_hulls <- st_sfc(crs = 6653)
for (id in unique(las_clusters$ClusterID)) {
  building <- filter_poi(nlas_filter, ClusterID == id)
  bldg_hull <- st_convex_hull(building)
  bldg_hulls <- c(bldg_hulls, bldg_hull)
}

plot(bldg_hulls)

# Filter out polygons w/ less than 20m of area
buff_size <- 0.5
fp_filtered <- bldg_hulls[(st_area(bldg_hulls) >= units::set_units(20, m^2))] %>% # Require >= 20m^2 of area
  st_buffer(-1 * buff_size) %>% # Reduce area by 0.5m
  st_buffer(buff_size) # Increase area by 0.5m


# TODO: Can we use coplanarity to identify each roof panel?
# TODO: Implement Toula's least squares operations


# Export Topological Datasets ---------------------------------------------

# Write to file
st_write(res_b, 'output/footprint/5255C/5255C.shp')

dsm <- rasterize_canopy(las, res = 0.5, algorithm = p2r(0.2, na.fill = tin()))
writeRaster(dsm, 'output/DSM/POC.tif', overwrite=TRUE)
plot(dsm)






