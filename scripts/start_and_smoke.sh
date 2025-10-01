#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32}"

/opt/cliplaunch/scripts/server_up.sh
/opt/cliplaunch/scripts/smoke_flow.sh
