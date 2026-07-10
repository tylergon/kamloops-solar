library(stringr)
library(processx)

args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

source("src/utils.r")
init_logging("sebe_orchestrator - {wd}")

# Input
met_path <- fs::path(config$input_dir, "metprocessor-output.txt")
dsm_path <- fs::path(wd, "dsm.tif")
chm_path <- fs::path(wd, "chm.tif")

# Model
model <- fs::path(config$project_dir, "src/calculate-insolation.model3")

log_info("Running SEBE")

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

log_info(result$stdout)
if (nzchar(result$stderr)) {
  log_warn(result$stderr)
}

output_path <- "Energyyearroof.tif"
irr_written <- file.exists(file.path(wd, output_path)) &&
               file.info(file.path(wd, output_path))$size > 10000

if (!irr_written) {
  log_error("SEBE failed: {result$stderr}")
} else {
  log_success("SEBE complete")
}
