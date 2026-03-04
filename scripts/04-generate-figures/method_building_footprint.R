library(tidyverse)
library(terra)
library(lidR)
library(sf)


# Setup -------------------------------------------------------------------


# Directories for data that will be used
TILE <- "5255C.las"

LAS_DIR <- 'D:/Dev/Geomatics/kamloops-solar/data/las/clean'
GEO_DIR <- 'D:/Dev/Geomatics/kamloops-solar/output/01-base-geospatial/DOWNTOWN/'
NORM_DIR <- 'D:/Dev/Geomatics/kamloops-solar/scratch/normalized_las/DOWNTOWN/normalized'
INS_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/02-insolation/"
# INS_DIR<- "D:/Dev/Geomatics/kamloops-solar/output/to_delete/results/Downtown/"

ACCEPTED <- "D:/Dev/Geomatics/kamloops-solar/output/03-stats-and-figures/Downtown/accepted_rooftop_irradiance.tif"

ORTHO_PATH <- "D:/Dev/Geomatics/kamloops-solar/data/orthophoto/5255C.tif"
BOUNDARY_PATH <- "D:/Dev/Geomatics/kamloops-solar/scratch/figure_extent.gpkg"
CSV_PATH <- "D:/Dev/Geomatics/kamloops-solar/scratch/nbhd_tile_overlap.csv"


ortho <- rast("D:/Dev/Geomatics/kamloops-solar/data/orthophoto/5255C.tif")
plotRGB(ortho)

# Read in our boundary file
boundary <- st_read(BOUNDARY_PATH)


# Footprint Filtering Process ---------------------------------------------


# 0. Setup

downtown_tiles <- read_csv(CSV_PATH, col_names=F) %>% filter(X1 == "DOWNTOWN")

# 1. Base LAS Data

cat <- readLAScatalog(paste0(LAS_DIR, '/' , downtown_tiles[[2]], '.las'))
las <- clip_roi(cat, boundary)

plot(las, bg='white')

plot(las, bg='white', color='Classification')

las_rast <- rasterize_canopy(las, 0.1, algorithm = dsmtin()) 
plot(las_rast)

# 2. Normalized LAS Data

ncat <- readLAScatalog(NORM_DIR)
nlas <- clip_roi(ncat, boundary)

plot(nlas, bg='white')

nlas_rast <- rasterize_canopy(nlas, 0.1, algorithm = dsmtin()) 
plot(nlas_rast)

# 3. Filtered building point data (above 2.5m)

nlas_f1 <- filter_poi(nlas, (Classification == 2 | Classification == 6))

bldg_grnd_rast <- rasterize_canopy(nlas_f1, 0.1, algorithm = dsmtin()) 
plot(bldg_grnd_rast)

# TODO: Switch to ground OR (building > 2.5m), should fix 
nlas_f2 <- filter_poi(nlas, Classification == 2 | (Classification == 6 & Z > 2.5))

bldg_rast <- rasterize_canopy(nlas_f2, 0.1, algorithm = dsmtin()) 
plot(bldg_rast)

# 4. Building footprint as a raster

nlas_f <- filter_poi(nlas, (Classification == 6 & Z > 2.5))
rooftops <- rasterize_canopy(nlas_f, 2, algorithm = p2r(0.2))
rooftop_poly <- as.polygons(rooftops > 0)



# Now make it into a plot
par(mfrow = c(2, 2))

plot(las_rast)
plot(bldg_rast)
plot(rooftops)

plotRGB(ortho)
plot(rooftop_poly, add=TRUE, border='#FF8800', lwd=3)




# Making data for SEBE ----------------------------------------------------


# Ortho photo of the area
ortho <- rast(ORTHO_PATH) %>% mask(boundary) %>% crop(boundary)
plotRGB(ortho)
writeRaster(ortho, 'D:/Dev/Geomatics/kamloops-solar/scratch/ortho.tif')

# DSM of the area 
dsm <- rast(paste0(GEO_DIR, 'DOWNTOWN-DSM.tif', sep='')) %>%
  mask(boundary) %>% crop(boundary)
plot(dsm)

# CHM of the area 
chm <- rast(paste0(GEO_DIR, 'DOWNTOWN-CHM.tif', sep='')) %>%
  mask(boundary) %>% crop(boundary)
plot(chm)

# Insolation for the area
irr <- rast(paste0(INS_DIR, 'irradiance.tif', sep='')) %>%
  mask(boundary) %>% crop(boundary)
plot(irr)



# 1. Overlay building footprints on top of NBHD

# 2. Overlay suitable pixels on top of NBHD

fp <- st_read(paste0(GEO_DIR, 'DOWNTOWN-FP.gpkg', sep='')) %>% st_crop(boundary)
px <- rast(ACCEPTED) %>% mask(boundary) %>% crop(boundary)
px_pg <- (px > 0) %>% as.polygons(aggregate=TRUE) %>% st_as_sf()

FIG_DIR <- "D:/Dev/Geomatics/kamloops-solar/assets/figures/"


png(paste0(FIG_DIR, 'accepted-overlay.png', sep=''), width = 800, height = 800, res = 150)
plotRGB(ortho)
plot(boundary, add=TRUE, col=adjustcolor("black", alpha.f=0.5))
plot(fp, add=TRUE, col=adjustcolor("blue", alpha.f = 0.7))
plot(px_pg, add=TRUE, col=adjustcolor("yellow", alpha.f = 0.7))
dev.off()

png(paste0(FIG_DIR, 'site.png', sep=''), width = 800, height = 800, res = 150)
plotRGB(ortho)
dev.off()

# 3. Close the device (CRITICAL step to write the file)

# 3. Plot the irradiance
ins <- rast(paste0(INS_DIR, 'DOWNTOWN.tif', sep=''))  %>% mask(boundary) %>% crop(boundary)
solar_cols <- colorRampPalette(c("blue", "green", "yellow", "red"))(100)
plot(ins, 
     col = solar_cols,
     plg = list(loc = "bottom", title = "Solar Irradiance"), # Legend to bottom
     pax = list(side = 1:4, tick = FALSE, labels = TRUE),    # Remove ticks, keep labels
     mar = c(4, 3, 2, 2))


plot(ins)






