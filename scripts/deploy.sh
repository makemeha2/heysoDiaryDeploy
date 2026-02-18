#!/usr/bin/env bash
set -euo pipefail

# 사용 예)
# ./scripts/deploy.sh prod prod-a1b2c3d GHCR_USER GHCR_TOKEN
# (dev도 동일 패턴)
#
# 인자:
#   1) MODE: dev | prod
#   2) TAG:  prod-a1b2c3d 같은 고정 태그
#   3) GHCR_USER
#   4) GHCR_TOKEN

cd "$(dirname "$0")/.."

MODE="${1:-prod}"
NEW_TAG="${2:-}"
GHCR_USER="${3:-}"
GHCR_TOKEN="${4:-}"

BASE="-f compose.base.yml"
if [[ "$MODE" == "dev" ]]; then
  OVERRIDE="-f compose.dev.yml"
else
  OVERRIDE="-f compose.prod.yml"
fi

# 1) TAG 갱신 (.env가 있어야 함)
if [[ -z "$NEW_TAG" ]]; then
  echo "[deploy] ERROR: TAG is required (e.g. prod-a1b2c3d)"
  exit 1
fi

if [[ -f ".env" ]]; then
  if grep -q '^TAG=' .env; then
    sed -i "s/^TAG=.*/TAG=${NEW_TAG}/" .env
  else
    echo "TAG=${NEW_TAG}" >> .env
  fi
else
  echo "[deploy] ERROR: .env not found. Create /opt/heyso/heysoDiaryDeploy/.env"
  exit 1
fi

echo "[deploy] MODE=${MODE}, TAG=${NEW_TAG}"

# 2) GHCR 로그인(필요 시)
if [[ -n "$GHCR_USER" && -n "$GHCR_TOKEN" ]]; then
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
  echo "[deploy] docker login ghcr.io OK"
else
  echo "[deploy] GHCR_USER/TOKEN not provided. Assuming docker already logged in."
fi

# 3) Pull & Up
docker compose $BASE $OVERRIDE pull
docker compose $BASE $OVERRIDE up -d
docker compose $BASE $OVERRIDE ps
echo "✅ Deploy done"
