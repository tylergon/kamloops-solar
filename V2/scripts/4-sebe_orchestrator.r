library(stringr)
library(jsonlite)
library(fs)
library(processx)

args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

message(str_glue(">>> SEBE::BEGIN ~ {wd}"))

config <- fromJSON("config.json")

# Input

met_path <- fs::path(config$input_dir, "metprocessor-output-kamloops-a.txt")
dsm_path <- fs::path(wd, "dsm.tif")
chm_path <- fs::path(wd, "chm.tif")

# Output
out_dir <- fs::path(wd)
irr_path <- fs::path(out_dir, "irr.tif")

# Model
model <- fs::path(config$project_dir, "V2/calculate-insolation.model3")

result <- run(
  command = "qgis_process",
  args = c(
    "run",
    model,
    "--",
    str_glue("building__ground_dsm={dsm_path}"),
    str_glue("vegetation_dsm={chm_path}"),
    str_glue("meteorological_data_umeped={met_path}"),
    str_glue("outputdir={out_dir}")
  ),
  env = c(QT_QPA_PLATFORM = "offscreen"),
  echo = FALSE,
  echo_cmd = TRUE,
  spinner = FALSE,
  stdout = "|",
  stderr = "|",
  error_on_status = FALSE
)

cat(result$stdout)
cat(result$stderr)  # this is where the double free line will be

irr_written <- file.exists(file.path(out_dir, "Energyyearroof.tif")) &&
               file.info(file.path(out_dir, "Energyyearroof.tif"))$size > 10000

if (!irr_written) {
  message("\n\n>>> SEBE::FAIL\n\n",  result$stderr)
} else {
  message("\n\n>>> SEBE::SUCCESS\n\n")
}
