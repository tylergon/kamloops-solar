library("tidyverse")
library("lidR")
library("lidRviewer")
library("sf")
library("terra")
library("RCSF")

# -- Basic LAS setup --

las_og <- readLAS("data/LiDAR/5255C/5255C.las", select = "xyzrn")
st_crs(las_og) <- 6653

extent <- st_bbox(las_og)
las <- clip_rectangle(las_og,
                      extent$xmin,
                      extent$ymin,
                      extent$xmin+((extent$xmax - extent$xmin)/2),
                      extent$ymin+((extent$ymax - extent$ymin)/2))


###### AI SUGGESTION ON BETTER CLIPPING ######

# 1. Create a polygon from the bounding box
#bbox_poly <- st_as_sfc(extent)

# 2. Use st_make_grid to split it into 4 equal quadrants (2x2)
#grid <- st_make_grid(bbox_poly, n = c(2, 2))

# 3. Clip using the first quadrant (bottom-left)
#las <- clip_roi(las_og, grid[1])

##############################################


# -- Load Kamloops footprints --

fp_og <- st_read("data/building-footprints.gpkg")
fp_og <- st_transform(fp_og, crs = 6653)


fp <- st_crop(fp_og, st_bbox(las))
fp_geom <- st_geometry(fp)
plot(fp_geom)




# -- Identify & filter out the ground points --

las_gnd <- classify_ground(las, algorithm = csf())
ground <- filter_poi(las_gnd, Classification == 2L)
# plot(ground)

# -- Generate the DTM --

dtm_tin <- rasterize_terrain(ground, res = 1, algorithm = tin())
plot_dtm3d(dtm_tin, bg = "white") 

plot(dtm_tin)






plot(las_grn)
plot(las_grn, color = "Classification")

las_check(las)

plot(las, color = "Classification")
print(las)
