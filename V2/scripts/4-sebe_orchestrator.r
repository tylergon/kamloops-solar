library(tidyverse)
library(jsonlite)
library(fs)
library(processx)

config <- fromJSON("config.json")

# TODO: Account for current grid tile
dsm_path <- path(config$scratch_dir, "dsm.tif")
chm_path <- path(config$scratch_dir, "chm.tif")

irr_out_path <- path(config$scratch_dir, "irr.tif")
out_dir <- path(config$scratch_dir)

model_path <- path_abs("V2/calculate-insolation.model3")

# TODO: This doesn't live here...
qgis_bat_path <- path("C:\\GIS\\OSGeo4W\\bin\\qgis_process-qgis.bat")


result <- run(
  command = qgis_bat_path,
  args = c(
    "run",
    model_path,
    "--",
    str_glue("building__ground_dsm={dsm_path}"),
    str_glue("vegetation_dsm={chm_path}"),
    # TODO: This should require the data to UMEP'd. Expect TMY
    str_glue("meteorological_data_umeped={METEOROLOGICAL_DATA}"),
    str_glue("Outputdir={out_dir}"),
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
