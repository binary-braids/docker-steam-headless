#!/usr/bin/env bash
###
# File: start-desktop.sh
# Project: bin
# File Created: Thursday, 1st January 1970 12:00:00 pm
# Author: Josh.5 (jsunnex@gmail.com)
# -----
# Last Modified: Sunday, 2nd October 2022 22:58:17 pm
# Modified By: Josh.5 (jsunnex@gmail.com)
###
set -e

# CATCH TERM SIGNAL:
_term() {
    kill -TERM "$pipewire_pid" 2>/dev/null
}
trap _term SIGTERM SIGINT


# EXECUTE PROCESS:
echo "PIPEWIRE: Starting pipewire service"
/usr/bin/pipewire &
pipewire_pid=$!


# WAIT FOR CHILD PROCESS:
wait "$pipewire_pid"
