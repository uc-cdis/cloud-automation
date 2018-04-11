NOTE: fence is hard-coded to look for `local_settings.py` at
`/var/www/local_settings.py` in the case that it isn't found immediately (so, in
the case that fence is installed in a Docker image in a kubernetes pod). Don't
just change the path that the settings file is mounted to.
