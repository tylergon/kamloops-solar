library(tidyverse)
library(jsonlite)
library(fs)
library(processx)

# args <- commandArgs(trailingOnly = TRUE)
# wd <- args[1]

wd <- "C:/Users/Tyler/Desktop/PV/Scratch/SEBE/1"

config <- fromJSON("config.json")

# TODO: Account for current grid tile
dsm_path <- path(wd, "dsm.tif")
chm_path <- path(wd, "chm.tif")

irr_out_path <- path(wd, "irr.tif")
out_dir <- path(wd)

# model_path <- path_abs("V2/calculate-insolation.model3")


# TODO: This doesn't live here...
# qgis_bat_path <- path("C:/GIS/OSGeo4W/bin/python-qgis.bat")


met_data <- path("C:/Users/Tyler/Desktop/PV/Input/Weather/metprocessor-output-kamloops-a.txt")


result <- run(
  command = path("C:\\GIS\\OSGeo4W\\bin\\qgis_process-qgis-ltr.bat"),
  args = c(
    "run",
    path_abs("V2/calculate-insolation.model3"),
    "--",
    str_glue("building__ground_dsm={dsm_path}"),
    str_glue("vegetation_dsm={chm_path}"),
    # TODO: This should require the data to UMEP'd. Expect TMY
    str_glue("meteorological_data_umeped={met_data}"),
    str_glue("outputdir={out_dir}"),
    str_glue("Rooftopirradiance={irr_out_path}")
  ),
  echo = TRUE,
  echo_cmd = TRUE,
  spinner = TRUE,
  error_on_status = FALSE
)

# GENERIC ERR FROM CLAUDE -> Write some better handling...
if (result$status != 0) {
  message("Model failed:\n", result$stderr)
} else {
  message("Model succeeded")
}
