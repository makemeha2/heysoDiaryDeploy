# 배포 체크리스트

## 관리자 권한 보호 점검
- [ ] `/api/admin/auth/login`만 비인증 접근 가능한지 확인
- [ ] `/api/admin/**`가 `scope=admin` 없이 접근 시 403인지 확인
- [ ] `admin_access_token`과 사용자 토큰 저장 키가 분리되어 있는지 확인
- [ ] 구경로 `/api/comCd/admin/**` 호출이 404 또는 미노출인지 확인

## 운영 설정 점검
- [ ] nginx rate limit이 `/api/admin/auth/login`에 강하게 적용되는지 확인
- [ ] nginx rate limit이 `/api/admin/**`에 완화 적용되는지 확인
- [ ] `robots.txt`에 `/admin` 차단 규칙이 반영되었는지 확인
- [ ] admin 페이지가 `meta noindex,nofollow`를 설정하는지 확인
