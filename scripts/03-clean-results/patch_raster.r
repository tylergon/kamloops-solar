library(snakecase)
library(tidyverse)
library(terra)
library(sf)

IN_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/results/"
OUT_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/results/"
NBHD_INFO <- "D:/Dev/Geomatics/kamloops-solar/data/Neighbourhoods/Neighbourhood.shp"

# Fetch the neighbourhood list
nbhds <- read_sf(NBHD_INFO)


nbhd_paths <- paste0(IN_DIR, to_upper_camel_case(nbhds$NAME), '/', sep='')


# SAVE IRRADIANCE AS BIG TIF
irradiance_paths <- paste0(nbhd_paths, 'irradiance.tif')
irradiance_sprc <- sprc(irradiance_paths)
irradiance_mosaic <- mosaic(irradiance_sprc, fun='mean')
writeRaster(irradiance_mosaic, paste0(OUT_DIR, '/irradiance.tif', sep=''))

# SAVE DEM AS BIG TIF
accepted_rooftop_irradiance_paths <- paste0(nbhd_paths, 'accepted_rooftop_irradiance.tif')
accepted_rooftop_irradiance_sprc <- sprc(accepted_rooftop_irradiance_paths)
accepted_rooftop_irradiance_mosaic <- mosaic(accepted_rooftop_irradiance_sprc, fun='mean')
writeRaster(accepted_rooftop_irradiance_mosaic, paste0(OUT_DIR, '/accepted_rooftop_irradiance.tif', sep=''))


# SAVE DEM AS BIG TIF
dem_paths <- paste0(nbhd_paths, 'dem.tif')
dem_sprc <- sprc(dem_paths)
dem_mosaic <- mosaic(dem_sprc, fun='mean')
writeRaster(dem_mosaic, paste0(OUT_DIR, '/dem.tif', sep=''))

# SAVE FPs AS BIG TIF
fp_paths <- paste0(nbhd_paths, 'fp.gpkg')
fp_collection <- lapply(fp_paths, function (x) (st_read(x))) %>% bind_rows()
st_write(fp_collection, paste0(OUT_DIR, '/fp.gpkg'))





