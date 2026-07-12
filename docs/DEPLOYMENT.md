# Deployment Guide

## 배포 순서

| 단계 | 폴더·명령 | 실행 시점 | 주요 작업 |
|---:|---|---|---|
| 0 | `make validate` | 배포 전 | Terraform, cloud-init, VM Family Quota 검증 |
| 1 | `terraform/00-network` | 최초 1회 | 양쪽 RG/VNet/NSG/PIP/LB, Traffic Manager |
| 2 | `terraform/10-primary` | 최초 1회 | 서울 VM, OS/Data Disk, Primary LB Backend |
| 3 | `make primary-check` | Primary 생성 후 | Mount, MySQL, Tomcat, DB, `/health` 검증 |
| 4 | `terraform/20-automation` | Primary 검증 후 | Automation Account, Runbook, Schedule |
| 5 | `terraform/30-dr` | 장애 승인 후 | 도쿄 Disk/NIC/VM, DR LB Backend |

## 1. 최신 소스와 공통 준비

```bash
git switch main
git pull --ff-only origin main
chmod +x scripts/*.sh

az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

각 모듈의 예제 변수를 복사합니다.

```bash
cp -n terraform/00-network/terraform.tfvars.example terraform/00-network/terraform.tfvars
cp -n terraform/10-primary/terraform.tfvars.example terraform/10-primary/terraform.tfvars
cp -n terraform/20-automation/terraform.tfvars.example terraform/20-automation/terraform.tfvars
cp -n terraform/30-dr/terraform.tfvars.example terraform/30-dr/terraform.tfvars
```

`terraform.tfvars`에는 실제 구독 ID, SSH 공개키 경로와 접속 허용 CIDR을 입력합니다.

## 2. VM 크기와 Quota

기본 예제 크기는 다음과 같습니다.

```hcl
vm_size = "Standard_D2s_v4"
```

VM 생성에는 다음 두 조건이 모두 필요합니다.

1. 해당 VM Family의 리전별 Quota가 충분해야 함
2. 배포 시점에 해당 리전의 실제 물리 Capacity가 있어야 함

Quota가 충분해도 `SkuNotAvailable`이 발생할 수 있습니다. 이 경우 같은 B 계열을 반복하기보다 Quota가 있는 D 계열 등 다른 Family 크기를 선택합니다.

현재 설정과 Quota를 포함한 사전검증:

```bash
make validate
```

## 3. Network 및 Traffic Manager

```bash
terraform -chdir=terraform/00-network init
terraform -chdir=terraform/00-network validate
terraform -chdir=terraform/00-network plan -out=network.tfplan
terraform -chdir=terraform/00-network apply network.tfplan
```

검증:

```bash
terraform -chdir=terraform/00-network output
bash scripts/traffic-switch.sh status
```

초기 상태는 Korea Endpoint Enabled, Japan Endpoint Disabled입니다.

## 4. Primary VM

```bash
terraform -chdir=terraform/10-primary init
terraform -chdir=terraform/10-primary validate
terraform -chdir=terraform/10-primary plan -out=primary.tfplan
terraform -chdir=terraform/10-primary apply primary.tfplan
```

환경변수를 Terraform Output에서 다시 생성합니다.

```bash
source scripts/load-env.sh
```

Primary 전체 검증:

```bash
make primary-check
```

이 검증은 다음 항목을 확인합니다.

- cloud-init `status: done`
- Managed Data Disk의 `/data` Mount
- `/data/mysql`의 `/var/lib/mysql` Bind Mount
- MySQL, Tomcat, Metadata Timer, Health Timer 실행 및 자동기동
- `dr_demo.instance_info` 조회
- VM 로컬 `/health`
- Korea Load Balancer `/health`

직접 접속:

```bash
ssh -i "$SSH_KEY" azureuser@"$PRIMARY_IP"
```

## 5. Primary 재부팅 검증

Primary 구성이 성공하면 재부팅 테스트를 수행합니다.

```bash
ssh -i "$SSH_KEY" azureuser@"$PRIMARY_IP" 'sudo reboot'
```

재접속 가능해진 후 다시 실행합니다.

```bash
make primary-check
```

재부팅 후에도 Data Disk, MySQL, Tomcat과 `/health`가 정상이어야 Snapshot Automation으로 진행합니다.

## 6. Automation

최초 테스트에서는 `terraform/20-automation/terraform.tfvars`를 다음처럼 유지합니다.

```hcl
enable_schedule = false
```

배포:

```bash
terraform -chdir=terraform/20-automation init
terraform -chdir=terraform/20-automation validate
terraform -chdir=terraform/20-automation plan -out=automation.tfplan
terraform -chdir=terraform/20-automation apply automation.tfplan
```

Runbook을 수동으로 한 번 실행하고 다음을 확인합니다.

- Source Snapshot 생성
- Target Snapshot Japan East 생성
- OS와 DATA-LUN-0의 RecoverySet Tag 일치
- Target Snapshot `CompletionPercent=100`
- 서울 MySQL과 Tomcat 재기동
- 서울 Load Balancer `/health` 복구

수동 테스트가 성공한 다음에만 Schedule을 활성화합니다.

## 7. DR 배포

DR VM Family Quota와 Japan East Capacity를 다시 확인한 뒤 실행합니다.

```bash
terraform -chdir=terraform/30-dr init
terraform -chdir=terraform/30-dr validate
terraform -chdir=terraform/30-dr plan -out=dr.tfplan
terraform -chdir=terraform/30-dr apply dr.tfplan
```

또는 승인형 Failover 스크립트:

```bash
bash scripts/dr-failover.sh ~/.ssh/azure_snapshot_dr azureuser
```

Traffic Manager 상태:

```bash
bash scripts/traffic-switch.sh status
```

## 8. 삭제

DR Compute만 삭제:

```bash
bash scripts/dr-destroy.sh
```

전체 Terraform 환경 삭제:

```bash
DESTROY_APPROVED=yes bash scripts/destroy-all.sh
```

전체 삭제는 반드시 다음 역순으로 실행됩니다.

```text
terraform/30-dr
→ terraform/20-automation
→ terraform/10-primary
→ terraform/00-network
```

cloud-init 실패 등으로 전체 재생성이 필요한 경우 [`RESET-AND-REDEPLOY.md`](RESET-AND-REDEPLOY.md)를 따릅니다.

## 9. 자주 사용하는 Make 명령

```bash
make help
make validate
make network
make primary
make primary-check
make automation
make dr
make dr-destroy
make tm-status
make destroy-all
```
