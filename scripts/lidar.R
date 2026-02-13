library("tidyverse")
library("lidR")
#library("lidRviewer")
library("sf")
library("terra")
library("RCSF")
library("dbscan")

trg_crs <- 6653

# A bunch of stuff to process MORE data...

# cat <- readLAScatalog("C:/Users/tyler/Documents/LiDAR/Data")
# st_crs(cat) <- trg_crs
# plot(cat)
# east <- readLAS("C:/Users/tyler/Documents/LiDAR/Data/5550A.las")
# st_crs(east) <- trg_crs
# las_check(east)
# west <- readLAS("C:/Users/tyler/Documents/LiDAR/Data/5261D.las")
# st_crs(west) <- trg_crs
# writeLAS(east, "C:/Users/tyler/Documents/LiDAR/Test/east.las")
# writeLAS(west, "C:/Users/tyler/Documents/LiDAR/Test/west.las")
# updated_cat <- readLAScatalog("C:/Users/tyler/Documents/LiDAR/Test")
# plot(updated_cat)
# plot(east)
# plot(west)
# plot(cat)
# summary(cat)

# TODO & stuff

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
st_crs(las_init) <- trg_crs

# Load Kamloops footprints
fp_init <- st_read("data/building-footprints.gpkg") %>% 
  st_transform(crs = trg_crs) %>% 
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
#plotRGB(rgb)
#rgb

#writeRaster(rgb, 'output/POC/ortho.tif', overwrite=TRUE)
#st_write(fp, 'output/POC/footprint-gt.gpkg', overwrite=TRUE)


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

writeRaster(dem, 'output/POC/dem.tif', overwrite=TRUE)

# TODO: Compare the DEM to an aerial photo

plot(dem)
plot_dtm3d(dem, bg = "white") 
plot(nlas)
plot(las)


# Building Footprint Identification ---------------------------------------

# For our powerline identification, we'll be using eigen_values to identify
# linear-ish points between the elevation of 4 to 20 m of elevation. Additionally,
# we'll be de-noising upon the removal of these points to ensure extraneous points
# are not missed (?)


# 1) Filter down our point cloud
# We **don't** use ReturnNumber == 1 as we might filter out occluded buildings (?)

# Filter down to building points
nlas_filter <- filter_poi(nlas, Z >= 2.5, Classification == 6)

# Extract HighVeg
las_veg <- filter_poi(nlas, Classification == 5L)



# Identify Powerlines -----------------------------------------------------

# Filter down to points above 2 meters
las_pl <- filter_poi(nlas, Z > 2) 
        # filter_poi(nlas, Classification == 0) 

# Calculate eigenvalues in a 0.5m radius
las_pl_ev <- point_eigenvalues(las_pl, r = 0.5)

# Use JR's method for calculating linearity 
lim <- 2
is_linear_v1 <- las_pl_ev$eigen_largest > las_pl_ev$eigen_medium * lim & las_pl_ev$eigen_largest > las_pl_ev$eigen_smallest * lim

# Use the "typical" calculation for linearity
linearity <- (las_pl_ev$eigen_largest - las_pl_ev$eigen_medium) / las_pl_ev$eigen_largest
is_linear_v2 <- linearity >= 0.8 & las_pl$Z >= 3.5 & las_pl$Z < 20

# Add new linearity attributes to the LAS data

las_pl <- add_attribute(las_pl, is_linear_v1, "is_linear_v1") %>% 
  add_attribute(is_linear_v2, 'is_linear_v2') %>% 
  add_attribute(linearity, 'linearity')
#add_attribute(las_pl_ev$eigen_largest, 'largest')

plot(las_pl, color="is_linear_v1")
plot(las_pl, color="is_linear_v2")

plot(is_p_data, color="is_powerline")

# TODO: Denoise to remove missed points..

tib <- as_tibble(is_p_data@data)
tib[is.na(tib$linearity),]$largest


plot(pl_data, color="is_lin")
plot(pl_data, color="linearity")



lines <- segment_shapes(pl_data, shp_line(k = 5), "line_of_some_sort")
ev

# M1 <- point_metrics(las, ~plane_metrics2(X,Y,Z), k = 25, filter = ~ReturnNumber == 1)

