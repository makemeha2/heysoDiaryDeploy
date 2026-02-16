# 사용예
# ./scripts/deploy.sh dev
# ./scripts/deploy.sh prod
#

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-prod}"   # dev 또는 prod
BASE="-f compose.base.yml"

if [[ "$MODE" == "dev" ]]; then
  OVERRIDE="-f compose.dev.yml"
else
  OVERRIDE="-f compose.prod.yml"
fi

docker compose $BASE $OVERRIDE pull
docker compose $BASE $OVERRIDE up -d
docker compose $BASE $OVERRIDE ps
