# Operations Runbook

## 1. 정상 운영

| 점검 | 명령/위치 | 정상 기준 |
|---|---|---|
| Traffic Manager | `./scripts/traffic-switch.sh status` | KRC Enabled/Online, JPE Disabled |
| Primary Health | `curl http://<KRC_LB_FQDN>:8080/health` | HTTP 200, `OK` |
| MySQL | `systemctl status mysql` | active |
| Tomcat | `systemctl status tomcat9` | active |
| Snapshot Job | Automation Job History | Completed |
| Target Snapshot | Japan East Snapshots | CompletionPercent 100 |

## 2. Snapshot 장애

1. Automation Job Output과 Error를 확인합니다.
2. 서울 서비스가 재기동됐는지 확인합니다.
3. Source Snapshot을 복사 완료 전에 삭제하지 않습니다.
4. 같은 Disk 계열의 이전 CopyStart가 진행 중인지 확인합니다.
5. RecoverySet에서 OS와 DATA-LUN-0이 모두 존재하는지 확인합니다.

## 3. DR 선언 체크리스트

- [ ] Korea Central 장애가 실제 장애인지 확인
- [ ] 담당자 DR 전환 승인
- [ ] Primary VM과 MySQL의 Fencing 또는 접근 차단 확인
- [ ] Japan East 최신 RecoverySet의 복사 완료 확인
- [ ] 도쿄 VNet, NSG, Public IP, Load Balancer 정상 확인
- [ ] `terraform/30-dr plan` 검토

## 4. Failover

```bash
./scripts/dr-failover.sh ~/.ssh/azure_snapshot_dr azureuser
```

성공 조건:

- Japan VM 생성 완료
- `/var/lib/mysql` Mount 완료
- MySQL 실행
- Tomcat 실행
- Japan LB `/health` HTTP 200
- Japan Traffic Manager Endpoint `Online`
- Korea Endpoint Disabled

## 5. Failover 실패

Traffic Manager 전환 스크립트는 Japan Endpoint가 `Online`이 되지 않으면 Korea Endpoint를 비활성화하지 않습니다.

확인 순서:

```bash
terraform -chdir=terraform/30-dr output
./scripts/traffic-switch.sh status
```

DR VM:

```bash
systemctl status mysql tomcat9 dr-health.timer
mount | grep -E '/data|/var/lib/mysql'
curl -v http://127.0.0.1:8080/health
sudo mysql -e "SELECT * FROM dr_demo.instance_info\G"
```

## 6. Failback

Failback 전에 DB 데이터의 서울 복귀 방법을 확정해야 합니다. Snapshot 복구 VM에서 발생한 신규 MySQL 데이터는 자동으로 서울에 반영되지 않습니다.

데이터 복구와 서울 Health 확인 후:

```bash
export PRIMARY_HEALTH_URL="http://<KRC_LB_FQDN>:8080/health"
./scripts/failback-primary.sh
```

## 7. DR Compute 정리

Failback이 완료되고 보존 승인을 받은 뒤:

```bash
./scripts/dr-destroy.sh
```

Japan East의 복사 Snapshot은 Runbook Retention 정책에 따라 유지됩니다.
