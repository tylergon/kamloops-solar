# kamloops-solar
My project repository for mapping Kamloops' rooftop solar potential

**Current Workflow**

*Identifying Building Footprints*

1. Create a DEM and DSM from the point cloud.

        I'm using the lidR package (lastools requires $$$)
        Requires the lidRviewer package for visualizations at first.

        Ideally we'd be classifying the ground points THEN generating a DTM with those points (w/ TIN)


