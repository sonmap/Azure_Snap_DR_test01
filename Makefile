.PHONY: help validate network primary primary-check automation dr dr-destroy tm-status tm-primary tm-dr destroy-all clean-plans

help:
	@echo "Azure Snapshot DR commands"
	@echo "  make validate       - Terraform/cloud-init preflight validation"
	@echo "  make network        - Deploy shared network, load balancers and Traffic Manager"
	@echo "  make primary        - Deploy Korea Central primary VM"
	@echo "  make primary-check  - Validate primary VM mounts, services, DB and health"
	@echo "  make automation     - Deploy Automation Account and snapshot runbook"
	@echo "  make dr             - Deploy and validate Japan East DR VM"
	@echo "  make dr-destroy     - Destroy DR compute only"
	@echo "  make destroy-all    - Destroy every Terraform layer in reverse order"
	@echo "  make clean-plans    - Delete saved *.tfplan files"

validate:
	bash scripts/preflight.sh

network:
	terraform -chdir=terraform/00-network init
	terraform -chdir=terraform/00-network apply

primary:
	terraform -chdir=terraform/10-primary init
	terraform -chdir=terraform/10-primary apply

primary-check:
	bash scripts/validate-primary.sh

automation:
	terraform -chdir=terraform/20-automation init
	terraform -chdir=terraform/20-automation apply

dr:
	bash scripts/dr-failover.sh

dr-destroy:
	bash scripts/dr-destroy.sh

tm-status:
	bash scripts/traffic-switch.sh status

tm-primary:
	bash scripts/traffic-switch.sh primary

tm-dr:
	bash scripts/traffic-switch.sh dr

destroy-all:
	DESTROY_APPROVED=yes bash scripts/destroy-all.sh

clean-plans:
	find terraform -type f -name '*.tfplan' -delete
