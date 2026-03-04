library("tidyverse")
library("lidR")
library("sf")
library("terra")

# Directories
data_dir <- "data/LiDAR/test-0"
out_dir <- "output/test-01"

# CRS of our LAS data
crs_out <- 26910
crs_str <- paste('EPSG:', crs_out, sep='')

# Spatial resolution of our analysis & outputs
sr <- 2

# Buffer size to filter out thin channels
buff_size <- 0.5

# Minimum building size to consider
min_area <- units::set_units(75, m^2)


# Normalize Point Cloud ---------------------------------------------------


# Catalog for normalizing the point cloud
ctg <- readLAScatalog(paste(data_dir, '/source', sep=''))

# Generate a DEM of the study area
dem <- rasterize_terrain(ctg, sr, tin())

# Save the DEM
crs(dem) <- crs_str
writeRaster(dem, paste(out_dir, '/kamloops-dem.tif', sep=''), overwrite=TRUE)

# Set up the output for the normalized point clouds
opt_output_files(ctg) <- paste(data_dir, "/normalized/norm_{ID}", sep='')
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Normalize the point cloud
normalize_height(ctg, dem)


# Building Footprints -----------------------------------------------------


# Catalog for identifying building footprints
ctg_norm <- readLAScatalog(paste(data_dir, "/normalized", sep=''))

# Filter down to buildings & points above 2m
opt_filter(ctg_norm) <- '-keep_class 6 -drop_z_below 2.5'
ctg_norm@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Create raster of our normalized, filtered point cloud to map rooftops
#   note: p2r doesn't fill gaps between houses
rooftops <- rasterize_canopy(ctg_norm, sr, algorithm = p2r(0.2)) 

# Convert from a Terra raster to sf polygons
bldg_poly <- as.polygons(rooftops > 0) %>%
  st_as_sf() %>% st_set_crs(crs_out) %>%
  # Ensure each identified rooftop is represented with a unique polygon
  st_cast('POLYGON') 

# Filter our buildings under 75 m2 of area
bldg_fp <- bldg_poly %>% filter(st_area(geometry) >= min_area) %>% 
  # Apply a 2 step buffer to filter out narrow channels
  st_buffer(-1 * buff_size) %>% st_buffer(buff_size)

# Write results out
st_write(bldg_fp, paste(out_dir, '/kamloops-fp.gpkg', sep=''), delete_dsn=TRUE)



# Building DSM ------------------------------------------------------------


# Fresh catalog for building DSM
ctg <- readLAScatalog(paste(data_dir, '/source', sep=''))
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE
opt_filter(ctg) <- '-keep_class 2 6'

# Generate a DSM only including buildings
result <- rasterize_canopy(ctg, sr, algorithm = p2r(0.2, na.fill = tin()))

# Fill in NA values
w <- 1
while(global(result, function(x) any(is.na(x)))[,1]) {
  w <- w + 2  
  result <- focal(result, w=w, fun=mean, na.policy="only", na.rm=T)
}

# Write out building DSM
crs(result)="EPSG:26910"
writeRaster(result, paste(out_dir, '/building_dsm.tif', sep=''), overwrite=TRUE)


# Canopy Height Model -----------------------------------------------------


# Fresh catalog for CHM
ctg <- readLAScatalog(paste(data_dir, '/normalized', sep=''))
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE
opt_filter(ctg) <- '-keep_class 3 5 -drop_z_below 1'

# Create a DSM of just the vegetation layer & write it out
dsm_veg <- rasterize_canopy(ctg, res=sr, p2r(0.2)) %>% 
  replace(is.na(.), 0)

crs(dsm_veg) <- crs_str
writeRaster(dsm_veg, paste(out_dir, '/chm.tif', sep=''), overwrite=TRUE)











