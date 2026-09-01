library(fs)
library(lubridate)
source("src/utils.r")

output_cols <- 80

start <- Sys.time()
sebe_dir <- path(config$scratch_dir, "SEBE")
n_tiles <- length(list.files(sebe_dir))
n_complete <- 0

while (n_tiles != n_complete) {
  tick <- Sys.time()

  # Find no. complete tiles
  outputs <- list.files(sebe_dir, pattern = "Energyyearroof.tif", recursive = TRUE)
  n_complete <- length(outputs)

  # Calculate statistics
  percentage <- n_complete / n_tiles
  elapsed <- format(.POSIXct(as.numeric(Sys.time() - start, units = "secs"), tz = "UTC"), "%H:%M:%S")

  # Print out progress
  preface <- sprintf(
    "[%s] %5.2f%% (%d/%d) ",
    elapsed, percentage * 100, n_complete, n_tiles
  )
  
  bar_width <- output_cols - 2 - nchar(preface)
  line <- sprintf(
    "\r%s[%s%s]", preface,
    strrep("%", bar_width), strrep(".", bar_width)
  )
  
  cat(line)
  flush.console()

  # Pause for a second or so...
  Sys.sleep(max(0, 1 - as.numeric(Sys.time() - tick, units = "secs")))
}

cat("\n")
