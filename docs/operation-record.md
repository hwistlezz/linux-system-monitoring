# 리눅스 시스템 운영 기록

## 1. 실습 환경

```text
Distributor ID:	Ubuntu
Description:	Ubuntu 24.04.4 LTS
Release:	24.04
Codename:	noble
```

- 방화벽 도구: UFW
- SSH 포트: 20022
- 애플리케이션 포트: 15034
- AGENT_HOME: /home/agent-admin/agent-app
- 로그 경로: /var/log/agent-app/monitor.log

---

## 2. SSH 보안 설정

### 수행 내용

- SSH 접속 포트를 20022로 변경했다.
- root 원격 접속을 차단했다.
- Ubuntu 24.04에서 ssh.socket이 22번 포트를 잡고 있어 ssh.socket을 비활성화하고 ssh.service가 20022 설정을 따르도록 수정했다.

### 확인 명령어

```bash
# SSH 설정 파일에서 포트와 root 원격 접속 차단 설정을 확인한다.
sudo grep -E '^(Port|PermitRootLogin)' /etc/ssh/sshd_config

# sshd가 실제로 20022 포트에서 LISTEN 중인지 확인한다.
sudo ss -tulnp | grep ssh
```

### 확인 결과

```text
Port 20022
PermitRootLogin no
tcp   LISTEN 0      128           0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=4603,fd=3))           
tcp   LISTEN 0      128              [::]:20022         [::]:*    users:(("sshd",pid=4603,fd=4))           
```

---

## 3. UFW 방화벽 설정

### 수행 내용

- UFW를 활성화했다.
- 인바운드 포트는 20022/tcp와 15034/tcp만 허용했다.

### 확인 명령어

```bash
# UFW 활성화 상태와 허용된 인바운드 포트를 확인한다.
sudo ufw status verbosesudo ufw status verbose
```

### 확인 결과

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW IN    Anywhere                  
15034/tcp                  ALLOW IN    Anywhere                  
20022/tcp (v6)             ALLOW IN    Anywhere (v6)             
15034/tcp (v6)             ALLOW IN    Anywhere (v6)             

```

---

## 4. 계정, 그룹, 권한 설정

### 수행 내용

- agent-admin, agent-dev, agent-test 계정을 생성했다.
- agent-common, agent-core 그룹을 생성했다.
- agent-admin과 agent-dev는 agent-common, agent-core에 포함했다.
- agent-test는 agent-common에만 포함했다.
- upload_files는 agent-common 그룹이 접근 가능하도록 설정했다.
- api_keys와 /var/log/agent-app는 agent-core 그룹만 접근 가능하도록 설정했다.

### 확인 명령어

```bash
# 각 계정이 어떤 그룹에 포함되어 있는지 확인한다.
id agent-admin
id agent-dev
id agent-test

# 주요 디렉토리의 소유자, 그룹, 권한을 확인한다.
sudo ls -ld /home/agent-admin
sudo ls -ld /home/agent-admin/agent-app
sudo ls -ld /home/agent-admin/agent-app/upload_files
sudo ls -ld /home/agent-admin/agent-app/api_keys
sudo ls -ld /var/log/agent-app
```

### 확인 결과

```text
uid=1001(agent-admin) gid=1004(agent-admin) groups=1004(agent-admin),1002(agent-common),1003(agent-core)
uid=1002(agent-dev) gid=1005(agent-dev) groups=1005(agent-dev),1002(agent-common),1003(agent-core)
uid=1003(agent-test) gid=1006(agent-test) groups=1006(agent-test),1002(agent-common)

drwxr-x---+ 3 agent-admin agent-core 4096 May 31 14:16 /home/agent-admin
drwxr-x---+ 5 agent-admin agent-core 4096 May 31 14:17 /home/agent-admin/agent-app
drwxrws--- 2 agent-admin agent-common 4096 May 31 14:16 /home/agent-admin/agent-app/upload_files
drwxrws--- 2 agent-admin agent-core 4096 May 31 14:16 /home/agent-admin/agent-app/api_keys
drwxrws--- 2 agent-admin agent-core 4096 May 31 14:21 /var/log/agent-app
```

### ACL 확인 결과

```text
getfacl: Removing leading '/' from absolute path names
# file: home/agent-admin
# owner: agent-admin
# group: agent-core
user::rwx
group::r-x
group:agent-common:--x
mask::r-x
other::---

getfacl: Removing leading '/' from absolute path names
# file: home/agent-admin/agent-app
# owner: agent-admin
# group: agent-core
user::rwx
group::r-x
group:agent-common:--x
mask::r-x
other::---

getfacl: Removing leading '/' from absolute path names
# file: home/agent-admin/agent-app/upload_files
# owner: agent-admin
# group: agent-common
# flags: -s-
user::rwx
group::rwx
other::---

getfacl: Removing leading '/' from absolute path names
# file: home/agent-admin/agent-app/api_keys
# owner: agent-admin
# group: agent-core
# flags: -s-
user::rwx
group::rwx
other::---

