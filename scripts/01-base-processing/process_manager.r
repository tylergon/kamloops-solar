library('tidyverse')
library('processx')

data_dir <- "data/LiDAR/"
temp_dir <- "temp/"
out_dir <- "output/batching"

# Read in the neighbourhood descriptions & print out some info:
neighbourhoods <- read_csv('output/neighbourhood_tiles_tail.csv')
neighbourhoods

# Iterate through each neighbourhood
for (i in 1:nrow(neighbourhoods)) {
  row <- neighbourhoods[i,] %>% select(neighbourhood, tiles) %>% tibble()
  nbhd <- row[1,]$neighbourhood
  
  # Write the info to a thing we need to do
  write_csv(row, 'temp/current_tile.csv', )
  
  # Call the worker
  result <- processx::run(
    command = 'Rscript',
    args = c("--vanilla", "--quiet", "D:/Dev/Geomatics/kamloops-solar/scripts/sandbox/process_worker.R"),
    wd = getwd(),
    echo = TRUE,
    error_on_status = TRUE
  )
  
  # Only print if there is actual content in stdout
  if (nchar(result$stdout) > 0) {
    cat(result$stdout)
  }
  
  if (result$status != 0) {
    message(paste("Error in child process for:", nbhd))
    cat(result$stderr)
  }
  
  # Output the results before moving to the next iteration
  cat('Completion Status (', nbhd, ') - ', result$status, sep='')
}
