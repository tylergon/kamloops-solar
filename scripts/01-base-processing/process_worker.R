library('tidyverse', quietly=TRUE, warn.conflicts=FALSE)
library("lidR")
library("sf")
library("terra")

out_prefix <- '[WORKER]'
indent <- '        '

# Read out data
instructions <- read_csv('temp/current_tile.csv')

# Parse the current neighbourhood & target tiles
nbhd <- instructions[1,]$neighbourhood
tiles <- str_split_1(instructions[1,]$tiles, ',')

# Print out confirmation we received instructions
cat(out_prefix, 'INSTRUCTIONS RECEIVED -', nbhd, '\n')
for (i in 1:length(tiles)) {
  cat(indent, tiles[i], '\n')
}

# Set up important directory information

data_dir <- "C:/Users/tyler/Documents/LiDAR/Data/main"
out_dir <- "D:/Dev/Geomatics/kamloops-solar/output/batch"
temp_dir <- paste0("D:/Dev/Geomatics/kamloops-solar/output/temp/", nbhd)
norm_dir <- paste0(temp_dir, '/normalized')

dir.create(temp_dir)
dir.create(norm_dir)


# A bunch of configuration ------------------------------------------------


# CRS of our LAS data
crs_out <- 26910
crs_str <- paste('EPSG:', crs_out, sep='')

# Spatial resolution of our analysis & outputs
sr <- 2

# Buffer size to filter out thin channels
buff_size <- 0.5

# Minimum building size to consider
min_area <- units::set_units(75, m^2)

# Read our target LAS tiles into a catalogue
trg_tiles <- paste0(data_dir, '/' , tiles, '.las')
ctg <- readLAScatalog(trg_tiles)


# Normalize Point Cloud ---------------------------------------------------


# Generate a DEM of the study area
dem <- rasterize_terrain(ctg, sr, tin())

# Save the DEM
crs(dem) <- crs_str
writeRaster(dem, paste(out_dir, '/', nbhd, '-DEM.tif', sep=''), overwrite=TRUE)

# Set up the output for the normalized point clouds

opt_output_files(ctg) <- paste(norm_dir, "/norm_{ID}", sep='')
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE

# Normalize the point cloud
normalize_height(ctg, dem)


# Building Footprints -----------------------------------------------------


# Catalog for identifying building footprints
ctg_norm <- readLAScatalog(norm_dir)

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
st_write(bldg_fp, paste0(out_dir, '/', nbhd, '-FP.gpkg', sep=''), delete_dsn=TRUE)


# Building DSM ------------------------------------------------------------


# Fresh catalog for building DSM
ctg <- readLAScatalog(trg_tiles)
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
writeRaster(result, paste0(out_dir, '/', nbhd, '-DSM.tif', sep=''), overwrite=TRUE)


# Canopy Height Model -----------------------------------------------------


# Fresh catalog for CHM
ctg <- readLAScatalog(norm_dir)
ctg@output_options$drivers$SpatRaster$param$overwrite <- TRUE
opt_filter(ctg) <- '-keep_class 3 5 -drop_z_below 1'

# Create a DSM of just the vegetation layer & write it out
dsm_veg <- rasterize_canopy(ctg, res=sr, p2r(0.2)) %>% 
  replace(is.na(.), 0)

crs(dsm_veg) <- crs_str
writeRaster(dsm_veg, paste0(out_dir, '/', nbhd, '-CHM.tif', sep=''), overwrite=TRUE)











