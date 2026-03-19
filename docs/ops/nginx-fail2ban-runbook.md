# Heyso Diary 운영 보안 하드닝 Runbook

## 0) 배포 구조 확인
- 웹 프록시는 VM 로컬 nginx(systemd)가 아니라 `heyso-web` Docker 컨테이너 nginx를 사용한다.
- 근거:
  - `compose.base.yml`의 `web` 서비스가 `127.0.0.1:8080->80`으로 노출됨
  - `./nginx/default.conf -> /etc/nginx/conf.d/default.conf` 마운트
- fail2ban이 nginx access log를 읽을 수 있도록 `./logs/nginx:/var/log/nginx` 마운트를 사용한다.

## 1) 반영된 nginx 정책 요약
- 즉시 차단(앱 전달 전):
  - `.env`, `.git`, hidden dotfiles(단 `/.well-known/` 예외)
  - `phpinfo`, `xmlrpc`, `wp-*` 핵심 경로
  - `composer.json/lock`, `vendor`, `backup/backups`, `id_rsa`
- Rate limit:
  - 일반 `/api/`: `20r/s`, `burst=40`, `limit_conn=40`
  - 로그인 `/api/auth/oauth/google`: `10r/m` (burst 10)
  - OTP 발송 `/api/auth/reauth/email/send`: `5r/m` (burst 5)
  - OTP 검증 `/api/auth/reauth/email/verify`: `10r/m` (burst 10)

## 2) VM 접속 방법 예시
```powershell
# PEM은 C:\Users\fafa jeong\.ssh 아래 파일을 사용
# 아래 <YOUR_PEM_FILE>.pem 부분은 실제 파일명으로 변경 필요
ssh -i "C:\Users\fafa jeong\.ssh\<YOUR_PEM_FILE>.pem" azureuser@<VM_PUBLIC_IP>
```

## 3) nginx 반영 절차(컨테이너 기준)
```bash
cd /opt/heyso/heysoDiaryDeploy

# 1) compose 유효성 확인
docker compose -f compose.base.yml -f compose.prod.yml config >/tmp/compose.rendered.yml

# 2) web 컨테이너 재생성(마운트 반영)
docker compose -f compose.base.yml -f compose.prod.yml up -d web

# 3) nginx 설정 테스트
docker exec heyso-web nginx -t

# 4) nginx reload
docker exec heyso-web nginx -s reload
```

## 4) fail2ban 설치 및 설정(Ubuntu)
```bash
sudo apt-get update
sudo apt-get install -y fail2ban

# 필터/제일 배치
sudo cp /opt/heyso/heysoDiaryDeploy/security/fail2ban/filter.d/nginx-botscan.conf /etc/fail2ban/filter.d/nginx-botscan.conf
sudo cp /opt/heyso/heysoDiaryDeploy/security/fail2ban/jail.d/nginx-botscan.local /etc/fail2ban/jail.d/nginx-botscan.local

# fail2ban 문법 검증(권장)
sudo fail2ban-regex /opt/heyso/heysoDiaryDeploy/logs/nginx/access.log /etc/fail2ban/filter.d/nginx-botscan.conf

# 시작/재시작
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
```

## 5) 상태 확인 / 차단 해제
```bash
# 전체 상태
sudo fail2ban-client status

# 특정 jail 상태
sudo fail2ban-client status nginx-botscan

# 수동 해제
sudo fail2ban-client set nginx-botscan unbanip <IP>
```

## 6) 적용 후 검증(curl 예시)
### 6.1 차단 패턴 검증
```bash
curl -i http://127.0.0.1:8080/.env
curl -i http://127.0.0.1:8080/xmlrpc.php
curl -i http://127.0.0.1:8080/wp-login.php
curl -i http://127.0.0.1:8080/.git/config
```

### 6.2 일반 API rate limit 검증(20r/s, burst 40)
```bash
for i in $(seq 1 80); do
  curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/api/test &
done
wait
```

### 6.3 로그인/OTP rate limit 검증
```bash
# 로그인 (분당 10 내외)
for i in $(seq 1 20); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "Content-Type: application/json" \
    -d '{"idToken":"dummy"}' \
    http://127.0.0.1:8080/api/auth/oauth/google
done

# OTP 발송 (분당 5 내외)
for i in $(seq 1 12); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST \
    -H "Authorization: Bearer <token>" \
    http://127.0.0.1:8080/api/auth/reauth/email/send
done
```

## 7) 참고: host nginx 사용 중인 환경일 때
- 일부 운영 환경에서는 host nginx(systemd) 재적용 명령이 필요할 수 있다.
```bash
sudo nginx -t
sudo systemctl reload nginx
```
- 현재 Heyso Diary 배포 레포 기준 주 반영 지점은 `heyso-web` 컨테이너 nginx다.

## 8) 운영 주의사항
- `/.well-known/`은 인증서/검증 경로로 사용될 수 있어 차단 예외를 유지한다.
- 과도한 rate limit은 정상 로그인/OTP 흐름을 방해할 수 있으므로 기본값 유지 후 모니터링으로 조정한다.
- 이 설정은 1차 방어선이다. 대규모 스캔/공격에는 Cloudflare/WAF, 보안그룹/방화벽 정책을 병행한다.
