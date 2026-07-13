# Project Roadmap

## The Docket

1. Polish

    - [x] Rooftop segmentation improvements
        - [x] Convert aspect to normalized vectors
            - https://setosa.io/ev/sine-and-cosine/
            - https://cartographicperspectives.org/index.php/journal/article/view/1669/1947
        - [x] Parallel execution
        - [x] Better segmentation! (i.e. tune hyperparameters)
        - [ ] Better understanding of edge cases
            1. No features are in the area
            2. Single column / row. Can we 
        - [x] Output as polygons
    
    - [x] Logging: We need consistent logging throughout the project to keep track of the runtime as we go through ALL of Kamloops.

    - [ ] Chunking: Tiles need to be consistently chunked & it needs to be possible to remove the buffer to enable non-average based stitching.

    - [ ] Use segments in locating suitable areas
    - [ ] Move window filling algorithm into SEBE -> It's not necessary elsewhere. Same w/ CHM

## Additional Features

- [ ] !!! Investigate binning logic & POA irradiance
- [ ] !! Identify rooftops using height above ground + normals clustering
- [ ] !! Include edge to area metrics
- [ ] ! Play with `2-buildings.r` hyperparameters
- [ ] ! Cleaner method of aligning SEBE input raster extents?
- [ ] ! Explore alternatives to moving window. TIN interpolation?
- [ ] Can loaded libraries be shared b/w orchestrate.r & children?
- [ ] Extract generalizable logic into utils.r -> source("src/utils.r")
- [ ] Could smoothing help?

## Discussion Topics for Greg

- Parallelizing DBSCAN. How do we feel about the current method.