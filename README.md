# Linux System Monitoring

리눅스 서버 운영 기초를 연습하기 위한 학습용 저장소.

SSH 보안 설정, UFW 방화벽 구성, 사용자와 그룹 기반 권한 관리, Bash 기반 시스템 모니터링, cron 자동 실행을 다룹니다.

## 주요 내용

- SSH 포트 변경 및 root 원격 접속 차단
- UFW 기반 인바운드 포트 제한
- 사용자, 그룹, 디렉토리 권한 구성
- Bash 기반 프로세스, 포트, 리소스 모니터링
- monitor.log 누적 기록 및 로그 로테이션
- cron을 이용한 주기적 자동 실행

## 구조

```text
linux-system-monitoring/
├── README.md
├── docs/
│   ├── operation-record.md
│   └── evidence/
└── scripts/
    └── monitor.sh
```

## 실행 스크립트
`scripts/monitor.sh`

실제 실습 환경에서는 다음 위치에 배치하여 실행했습니다.

`/home/agent-admin/agent-app/bin/monitor.sh`
