if (!require("logger")) install.packages("logger")

# Ensure the logs/ directory exists 
dir.create("logs", showWarnings = FALSE)

# Define a single log file (new file each day) 
log_file <- paste0("logs/app_log_", Sys.Date(), ".log")

# Remove any existing appenders to avoid duplicates 
logger::log_appender(NULL) # This removes the default console appender 

# Clean up logs older than 30 days 
old_logs <- list.files("logs", full.names = TRUE)

# Fix: Convert Sys.Date() to POSIXct for proper comparison 
old_logs_dates <- file.mtime(old_logs)
cutoff_date <- as.POSIXct(Sys.Date() - 30) # Convert to POSIXct 

# Remove files older than 30 days 
file.remove(old_logs[old_logs_dates < cutoff_date])

# Configure appender to write logs to file and console
logger::log_appender(logger::appender_tee(log_file))

# Set log level (change to DEBUG for more details)
logger::log_threshold(INFO)
