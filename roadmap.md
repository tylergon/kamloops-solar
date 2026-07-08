# Project Roadmap

## The Docket

1. Polish

    - [ ] Rooftop segmentation improvements
        - [x] Convert aspect to normalized vectors
            - https://setosa.io/ev/sine-and-cosine/
            - https://cartographicperspectives.org/index.php/journal/article/view/1669/1947
        - [x] Parallel execution
        - [ ] Better segmentation! (i.e. tune hyperparameters)
        - [ ] Better understanding of edge cases
            1. No features are in the area
            2. Single column / row. Can we 
        - [ ] Output as polygons
    - [ ] Extract generalizable logic into utils.r -> source("src/utils.r")
    - [ ] Consistent logging
    - [ ] Stitching logic
    - [ ] Chunking alignment
    - [ ] Merging tiles
    - [ ] Use segments in locating suitable areas

## Additional Features

- [ ] !!! Investigate binning logic & POA irradiance
- [ ] !! Identify rooftops using height above ground + normals clustering
- [ ] !! Include edge to area metrics
- [ ] ! Play with `2-buildings.r` hyperparameters
- [ ] ! Cleaner method of aligning SEBE input raster extents?
- [ ] ! Explore alternatives to moving window. TIN interpolation?

## Discussion Topics for Greg

- Parallelizing DBSCAN. How do we feel about the current method.