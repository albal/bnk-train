# BNK training lab: k3d + Terraform
KUBECONFIG := $(CURDIR)/kubeconfig
export KUBECONFIG
TF := terraform
FORGE_COMPOSE := docker compose -f docker-compose.yml -f docker-compose.local.yml -f docker-compose.lab.yml

.PHONY: help up cluster platform down status verify outputs forge-up forge-down forge-logs

help:
	@echo "make up        - create k3d cluster + platform (cert-manager, monitoring, demo app, bnk-forge, BNK if enabled)"
	@echo "make cluster   - only the k3d cluster (00-cluster)"
	@echo "make platform  - only the platform stack (10-platform)"
	@echo "make verify    - run the lab verification checks"
	@echo "make outputs   - URLs and passwords"
	@echo "make status    - nodes, pods, gateways"
	@echo "make forge-up / forge-down / forge-logs - bnk-forge only"
	@echo "make down      - destroy everything"

up: cluster platform

cluster:
	cd 00-cluster && $(TF) init -input=false -upgrade=false >/dev/null && $(TF) apply -input=false -auto-approve

platform:
	cd 10-platform && $(TF) init -input=false -upgrade=false >/dev/null && $(TF) apply -input=false -auto-approve

down:
	-cd 10-platform && $(TF) destroy -input=false -auto-approve
	cd 00-cluster && $(TF) destroy -input=false -auto-approve

outputs:
	@cd 10-platform && $(TF) output

status:
	kubectl get nodes
	kubectl get pods -A
	-kubectl get gatewayclass,gateway,httproute -A

verify:
	@bash scripts/verify.sh

forge-up:
	cd 10-platform && $(TF) apply -input=false -auto-approve -target=terraform_data.forge_deploy

forge-down:
	cd bnk-forge && make down COMPOSE='$(FORGE_COMPOSE)'

forge-logs:
	cd bnk-forge && $(FORGE_COMPOSE) logs -f --tail 50