plot(filter_poi(nlas, Classification == 0 & Z > 4))


# i) Create rasters of the nDSM and classification...

ndsm <- rasterize_canopy(nlas_filter, res = 0.5, algorithm = p2r())
writeRaster(ndsm, 'output/POC/ndsm.tif', overwrite=TRUE)

polys <- as.polygons((ndsm > 0))
polys_sf <- st_as_sf(polys)

writeVector(polys, 'output/POC/polys.gpkg', overwrite=TRUE)


buff_size <- 0.5
fp_filt <- polys_sf[(st_area(polys_sf) >= units::set_units(75, m^2))] %>%
  st_buffer(-1 * buff_size) %>% # Reduce area by 0.5m
  st_buffer(buff_size) # Increase area by 0.5m
plot(fp_filt)

st_write(fp_filt, 'output/POC/polys_filt.gpkg', delete_dsn=TRUE)


# TODO: Figure out how we can use NumberOfReturns & ReturnNumber for:
#         a) DEM creation
#         b) Building identification (clean up the point cloud (?))
#         c) Powerline filtering
#nlas_test <- filter_poi(nlas, ReturnNumber != NumberOfReturns)


# 2) Cluster point cloud based on proximity
# TODO: Optimize dbscan parameters

df <- data.frame(nlas_filter$X, nlas_filter$Y)
dbscan_res <- dbscan(df, eps=0.75, minPts = 20)

nlas_filter@data$ClusterID <- dbscan_res$cluster
las_clusters <- filter_poi(nlas_filter, ClusterID > 0)

plot(las_clusters, color = "ClusterID")

# 3) Wrap each cluster with a concave hull
# TODO: Bump up tightness to get better wrapped angles
#       AKA solve hull for minimum area full encasement
# TODO: Improve performance by converting each cluster to a dataset(?)
# TODO: Can we use coplanarity to identify each roof panel?
# TODO: Implement Toula's least squares operations

bldg_points <- st_sfc(crs=trg_crs)
bldg_locations <- st_sfc(crs=trg_crs)
bldg_hulls <- st_sfc(crs=trg_crs)

for (id in unique(las_clusters$ClusterID)) {
  bldg <- filter_poi(nlas_filter, ClusterID == id)
  
  point_feature <- st_as_sf(bldg) %>% 
    select(ClusterID, geometry) %>% 
    st_zm()
  
  # Save building points and approximate building centre
  # Used when testing adjusted dbscan parameters, but otherwise skip
  
  #bldg_points <- rbind(bldg_points, point_feature)
  #point_location <- st_sf(ID = id, geometry = st_sfc(st_point(c(mean(bldg$X), mean(bldg$Y))), crs=6653))
  #bldg_locations <- rbind(bldg_locations, point_location)
  
  # Wrap the building with a hull
  
  bldg_hull <- point_feature %>% st_union() %>% st_concave_hull(ratio = 0.1)
  bldg_hulls <- c(bldg_hulls, bldg_hull)
  
  #NOTE: Concave hulls performs better on general buildings, but not so well
  #      when parts of buildings are obscured due to tree cover.
}

#st_write(bldg_points, 'output/POC/bldg_points.gpkg', delete_dsn=TRUE)
#st_write(bldg_locations, 'output/POC/bldg_locations.gpkg', delete_dsn=TRUE)
st_write(bldg_hulls, 'output/POC/bldg_hulls_0.1.gpkg', delete_dsn=TRUE)

# 4) Filter out polygons w/ less than 20m of area & buffer out channels
buff_size <- 0.5
fp_filtered <- bldg_hulls[(st_area(bldg_hulls) >= units::set_units(75, m^2))] %>% # Require >= 20m^2 of area
  st_buffer(-1 * buff_size) %>% # Reduce area by 0.5m
  st_buffer(buff_size) # Increase area by 0.5m
plot(fp_filtered)


# Export Topological Datasets ---------------------------------------------

#dsm <- rasterize_canopy(las, res = 0.5, algorithm = p2r(0.2, na.fill = tin()))
#writeRaster(dsm, 'output/POC/dsm.tif', overwrite=TRUE)
st_write(fp_filtered, 'output/POC/footprint-concave.gpkg', delete_dsn=TRUE)






