#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?set DATABASE_URL}"
: "${PUB32:?set PUB32}"

bash /opt/cliplaunch/scripts/start_api_bg.sh
bash /opt/cliplaunch/scripts/run_regression.sh
