# Open Source Solar Insolation Evaluation

This repository houses the code written for my capstone project. The project's goal was to develop an open-source workflow for evaluating the solar insolation potential of rooftops across British Columbia, using Kamloops as a case study. The workflow can be summarized in 4 (non-linear) steps:

0. Data acquisition and cleaning
1. Building identification
2. Annual solar irradiation modelling
3. Suitability criteria analysis

The workflow stitches together analysis using a series of open-source technologies, including QGIS, UMEP, and `lidR`, to generate a pipeline able to iteratively transform data towards outputs. The iterative process enables better iteration & error management while additionally enabling a natural way to separate the scripts.

The project has not yet concluded, and as such there's not yet a full open-source workflow available for broader application across British Columbia. Keep an eye out, as I'll be updating this repository constantly and releasing it soon!