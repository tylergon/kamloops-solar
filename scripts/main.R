library("tidyverse")
library("lidR")
library("sf")
library("terra")

crs <- 6653

# Basic LAS setup
las_init <- readLAScatalog("data/LiDAR/source", select = "xyzrnc")
st_crs(las_init) <- crs

# TODO: Update output paths
# TODO: Run a demo
# TODO: UMEP time baby!


# Topographic Models ------------------------------------------------------


# Use vendor ground classification to generate a DEM
gnd <- filter_poi(las, Classification == 2L)
dem <- rasterize_terrain(gnd, res = 0.5, algorithm = tin())
plot(dem)

# Normalize the point cloud
nlas <- las - dem


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


# Export datasets for UMEP ------------------------------------------------


# Create a DSM of the LAS w/o powerlines
dsm <- rasterize_canopy(las_res, res = 0.5, algorithm = p2r(0.2, na.fill = tin()))
writeRaster(dsm, 'output/POC/dsm.tif', overwrite=TRUE)

# Create a DSM of the vegetation
las_veg <- filter_poi(las, Classification == 3 | Classification == 5)
dsm_veg <- rasterize_canopy(las_veg, res=0.5, p2r(0.2))
writeRaster(dsm_veg, 'output/POC/dsm_veg.tif', overwrite=TRUE)

plot(dsm)







