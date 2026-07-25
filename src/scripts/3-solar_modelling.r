library(stringr)
library(dplyr)
library(processx)
library(fs)
library(terra)

args <- commandArgs(trailingOnly = TRUE)
wd <- args[1]

source("src/utils.r")
init_logging(basename(wd), "3-solar_modelling")

##### Prepare Inputs #####

# Develop a bounding box for our tile
matches <- str_match(wd, "(?<xleft>\\d+)_(?<ybottom>\\d+)") |> 
  as.data.frame() |>
  mutate(across(c(xleft, ybottom), as.numeric))
bbox <- ext(c(
  xmin = matches$xleft - config$chunk_buffer,
  xmax = matches$xleft + config$chunk_size + config$chunk_buffer,
  ymin = matches$ybottom - config$chunk_buffer,
  ymax = matches$ybottom + config$chunk_size + config$chunk_buffer
))

log_info("Cutting out DSM")

# Cut out DSM
dsm <- rast(path(config$output_dir, "dsm.tif")) |>
  crop(bbox)

# Fill in NA values
w <- 1
while (global(dsm, function(x) any(is.na(x)))[, 1]) {
  log_info("Filling gaps ({w})")
  w <- w + 2
  dsm <- focal(
    dsm,
    w = w,
    fun = mean,
    na.policy = "only",
    na.rm = TRUE
  )
}

dsm_path <- path(wd, str_glue("dsm_{matches$xleft}_{matches$ybottom}.tif"))
writeRaster(dsm, dsm_path, overwrite = TRUE)

log_info("Cutting out CHM")

# Cut out CHM & fill empty pixels
chm <- rast(path(config$output_dir, "chm.tif")) |>
  crop(bbox)
chm[is.na(chm)] <- 0
chm_path <- path(wd, str_glue("chm_{matches$xleft}_{matches$ybottom}.tif"))
writeRaster(chm, chm_path, overwrite = TRUE)

# Clean up
rm(dsm, chm); gc()


##### Run SEBE #####


# Input
met_path <- path(config$input_dir, "metprocessor-output.txt")

# Model
# TODO: Is this necessary?
model <- path(config$project_dir, "src/calculate-insolation.model3")

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

log_info(skip_formatter(result$stdout))
if (nzchar(result$stderr)) {
  log_warn(skip_formatter(result$stderr))
}

output_path <- path(wd, "Energyyearroof.tif")
irr_written <- file.exists(output_path) &&
               file.info(output_path)$size > 10000

if (!irr_written) {
  log_error("SEBE failed: {result$stderr}")
} else {
  log_success("SEBE complete")
}

# Define the output extent
bbox_out <- ext(c(
  xmin = matches$xleft,
  xmax = matches$xleft + config$chunk_size,
  ymin = matches$ybottom,
  ymax = matches$ybottom + config$chunk_size
))

# Rewrite the output cropped to the correct bounds
rast(output_path) |>
  crop(bbox_out) |>
  writeRaster(path(wd, "irr.tif"), overwrite = TRUE)

log_success("SEBE output cropped")
