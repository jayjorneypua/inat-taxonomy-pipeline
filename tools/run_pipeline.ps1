# opens the pipeline watcher in its own window, then runs the job
Start-Process "$PSScriptRoot\watch_pipeline.cmd"
databricks bundle run inat_taxonomy_pipeline -p dbc-609647e1-c073