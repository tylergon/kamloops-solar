library(snakecase)
library(tidyverse)
library(terra)
library(sf)

# Toggle whether the results should be written
write_results <- TRUE

# Input directories
GEO_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/01-base-geospatial/"
IRR_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/02-insolation/"

# Output directory
OUT_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/03-stats-and-figures/"


# Fetch the neighbourhood list
BOUNDARY_DIR <- "D:/Dev/Geomatics/kamloops-solar/data/Neighbourhoods/Neighbourhood.shp"
nbhds <- read_sf(BOUNDARY_DIR)
neighbourhoods <- read_csv('scratch/neighbourhood_tiles_finished.csv')

for (nbhd in neighbourhoods$neighbourhood) {
  # Read relevant files
  irr <- rast(paste0(IRR_DIR, nbhd, '.tif', sep=''))
  dsm <- rast(paste0(GEO_DIR, nbhd, '/', nbhd, '-DSM.tif', sep=''))
  chm <- rast(paste0(GEO_DIR, nbhd, '/', nbhd, '-CHM.tif', sep=''))
  dem <- rast(paste0(GEO_DIR, nbhd, '/', nbhd, '-DEM.tif', sep=''))
  fp <- read_sf(paste0(GEO_DIR, nbhd, '/', nbhd, '-FP.gpkg', sep=''))
  
  # Read in geom & convert it to the correct CRS
  nbhd_geom <- nbhds %>% filter(NAME == nbhd) %>% st_geometry() %>% 
    vect() %>% project(crs(irr))
  
  # Clip raster imagery & footprintsto neighbourhood
  nbhd_irr <- irr %>% mask(nbhd_geom) %>% crop(nbhd_geom)
  nbhd_dsm <- dsm %>% mask(nbhd_geom) %>% crop(nbhd_geom)
  nbhd_chm <- chm %>% mask(nbhd_geom) %>% crop(nbhd_geom)
  nbhd_dem <- dem %>% mask(nbhd_geom) %>% crop(nbhd_geom)
  nbhd_fp <- vect(fp) %>% mask(nbhd_geom) %>% crop(nbhd_geom)
  
  # Build a matrix to reclassify aspect w/
  directions <- matrix(c(0, 45, 1,#N
                         45, 135, 2,#E
                         135, 225, 3,#S
                         225, 315, 4,#W
                         315, 360, 1), ncol=3, byrow = TRUE) #N
  
  # Calculate slope & aspect
  nbhd_slope <- terrain(nbhd_dsm, v="slope", neighbors=8, unit="degrees") # TODO: Should this be calculated only w/ building pixels in?
  nbhd_aspect <- terrain(nbhd_dsm, v="aspect", neighbors=8, unit="degrees") %>% 
    classify(rcl = directions, include.lowest = TRUE, right = TRUE)

  # Mask out values that are not in our building footprints or "quality"
  rooftop_irr <- nbhd_irr %>% 
    mask(nbhd_fp) %>% 
    mask(nbhd_aspect != 1, maskvalues = FALSE) %>% 
    mask(nbhd_slope <= 60, maskvalues = FALSE) %>% 
    mask(nbhd_irr >= 800, maskvalues = FALSE)
  
  # Create the neighbourhood output directory
  NBHD_OUT_DIR <- paste0(OUT_DIR, to_upper_camel_case(nbhd), '/', sep='')
  dir.create(NBHD_OUT_DIR, recursive = TRUE)
  
  # Write out all of the resources
  if (write_results) {
    writeRaster(rooftop_irr, paste0(NBHD_OUT_DIR, 'accepted_rooftop_irradiance.tif'), overwrite=T)
    writeRaster(nbhd_irr, paste0(NBHD_OUT_DIR, 'irradiance.tif'), overwrite=T)
    writeRaster(nbhd_dsm, paste0(NBHD_OUT_DIR, 'dsm.tif'), overwrite=T)
    writeRaster(nbhd_chm, paste0(NBHD_OUT_DIR, 'chm.tif'), overwrite=T)
    writeRaster(nbhd_dem, paste0(NBHD_OUT_DIR, 'dem.tif'), overwrite=T)
    writeVector(nbhd_fp, paste0(NBHD_OUT_DIR, 'fp.gpkg'), overwrite=T)  
  }
}












