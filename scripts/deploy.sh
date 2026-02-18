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

MODE="${1:-}"
TAG="${2:-}"

# ✅ GHCR 자격증명은 "환경변수 우선", 없으면 3,4번째 인자로도 받게 호환
GHCR_USER="${GHCR_USER:-${3:-}}"
GHCR_TOKEN="${GHCR_TOKEN:-${4:-}}"

if [ -z "${MODE}" ] || [ -z "${TAG}" ]; then
  echo "Usage: $0 <mode> <tag> [ghcr_user] [ghcr_token]"
  echo "Example: $0 prod prod-a1b2c3d"
  exit 1
fi

if [ -z "${GHCR_USER}" ] || [ -z "${GHCR_TOKEN}" ]; then
  echo "ERROR: GHCR_USER / GHCR_TOKEN is required (env or args)"
  exit 1
fi

# (선택) 파일 위치/구조에 맞게 조정
DEPLOY_DIR="/opt/heyso/heysoDiaryDeploy"
ENV_FILE="${DEPLOY_DIR}/.env"

cd "${DEPLOY_DIR}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: .env not found at ${ENV_FILE}"
  exit 1
fi

# ✅ 토큰이 로그에 찍히지 않도록 주의 (set -x 금지)
echo "${GHCR_TOKEN}" | docker login ghcr.io -u "${GHCR_USER}" --password-stdin >/dev/null 2>&1 \
  || { echo "ERROR: docker login failed"; exit 1; }

# .env에서 TAG= 값을 갱신
# - Linux sed 기준 (-i OK)
if grep -qE '^TAG=' "${ENV_FILE}"; then
  sed -i "s/^TAG=.*/TAG=${TAG}/" "${ENV_FILE}"
else
  echo "TAG=${TAG}" >> "${ENV_FILE}"
fi

# mode별 compose 파일을 쓰는 구조라면 여기에 맞추세요.
# 예: compose.base.yml + compose.prod.yml 식
# 지금 프로젝트가 docker-compose.yml 하나면 아래처럼 단순하게:
if [ -f "${DEPLOY_DIR}/docker-compose.yml" ]; then
  docker compose pull
  docker compose up -d
else
  # 예시: compose 분리형일 때
  # docker compose -f compose.base.yml -f "compose.${MODE}.yml" pull
  # docker compose -f compose.base.yml -f "compose.${MODE}.yml" up -d
  echo "ERROR: docker-compose.yml not found. Please adjust deploy.sh for your compose file names."
  exit 1
fi

# (선택) 불필요 이미지 정리
docker image prune -f >/dev/null 2>&1 || true

echo "Deploy complete. mode=${MODE}, tag=${TAG}"