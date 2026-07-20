library(stringr)
library(jsonlite)
library(logger)

config <- fromJSON("config.json")

init_logging <- function (module) {
    log_appender(appender_tee(path(config$log_dir, module, ext="log")))
    log_layout(layout_glue_generator(
        format = paste0("{level} [{format(time, \"%Y-%m-%d %H:%M:%S\")}] [", module, "] {msg}")
    ))
    log_info("Initialized")
}
