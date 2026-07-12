.PHONY: network primary automation dr dr-destroy tm-status tm-primary tm-dr

network:
	terraform -chdir=terraform/00-network init
	terraform -chdir=terraform/00-network apply

primary:
	terraform -chdir=terraform/10-primary init
	terraform -chdir=terraform/10-primary apply

automation:
	terraform -chdir=terraform/20-automation init
	terraform -chdir=terraform/20-automation apply

dr:
	./scripts/dr-failover.sh

dr-destroy:
	./scripts/dr-destroy.sh

tm-status:
	./scripts/traffic-switch.sh status

tm-primary:
	./scripts/traffic-switch.sh primary

tm-dr:
	./scripts/traffic-switch.sh dr
