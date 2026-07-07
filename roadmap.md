# Project Roadmap

## The Docket

1. Polish

    - [ ] Extract generalizable logic into utils.r -> source("src/utils.r")
    - [ ] Stitching logic
    - [ ] Chunking alignment
    - [ ] Merging tiles
    - [ ] Consistent logging
    - [ ] Rooftop segmentation improvements
        - [x] Convert aspect to normalized vectors
            - https://setosa.io/ev/sine-and-cosine/
            - https://cartographicperspectives.org/index.php/journal/article/view/1669/1947
        - [x] Parallel execution
        - [ ] Include proximity?
        - [ ] Better understanding of edge cases
            1. No features are in the area
            2. Single column / row. Can we 
        - [ ] Scaling(?)
        - [ ] Output as polygons
    - [ ] Use segments in locating suitable areas
    - [ ] All datasets should be aligned in extent... But this isn't always possible at the extremities I suppose? Think about it...


## Additional Features

- [ ] Refactor flow to chunk first, performing all operations in tiles.
- [ ] Play with hyperparameters
    - [ ] `2-buildings.r` - p2r
    - [ ] `6-segment.r` - DBSCAN
    - [ ] Bins for DBSCAN and suitability analysis
- [ ] Explore alternatives to moving window. TIN interpolation?
- [ ] Cleaner method of aligning SEBE input raster extents?

## Discussion Topics for Greg

- Parallelizing DBSCAN. How do we feel about the current method.