#!/usr/bin/env bash
set -euo pipefail

# 사용 예)
#   ./scripts/deploy.sh prod                # TAG 생략 -> latest
#   ./scripts/deploy.sh prod prod-a1b2c3d   # 특정 태그로 배포
# (dev도 동일 패턴)
#
# 인자:
#   1) MODE: dev | prod
#   2) TAG:  (optional) 예: prod-a1b2c3d, 생략 시 latest
#
# 자격증명:
#   GHCR_USER / GHCR_TOKEN (환경변수 권장, 없으면 3,4번째 인자로도 받게 호환)

cd "$(dirname "$0")/.."

MODE="${1:-}"
TAG="${2:-}"

# ✅ GHCR 자격증명은 "환경변수 우선", 없으면 3,4번째 인자로도 받게 호환
GHCR_USER="${GHCR_USER:-${3:-}}"
GHCR_TOKEN="${GHCR_TOKEN:-${4:-}}"

if [ -z "${MODE}" ]; then
  echo "Usage: $0 <mode> [tag] [ghcr_user] [ghcr_token]"
  echo "Example:"
  echo "  $0 prod"
  echo "  $0 prod prod-a1b2c3d"
  exit 1
fi

if [ "${MODE}" != "dev" ] && [ "${MODE}" != "prod" ]; then
  echo "MODE must be dev or prod. Got: ${MODE}"
  exit 1
fi

# TAG 생략 시 latest
if [ -z "${TAG}" ]; then
  TAG="latest"
fi

echo "[deploy] MODE=${MODE}, TAG=${TAG}"

# compose 파일 조합
BASE="compose.base.yml"
OVERRIDE="compose.${MODE}.yml"

if [ ! -f "${BASE}" ]; then
  echo "Missing ${BASE}"
  exit 1
fi
if [ ! -f "${OVERRIDE}" ]; then
  echo "Missing ${OVERRIDE}"
  exit 1
fi

# GHCR login (토큰이 있으면 로그인)
if [ -n "${GHCR_USER}" ] && [ -n "${GHCR_TOKEN}" ]; then
  echo "[deploy] docker login ghcr.io"
  echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USER}" --password-stdin
else
  echo "[deploy] GHCR_USER/GHCR_TOKEN not provided. Skipping docker login."
fi

# 환경변수로 TAG 전달 (compose에서 ${TAG}로 사용)
export TAG="${TAG}"

echo "[deploy] docker compose pull"
docker compose -f "${BASE}" -f "${OVERRIDE}" pull

echo "[deploy] docker compose up -d"
docker compose -f "${BASE}" -f "${OVERRIDE}" up -d --remove-orphans

echo "[deploy] done"
docker image prune -f >/dev/null 2>&1 || true
