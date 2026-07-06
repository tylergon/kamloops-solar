library(stringr)
library(jsonlite)
library(fs)
library(processx)

config <- read_json("config.json")

# ARG1: Working directory
args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

# Input
met_path <- fs::path(config$input_dir, "metprocessor-output.txt")
dsm_path <- fs::path(wd, "dsm.tif")
chm_path <- fs::path(wd, "chm.tif")

# Model
model <- fs::path(config$project_dir, "src/calculate-insolation.model3")

result <- run(
  command = "qgis_process",
  args = c(
    "run",
    model,
    "--verbose",
    "--",
    str_glue("building__ground_dsm={dsm_path}"),
    str_glue("vegetation_dsm={chm_path}"),
    str_glue("meteorological_data_umeped={met_path}"),
    str_glue("outputdir={wd}")
  ),
  env = c(Sys.getenv(), QT_QPA_PLATFORM = "offscreen"),
  echo = FALSE,
  echo_cmd = TRUE,
  spinner = FALSE,
  stdout = "|",
  stderr = "|",
  error_on_status = FALSE
)

# TODO: Unified logging...
cat(result$stdout)
cat(result$stderr)

irr_written <- file.exists(file.path(wd, "Energyyearroof.tif")) &&
               file.info(file.path(wd, "Energyyearroof.tif"))$size > 10000

# TODO: Unified logging...
if (!irr_written) {
  message("\n\n>>> SEBE::FAIL\n\n",  result$stderr)
} else {
  message("\n\n>>> SEBE::SUCCESS ~ {wd}\n\n")
}
