library(snakecase)
library(tidyverse)
library(terra)
library(sf)


# Set up file paths -------------------------------------------------------


cat_fname <- function (path, name) (paste0(path, name, sep=''))

RESULTS_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/results/"
OUT_DIR <- "D:/Dev/Geomatics/kamloops-solar/output/results/"
NBHD_INFO <- "D:/Dev/Geomatics/kamloops-solar/data/Neighbourhoods/Neighbourhood.shp"


# Generate a summary of each neighbourhood --------------------------------

# Read in neighbourhoods & create a path to their results directories
nbhds <- read_sf(NBHD_INFO)
nbhd_paths <- paste0(RESULTS_DIR, to_upper_camel_case(nbhds$NAME), '/', sep='')

# Create file paths for accepted irradiance & footprints
accepted <- lapply(cat_fname(nbhd_paths, 'accepted_rooftop_irradiance.tif'), rast)
footprints <- lapply(cat_fname(nbhd_paths, 'fp.gpkg'), st_read)

# Calculate the average irradiance, total usable area, a cumulative potential
accepted_avg <- sapply(accepted, function (x) global(x, fun="mean", na.rm=TRUE)$mean)
accepted_area <- sapply(accepted, function (x) (global(x>0, fun="sum", na.rm=TRUE)$sum * 4))
summed <- sapply(accepted, function (x) (global(x, fun="sum", na.rm=TRUE)$sum * 4))

# Calculate the total footprint area identified
footprint_area <- sapply(footprints, function (x) (sum(st_area(x))))

# Create a summary table aggregating the data for each neigbhourhood
nbhd_summary <- tibble('Neighbourhood' = to_any_case(nbhds$NAME, case='title'),
                       'Average Annual Irradiance' = accepted_avg,
                       'Accepted Rooftop Area (m^2)' = accepted_area,
                       'Total Identified Rooftop Area (m^2)' = footprint_area,
                       'Neighbourhood Area' = st_area(nbhds)) %>% 
  arrange(Neighbourhood)

# Write out to csv
write_csv(final_table, cat_fname(OUT_DIR, 'summary.csv'))

# Output our results ------------------------------------------------------

print(paste0('Average annual irradiance:', mean(nbhd_summary$`Average Annual Irradiance`)))
print(paste0('Accepted Rooftop Area (m^2):', sum(nbhd_summary$`Accepted Rooftop Area (m^2)`)))
print(paste0('Total Identified Rooftop Area (m^2):', sum(nbhd_summary$`Total Identified Rooftop Area (m^2)`)))
print(paste0('Neighbourhood Area:', sum(nbhd_summary$`Neighbourhood Area`)))




city <- rast("D:/Dev/Geomatics/kamloops-solar/output/to_delete/results/irradiance.tif")
city





sum(nbhd_summary$`Neighbouhood Area`)
