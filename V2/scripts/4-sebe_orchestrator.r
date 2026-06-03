library(stringr)
library(jsonlite)
library(fs)
library(processx)

# args <- commandArgs(trailingOnly = TRUE)
# wd <- args[1]

wd <- "/app/data/Scratch/SEBE/1"

config <- fromJSON("config.json")

# TODO: Account for current grid tile
dsm_path <- path(wd, "dsm.tif")
chm_path <- path(wd, "chm.tif")

irr_out_path <- path(wd, "irr.tif")
out_dir <- path(wd)

met_data <- path("/app/data/Input/Weather/metprocessor-output-kamloops-a.txt")

# Directories from host machine
data_dir <- "C:/Users/Tyler/Desktop/PV"
model_dir <- "C:/Users/Tyler/Documents/Documents/Dev/kamloops-solar/V2"
# What those dirs look like *inside* the container
data_dir_ct <- "/data"
model_dir_ct <- "/model"

wd_ct <- "/data/Scratch/SEBE/1"
met_data_ct <- "/data/Input/Weather/metprocessor-output-kamloops-a.txt"
irr_out_path_ct <- "/data/Scratch/SEBE/1/irr_test.tif"

result <- run(
  command = "docker",
  args = c(
    "run", "--rm",
    "-v", str_glue("{data_dir}:{data_dir_ct}"),
    "-v", str_glue("{model_dir}:{model_dir_ct}"),
    "qgis:latest",
    "qgis_process",
    "run",
    "/model/calculate-insolation.model3",
    "--",
    str_glue("building__ground_dsm={wd_ct}/dsm.tif"),
    str_glue("vegetation_dsm={wd_ct}/chm.tif"),
    str_glue("meteorological_data_umeped={met_data_ct}"),
    str_glue("outputdir={wd_ct}"),
    str_glue("Rooftopirradiance={irr_out_path_ct}")
  ),
  echo = TRUE,
  echo_cmd = TRUE,
  spinner = TRUE,
  error_on_status = FALSE
)


# result <- run(
#   command = path("C:\\GIS\\OSGeo4W\\bin\\qgis_process-qgis-ltr.bat"),
#   args = c(
#     "run",
#     path_abs("V2/calculate-insolation.model3"),
#     "--",
#     str_glue("building__ground_dsm={dsm_path}"),
#     str_glue("vegetation_dsm={chm_path}"),
#     # TODO: This should require the data to UMEP'd. Expect TMY
#     str_glue("meteorological_data_umeped={met_data}"),
#     str_glue("outputdir={out_dir}"),
#     str_glue("Rooftopirradiance={irr_out_path}")
#   ),
#   echo = TRUE,
#   echo_cmd = TRUE,
#   spinner = TRUE,
#   error_on_status = FALSE
# )

# GENERIC ERR FROM CLAUDE -> Write some better handling...
if (result$status != 0) {
  message("Model failed:\n", result$stderr)
} else {
  message("Model succeeded")
}
