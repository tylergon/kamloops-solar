This document is just here to help me keep track of how I would like the 
workflow to go for this section. 



1. Break down our area of interest (Kamloops) into tiles.
2. Normalize the point cloud
3. Identify buildings
4. Split out our lil datasets for SEBE
5. Run SEBE

To do each of these steps, lets create a super short **easy to understand**
script. We can orchestrate operations from *another* script, which will be
orchestrated from a script managing the entire AOI.

**BOOM!** Way too much going on :)


### The Docket

- [ ] Fix the CRS errors
- [x] Should I extract grid creation into a script called by the orchestrator?
- [ ] Should we instead be performing input generation, SEBE operation, and result combination in one script?
- [ ] Utility script for file names?
