library("sf")
library("terra")
 

# TODO: Extract [Aspects, Slopes, Full Buildings, and combinations] as features
#       to enable analysis of each of the traits statistics

# TODO: Polygonize faces w/ matching slope & aspect. Filter out if < 10m^2


# Load data ---------------------------------------------------------------


# TODO: Crop the orthophoto (and other files) to POC boundary.


# Digital surface model of the area
dsm <- rast('output/DSM/POC.tif')
dem <- rast('output/DEM/5255C.tif')

# Annual insolation estimates for the area
insolation <- rast('output/insolation/POC.tif')

# Footprints of the site
footprints <- st_read('output/footprint/5255C/5255C.shp')

# Load in the orthophoto
rgb_photo <- rast("data/Orthophoto/5255C.tif") %>% 
  crop(dsm)

plotRGB(rgb_photo)
plot(st_geometry(footprints), border = 'red', add = TRUE)


# Extract roof level insolation -------------------------------------------


bldg_insolation <- mask(insolation, footprints)
plot(bldg_insolation)

# TODO: Write the output somewhere presumably (?)
# writeRaster(building_insolation)



# Calculate rooftop attributes --------------------------------------------

# TODO: *** Where slope is 0 to 10, create a non-pitched bin for aspect
# TODO: *   Play with the neighbours argument of the terrain function


# Extract rooftops from raster DSM

bldg_surfaces <- mask(dsm, footprints)
plot(bldg_surfaces)

# Calculate & bin slope of rooftops
bldg_slope <- terrain(bldg_surfaces, v="slope", neighbors=8, unit="degrees")
bldg_slope_rcl <- classify(bldg_slope,
                           rcl = matrix(c(0, 10, 1,
                                          10, 20, 2,
                                          20, 30, 3,
                                          30, 40, 4,
                                          40, 50, 5,
                                          50, 60, 6,
                                          60, 90, 4), ncol=3, byrow = TRUE),
                           include.lowest = TRUE,
                           right = TRUE)

plot(bldg_slope_rcl)

# Calculate & bin aspects of rooftops
bldg_aspect <- terrain(bldg_surfaces, v="aspect", neighbors=8, unit="degrees")
bldg_aspect_rcl <- classify(bldg_aspect,
                            rcl = matrix(c(0, 45, 1,#N
                                           45, 135, 2,#E
                                           135, 225, 3,#S
                                           225, 315, 4,#W
                                           315, 360, 1), ncol=3, byrow = TRUE),
                            include.lowest = TRUE,
                            right = TRUE)

plot(bldg_aspect_rcl)



# Build the super raster! -------------------------------------------------


# TODO: Ask Brianne about that last step...


ret <- c(bldg_insolation, bldg_slope, bldg_slope_rcl,
         bldg_aspect, bldg_aspect_rcl,
         rasterize(footprints, bldg_insolation, field = "FID"))

names(ret) <- c("Insolation", "Slope", "Slope Class",
                "Aspect", "Aspect Class", "Building ID")



# Locate the best locations! ----------------------------------------------

# Surfaces must not be facing north
aspect_mask <- bldg_aspect >= 45 & bldg_aspect <= 315
# Surfaces must not have a slope over 60 degrees
slope_mask <- bldg_slope <= 60
# Surfaces must receive a minimum of 800 kWh/m^2
insolation_mask <- bldg_insolation >= 800

# Filter out points NOT matching our predefined filteres
mask <- aspect_mask & slope_mask & insolation_mask
accepted <- mask(bldg_insolation, mask, maskvalues = FALSE)
plot(accepted)



