# Project Roadmap

## The Docket

1. Polish
    - [ ] Convert aspect to sin / cos
        - https://setosa.io/ev/sine-and-cosine/
    - [ ] Stitching logic
    - [ ] Chunking alignment
    - [ ] Merging tiles
    - [ ] Consistent logging
    - [ ] Rooftop segmentation improvements
        - [ ] Parallel execution
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