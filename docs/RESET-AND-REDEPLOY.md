# Clean Reset and Redeploy

이 문서는 cloud-init 또는 초기 VM 구성이 실패했을 때 VM을 수동 수정하지 않고 Terraform 리소스를 모두 삭제한 뒤 처음부터 재배포하는 절차입니다.

## 1. 최신 소스 받기

```bash
git switch main
git pull --ff-only origin main
chmod +x scripts/*.sh
```

중요 수정 사항:

- `terraform/10-primary/main.tf`는 `cloud-init.yaml.tftpl` 하나만 `custom_data`로 전달합니다.
- Load Balancer Backend Pool은 `azurerm_lb_backend_address_pool` 데이터 소스로 조회합니다.
- 기본 VM 크기는 `Standard_D2s_v4`이며, 실제 구독 Quota와 리전 Capacity에 따라 `terraform.tfvars`에서 변경합니다.
- `scripts/preflight.sh`가 Terraform, cloud-init runcmd, SKU Family Quota를 사전에 확인합니다.

## 2. tfvars 준비

```bash
cp -n terraform/00-network/terraform.tfvars.example terraform/00-network/terraform.tfvars
cp -n terraform/10-primary/terraform.tfvars.example terraform/10-primary/terraform.tfvars
cp -n terraform/20-automation/terraform.tfvars.example terraform/20-automation/terraform.tfvars
cp -n terraform/30-dr/terraform.tfvars.example terraform/30-dr/terraform.tfvars
```

각 파일에 실제 `subscription_id`, SSH 공개키 경로, 접속 허용 CIDR을 입력합니다.

VM 크기는 다음 두 조건을 모두 만족해야 합니다.

1. VM Family Quota의 `Limit - Current Usage`가 VM vCPU 이상
2. 실제 배포 시점에 해당 리전 물리 Capacity 존재

Quota가 있어도 `SkuNotAvailable`이 발생하면 같은 Family를 반복하지 말고 Quota가 있는 다른 Family 크기로 변경합니다.

## 3. 사전 검증

```bash
./scripts/preflight.sh
```

검증 내용:

- 필수 명령 설치 여부
- Azure 로그인 구독
- Terraform format과 validate
- cloud-init `runcmd` Bash 문법
- obsolete cloud-init fragment 참조 여부
- Korea Central Primary VM Family Quota
- Japan East DR VM Family Quota

## 4. 전체 삭제

전체 삭제는 다음 환경변수를 명시해야 실행됩니다.

```bash
DESTROY_APPROVED=yes ./scripts/destroy-all.sh
```

삭제 순서:

```text
terraform/30-dr
→ terraform/20-automation
→ terraform/10-primary
→ terraform/00-network
```

삭제 확인:

```bash
az group list \
  --query "[?starts_with(name,'rg-snapdr')].[name,location,properties.provisioningState]" \
  --output table
```

## 5. Network 재배포

```bash
terraform -chdir=terraform/00-network init
terraform -chdir=terraform/00-network validate
terraform -chdir=terraform/00-network plan -out=network.tfplan
terraform -chdir=terraform/00-network apply network.tfplan
```

## 6. Primary VM 재배포

```bash
terraform -chdir=terraform/10-primary init
terraform -chdir=terraform/10-primary validate
terraform -chdir=terraform/10-primary plan -out=primary.tfplan
terraform -chdir=terraform/10-primary apply primary.tfplan
```

환경변수 로딩:

```bash
source scripts/load-env.sh
```

## 7. Primary 검증

```bash
./scripts/validate-primary.sh
```

검증 성공 기준:

- cloud-init `status: done`
- `/data`가 Managed Data Disk에 마운트
- `/data/mysql`이 `/var/lib/mysql`에 Bind Mount
- MySQL과 Tomcat active/enabled
- `dr_demo.instance_info` 조회 성공
- 로컬 `/health`가 `OK`
- Korea Load Balancer `/health`가 `OK`

직접 확인할 때:

```bash
ssh -i ~/.ssh/azure_snapshot_dr azureuser@"$PRIMARY_IP"

sudo cloud-init status --long
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
findmnt /data
findmnt /var/lib/mysql
sudo systemctl is-active mysql tomcat9
sudo mysql -e "SELECT * FROM dr_demo.instance_info\G"
curl -fsS http://127.0.0.1:8080/health
```

## 8. 재부팅 검증

Primary 검증이 성공한 뒤 재부팅합니다.

```bash
ssh -i ~/.ssh/azure_snapshot_dr azureuser@"$PRIMARY_IP" 'sudo reboot'
```

재접속 후 다시 실행합니다.

```bash
./scripts/validate-primary.sh
```

## 9. Automation 배포

Primary VM의 재부팅 검증까지 성공한 다음 진행합니다.

```bash
terraform -chdir=terraform/20-automation init
terraform -chdir=terraform/20-automation validate
terraform -chdir=terraform/20-automation plan -out=automation.tfplan
terraform -chdir=terraform/20-automation apply automation.tfplan
```

최초에는 `enable_schedule = false`를 유지하고 Runbook을 수동으로 한 번 실행해 OS와 DATA-LUN-0 Snapshot 복사를 확인합니다.

## 10. 명령 요약

```bash
git pull --ff-only origin main
chmod +x scripts/*.sh
./scripts/preflight.sh
DESTROY_APPROVED=yes ./scripts/destroy-all.sh
make network
make primary
source scripts/load-env.sh
make primary-check
```
