library("tidyverse")
library("lidR")
library("sf")
library("terra")
library("RCSF")
library("dbscan")


# Roadmap -----------------------------------------------------------------


# TODO: Set up the workflow to use LAS Catalogues.
# TODO: Setup a squaring algorithm for buildings (minimal gain)
# TODO: Export vegetation DEM
#       Explore further UMEP parameterization.
# TODO: Explore coplanairty & its usefulness
# TODO: Explore orthophotos to identify irregularities

# Stretch goals...
# 1.  Explore process w/o vendor classification


# Setup -------------------------------------------------------------------


trg_crs <- 6653

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

# Plot the imagery & footprints to show our goal
plotRGB(rgb)
plot(fp, border='green', lwd = 1.5, add=TRUE)

# Save the cropped aerial photography & footprints
# writeRaster(rgb, 'output/POC/ortho.tif', overwrite=TRUE)
# st_write(fp, 'output/POC/footprint-gt.gpkg', overwrite=TRUE)


# Topographic Models ------------------------------------------------------


# Use vendor ground classification to generate a DEM
gnd <- filter_poi(las, Classification == 2L)
dem <- rasterize_terrain(gnd, res = 0.5, algorithm = tin())
plot(dem)

# Normalize the point cloud
nlas <- las - dem

# Deprecated Workflow: Manual ground classification

#las_gnd <- classify_ground(las, algorithm = csf())
#csf_gnd <- filter_poi(las_gnd, Classification == 2L)
#vnd_gnd <- filter_poi(las, Classification == 2L)
#plot(csf_gnd)
#plot(vnd_gnd)


# Building Footprint Identification ---------------------------------------


# Filter down to building points
nlas_filter <- filter_poi(nlas, Z >= 2.5, Classification == 6)

# Rasterize our filtered & normalized LAS to get a map of roof locations
ndsm <- rasterize_canopy(nlas_filter, res = 0.5, algorithm = p2r()) # p2r doesn't fill
bldg_poly <- as.polygons(ndsm > 0) %>% st_as_sf() # polygonize the buildings

# Filter our buildings under 75 m2 of area
min_area <- 75
bldg_tmp <- bldg_poly[(st_area(bldg_poly) >= units::set_units(min_area, m^2))]

# Apply a two step buffer to filter out narrow channels
buff_size <- 0.5
bldg_fp <- bldg_tmp %>% st_buffer(-1 * buff_size) %>% st_buffer(buff_size)

# Validate our results
plotRGB(rgb)
plot(bldg_poly, border='green', col=NA, lwd = 1.5, add=TRUE)

# Save building footprints
st_write(bldg_fp, 'output/POC/bldg_fp.gpkg', delete_dsn=TRUE)


# Deprecated Method: Point cloud based identification using clustering,
#                    proximity, and hulls

# nlas_filter <- filter_poi(nlas, Z >= 2.5, Classification == 6)
# 
# # Use dbscan to identify clusters of points
# df <- data.frame(nlas_filter$X, nlas_filter$Y)
# dbscan_res <- dbscan(df, eps=0.75, minPts = 20)
# 
# # Save the results of dbscan and visualize results
# nlas_filter@data$ClusterID <- dbscan_res$cluster
# las_clusters <- filter_poi(nlas_filter, ClusterID > 0)
# plot(las_clusters, color = "ClusterID")
# 
# # Set up sf collections to save results
# bldg_locations <- st_sfc(crs=trg_crs)
# bldg_hulls <- st_sfc(crs=trg_crs)
# 
# # Loop through clusters to construct footprints
# for (id in unique(las_clusters$ClusterID)) {
#   bldg <- filter_poi(nlas_filter, ClusterID == id)
#   
#   # Pare down the point cloud data & drop the Z dimension
#   point_feature <- st_as_sf(bldg) %>% 
#     select(ClusterID, geometry) %>% 
#     st_zm()
#   
#   # Average the points' X and Y locations to get a centre of mass (testing only)
#   point_location <- st_sf(ID = id, geometry = st_sfc(st_point(c(mean(bldg$X), mean(bldg$Y))), crs=6653))
#   bldg_locations <- rbind(bldg_locations, point_location)
#   
#   # Wrap the building with a hull
#   bldg_hull <- point_feature %>% st_union() %>% st_concave_hull(ratio = 0.1)
#   bldg_hulls <- c(bldg_hulls, bldg_hull)
# }
# 
# # Filter out small buildings & apply 2 step buffer to remove thin channels
# buff_size <- 0.5
# fp_filtered <- bldg_hulls[(st_area(bldg_hulls) >= units::set_units(75, m^2))] %>% # Require >= 20m^2 of area
#   st_buffer(-1 * buff_size) %>% # Reduce area by 0.5m
#   st_buffer(buff_size) # Increase area by 0.5m
# plot(fp_filtered)
# 
# # Write out the results
# st_write(bldg_hulls, 'output/POC/bldg_hulls.gpkg', delete_dsn=TRUE)


# For our powerline identification, we'll be using eigen_values to identify
# linear-ish points between the elevation of 4 to 20 m of elevation. Additionally,
# we'll be de-noising upon the removal of these points to ensure extraneous points
# are not missed (?)


# Identify Powerlines -----------------------------------------------------


is_linear <- function (data, th1, th2) {
  return (data$eigen_largest > data$eigen_medium * th1 &
            data$eigen_largest > data$eigen_smallest * th2)
}

las_abv_2 <- filter_poi(las, Z > 2)
las_rest <- filter_poi(las, Z <= 2)

# Calculate eigenvalues using the knn and radius options
ev_lg <- point_eigenvalues(las_abv_2, r = 0.7)
ev_sm <- point_eigenvalues(las_abv_2, r = 0.3)

# Remove linear points
powerlines <- las_abv_2@data$Classification == 0 & las_abv_2$Z >= 3.5 & las_abv_2$Z < 20 &
  (is_linear(ev_sm, 5, 5) | is_linear(ev_lg, 5, 5))

# Filter out points that match powerline criteria
las_pl <- add_attribute(las_abv_2, powerlines, "is_pl") %>% 
  filter_poi(is_pl == FALSE) %>% 
  remove_lasattribute('is_pl')

# Remove high noise points & drop the 
result <- classify_noise(las_pl, sor(15,7)) %>%  # TODO: Why these params?
  filter_poi(Classification != 18)

# Stitch the LAS back together
las_res <- rbind(las_rest, result)


# # Attempt round 2
# ev_r2 <- point_eigenvalues(las_pl, r = 0.3)
# pl_r2 <- las_pl@data$Classification == 0 & las_pl$Z >= 3.5 & las_pl$Z < 20 &
#   (is_linear(ev_r2, 5, 5))
# ls_r2 <- add_attribute(las_pl, pl_r2, "is_pl")
# plot(ls_r2, color='is_pl')




# Export datasets for UMEP ------------------------------------------------


# Create a DSM of the LAS w/o powerlines
dsm <- rasterize_canopy(las_res, res = 0.5, algorithm = p2r(0.2, na.fill = tin()))
writeRaster(dsm, 'output/POC/dsm.tif', overwrite=TRUE)

# Create a DSM of the vegetation
las_veg <- filter_poi(las, Classification == 3 | Classification == 5)
dsm_veg <- rasterize_canopy(las_veg, res=0.5, p2r(0.2))
writeRaster(dsm_veg, 'output/POC/dsm_veg.tif', overwrite=TRUE)

plot(dsm)







