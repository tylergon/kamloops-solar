library(stringr)
library(jsonlite)
library(logger)

config <- fromJSON("config.json")

init_logging <- function (module, subdir = NA) {
    # Set up the logging directory if it does not exist
    log_dir <- path(config$log_dir)
    if (!is.na(subdir)) {
        log_dir <- path(config$log_dir, subdir)
    }
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

    # Set up the logging appender
    log_appender(appender_tee(path(log_dir, module, ext="log")))
    log_layout(layout_glue_generator(
        format = paste0("{level} [{format(time, \"%Y-%m-%d %H:%M:%S\")}] [", module, "] {msg}")
    ))
    log_info("Initialized")
}
