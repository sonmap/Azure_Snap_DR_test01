# Deployment Guide

## 배포 순서

| 단계 | 폴더 | 실행 시점 | 주요 리소스 |
|---:|---|---|---|
| 1 | `terraform/00-network` | 최초 1회 | 양쪽 RG/VNet/NSG/PIP/LB, Traffic Manager |
| 2 | `terraform/10-primary` | 최초 1회 | 서울 VM, OS/Data Disk, Primary LB Backend |
| 3 | `terraform/20-automation` | 최초 1회 | Automation Account, Runbook, Schedule |
| 4 | `terraform/30-dr` | 장애 승인 후 | 도쿄 Disk/NIC/VM, DR LB Backend |

## 1. 공통 변수

각 폴더의 `terraform.tfvars.example`을 `terraform.tfvars`로 복사하고 구독 ID를 입력합니다.

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

## 2. Network 및 Traffic Manager

```bash
terraform -chdir=terraform/00-network init
terraform -chdir=terraform/00-network plan
terraform -chdir=terraform/00-network apply
```

검증:

```bash
terraform -chdir=terraform/00-network output
./scripts/traffic-switch.sh status
```

초기 상태는 Korea Endpoint Enabled, Japan Endpoint Disabled입니다.

## 3. Primary VM

```bash
terraform -chdir=terraform/10-primary init
terraform -chdir=terraform/10-primary plan
terraform -chdir=terraform/10-primary apply
```

Cloud-init 완료 확인:

```bash
PRIMARY_IP=$(terraform -chdir=terraform/10-primary output -raw management_public_ip)
ssh -i ~/.ssh/azure_snapshot_dr azureuser@$PRIMARY_IP \
  'cloud-init status --wait && systemctl status mysql tomcat9 --no-pager'
```

서비스 확인:

```bash
PRIMARY_FQDN=$(terraform -chdir=terraform/00-network output -raw primary_service_fqdn)
curl -f "http://${PRIMARY_FQDN}:8080/health"
```

## 4. Automation

```bash
terraform -chdir=terraform/20-automation init
terraform -chdir=terraform/20-automation apply
```

Automation Account Runtime에 `Az.Accounts`와 `Az.Compute` 모듈을 준비합니다. Runbook을 수동으로 1회 실행해 다음을 확인합니다.

- Source Snapshot 생성
- Target Snapshot Japan East 생성
- OS와 DATA-LUN-0의 RecoverySet Tag 일치
- CompletionPercent 100
- 서울 MySQL/Tomcat 재기동

## 5. DR 배포

```bash
terraform -chdir=terraform/30-dr init
terraform -chdir=terraform/30-dr plan
terraform -chdir=terraform/30-dr apply
```

또는 전체 승인형 스크립트:

```bash
./scripts/dr-failover.sh ~/.ssh/azure_snapshot_dr azureuser
```

## 6. 삭제

DR Compute만 삭제:

```bash
./scripts/dr-destroy.sh
```

전체 실습 환경은 역순으로 삭제합니다.

```bash
terraform -chdir=terraform/20-automation destroy
terraform -chdir=terraform/10-primary destroy
terraform -chdir=terraform/00-network destroy
```