getfacl: Removing leading '/' from absolute path names
# file: var/log/agent-app
# owner: agent-admin
# group: agent-core
# flags: -s-
user::rwx
group::rwx
other::---

```

---

## 5. 애플리케이션 실행 환경 구성

### 수행 내용

- AGENT_HOME, AGENT_PORT, AGENT_UPLOAD_DIR, AGENT_KEY_PATH, AGENT_LOG_DIR 환경 변수를 설정했다.
- /home/agent-admin/agent-app/api_keys/t_secret.key 파일을 생성했다.
- agent-admin 일반 계정으로 애플리케이션을 실행했다.
- Boot Sequence 5단계가 모두 OK인지 확인했다.
- Agent READY 출력과 15034 포트 LISTEN 상태를 확인했다.

### 확인 결과

```text
Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
... Running as service user 'agent-admin'
[2/5] Verifying Environment Variables     [OK]
... All required envs exist
[3/5] Checking Required Files             [OK]
... Verified key file with correct key string.
[4/5] Checking Port Availability          [OK]
... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
... Log directory is writable: /var/log/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
tcp   LISTEN 0      5             0.0.0.0:15034      0.0.0.0:*          
```

---

## 6. 모니터링 스크립트

### 스크립트 위치

```text
/home/agent-admin/agent-app/bin/monitor.sh
```

### 권한 확인

```text
-rwxr-x--- 1 agent-dev agent-core 4421 May 31 14:20 /home/agent-admin/agent-app/bin/monitor.sh
```

### 수동 실행 결과

```text
==================================================
SYSTEM MONITOR RESULT
==================================================

[HEALTH CHECK]
Checking process 'agent_app.py'... [OK] (PID: 3641)
Checking port 15034... [OK]

[FIREWALL CHECK]
Checking UFW firewall... [OK]

[RESOURCE MONITORING]
CPU Usage  : 0.2%
MEM Usage  : 8.5%
DISK Used  : 1%


[INFO] Log appended: /var/log/agent-app/monitor.log
```

### 로그 기록 확인

```text
[2026-05-31 14:23:02] PID:3641 CPU:0.0% MEM:8.5% DISK_USED:1%
[2026-05-31 14:24:01] PID:3641 CPU:0.4% MEM:8.5% DISK_USED:1%
[2026-05-31 14:25:02] PID:3641 CPU:0.1% MEM:8.5% DISK_USED:1%
[2026-05-31 14:26:02] PID:3641 CPU:0.0% MEM:8.5% DISK_USED:1%
[2026-05-31 14:27:00] PID:3641 CPU:0.2% MEM:8.5% DISK_USED:1%
```

---

## 7. cron 자동 실행 설정

### 수행 내용

- agent-admin 계정의 crontab에 monitor.sh를 매분 실행하도록 등록했다.
- 1분 뒤 /var/log/agent-app/monitor.log에 로그가 자동으로 추가되는 것을 확인했다.

### 확인 결과

```text
* * * * * /home/agent-admin/agent-app/bin/monitor.sh >> /var/log/agent-app/monitor-cron.out 2>&1

[2026-05-31 14:20:34] PID:3641 CPU:0.4% MEM:8.4% DISK_USED:1%
[2026-05-31 14:21:02] PID:3641 CPU:0.0% MEM:8.4% DISK_USED:1%
[2026-05-31 14:22:01] PID:3641 CPU:0.0% MEM:8.4% DISK_USED:1%
[2026-05-31 14:22:41] PID:3641 CPU:0.0% MEM:8.5% DISK_USED:1%
[2026-05-31 14:23:02] PID:3641 CPU:0.0% MEM:8.5% DISK_USED:1%
[2026-05-31 14:24:01] PID:3641 CPU:0.4% MEM:8.5% DISK_USED:1%
[2026-05-31 14:25:02] PID:3641 CPU:0.1% MEM:8.5% DISK_USED:1%
[2026-05-31 14:26:02] PID:3641 CPU:0.0% MEM:8.5% DISK_USED:1%
[2026-05-31 14:27:00] PID:3641 CPU:0.2% MEM:8.5% DISK_USED:1%
```

---

## 8. 최종 점검표

- [x] SSH 포트 20022 변경 확인
- [x] root 원격 접속 차단 확인
- [x] UFW 활성화 확인
- [x] 20022/tcp, 15034/tcp만 허용 확인
- [x] agent-admin, agent-dev, agent-test 계정 생성 확인
- [x] agent-common, agent-core 그룹 생성 확인
- [x] 디렉토리 권한 설정 확인
- [x] 애플리케이션 Boot Sequence 5단계 OK 확인
- [x] Agent READY 출력 확인
- [x] 15034 포트 LISTEN 확인
- [x] monitor.sh 프로세스 확인 기능 확인
- [x] monitor.sh 포트 확인 기능 확인
- [x] CPU, 메모리, 디스크 사용률 수집 확인
- [x] monitor.log 누적 기록 확인
- [x] cron 매분 자동 실행 확인
- [x] monitor.log 10MB / 10개 유지 로직 구현 확인
