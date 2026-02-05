# ============================================
# Makefile - Automatisation Image to Cluster
# ============================================
# Ce Makefile automatise l'ensemble du processus :
# 1. Installation des outils (Packer, Ansible, K3d)
# 2. Build de l'image Docker avec Packer
# 3. Déploiement sur K3d avec Ansible

.PHONY: all install install-packer install-ansible install-k3d cluster build deploy clean help forward status

# Variables
CLUSTER_NAME := lab
IMAGE_NAME := custom-nginx:latest
PACKER_DIR := packer
ANSIBLE_DIR := ansible

# ============================================
# Commandes principales
# ============================================

## all: Exécute tout le processus (install -> cluster -> build -> deploy)
all: install cluster build deploy forward
	@echo ""
	@echo "=========================================="
	@echo "✅ Déploiement terminé avec succès !"
	@echo "=========================================="
	@echo "Ouvrez l'onglet PORTS et rendez le port 8080 public"
	@echo "=========================================="

## help: Affiche l'aide
help:
	@echo "Makefile - Image to Cluster"
	@echo ""
	@echo "Commandes disponibles :"
	@echo "  make all            - Exécute tout le processus complet"
	@echo "  make install        - Installe Packer, Ansible et K3d"
	@echo "  make cluster        - Crée le cluster K3d"
	@echo "  make build          - Build l'image Docker avec Packer"
	@echo "  make deploy         - Déploie sur K3d avec Ansible"
	@echo "  make forward        - Configure le port-forward"
	@echo "  make status         - Affiche le statut du déploiement"
	@echo "  make clean          - Supprime le cluster et les images"
	@echo ""

# ============================================
# Installation des outils
# ============================================

## install: Installe tous les prérequis
install: install-packer install-ansible install-k3d install-kubectl
	@echo "✅ Tous les outils sont installés"

## install-packer: Installe Packer
install-packer:
	@echo "📦 Installation de Packer..."
	@if ! command -v packer &> /dev/null; then \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null || true; \
		echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null; \
		sudo apt-get update -qq && sudo apt-get install -y packer; \
	else \
		echo "  Packer est déjà installé"; \
	fi

## install-ansible: Installe Ansible
install-ansible:
	@echo "📦 Installation d'Ansible..."
	@if ! command -v ansible &> /dev/null; then \
		sudo apt-get update -qq && sudo apt-get install -y ansible python3-kubernetes; \
	else \
		echo "  Ansible est déjà installé"; \
	fi

## install-k3d: Installe K3d
install-k3d:
	@echo "📦 Installation de K3d..."
	@if ! command -v k3d &> /dev/null; then \
		curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; \
	else \
		echo "  K3d est déjà installé"; \
	fi

## install-kubectl: Installe kubectl
install-kubectl:
	@echo "📦 Installation de kubectl..."
	@if ! command -v kubectl &> /dev/null; then \
		curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
		chmod +x kubectl && sudo mv kubectl /usr/local/bin/; \
	else \
		echo "  kubectl est déjà installé"; \
	fi

# ============================================
# Cluster K3d
# ============================================

## cluster: Crée le cluster K3d
cluster:
	@echo "☸️  Création du cluster K3d '$(CLUSTER_NAME)'..."
	@if sudo k3d cluster list 2>/dev/null | grep -q $(CLUSTER_NAME); then \
		echo "  Le cluster existe déjà"; \
	else \
		sudo k3d cluster create $(CLUSTER_NAME) --servers 1 --agents 2; \
	fi
	@mkdir -p ~/.kube
	@sudo k3d kubeconfig get $(CLUSTER_NAME) > ~/.kube/config 2>/dev/null || true
	@sudo chmod 644 ~/.kube/config 2>/dev/null || true
	@kubectl cluster-info

# ============================================
# Build de l'image
# ============================================

## build: Build l'image Docker avec Packer
build:
	@echo "🔨 Build de l'image Docker avec Packer..."
	cd $(PACKER_DIR) && sudo packer init nginx.pkr.hcl
	cd $(PACKER_DIR) && sudo packer build nginx.pkr.hcl
	@echo "✅ Image $(IMAGE_NAME) créée avec succès"
	@sudo docker images | grep custom-nginx

# ============================================
# Déploiement
# ============================================

## deploy: Déploie l'application sur K3d
deploy:
	@echo "🚀 Déploiement sur K3d avec Ansible..."
	@export PATH=$$PATH:$$HOME/.local/bin && \
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.yml deploy.yml

## deploy-simple: Déploiement simplifié sans Ansible (alternative)
deploy-simple:
	@echo "🚀 Déploiement simplifié sur K3d..."
	sudo k3d image import $(IMAGE_NAME) -c $(CLUSTER_NAME)
	kubectl apply -f $(ANSIBLE_DIR)/k8s/deployment.yml
	kubectl apply -f $(ANSIBLE_DIR)/k8s/service.yml
	@echo "⏳ Attente du déploiement..."
	kubectl rollout status deployment/custom-nginx --timeout=60s
	@echo "✅ Déploiement terminé"

## forward: Configure le port-forward
forward:
	@echo "🔗 Configuration du port-forward..."
	@pkill -f "port-forward.*custom-nginx" 2>/dev/null || true
	@kubectl port-forward svc/custom-nginx 8080:80 >/tmp/port-forward.log 2>&1 &
	@sleep 2
	@echo "✅ Port-forward configuré sur le port 8080"
	@echo "   Ouvrez l'onglet PORTS dans Codespace et rendez le port 8080 public"

# ============================================
# Status et monitoring
# ============================================

## status: Affiche le statut du déploiement
status:
	@echo "📊 Statut du cluster et du déploiement"
	@echo ""
	@echo "=== Nodes ==="
	@kubectl get nodes
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods -l app=custom-nginx
	@echo ""
	@echo "=== Service ==="
	@kubectl get svc custom-nginx
	@echo ""
	@echo "=== Image Docker ==="
	@sudo docker images | grep custom-nginx || echo "Image non trouvée"

# ============================================
# Nettoyage
# ============================================

## clean: Supprime le cluster et les images
clean:
	@echo "🧹 Nettoyage..."
	@pkill -f "port-forward" 2>/dev/null || true
	@kubectl delete -f $(ANSIBLE_DIR)/k8s/ 2>/dev/null || true
	@sudo k3d cluster delete $(CLUSTER_NAME) 2>/dev/null || true
	@sudo docker rmi $(IMAGE_NAME) 2>/dev/null || true
	@echo "✅ Nettoyage terminé"

## clean-all: Supprime tout (cluster + outils)
clean-all: clean
	@echo "🧹 Suppression des outils..."
	@sudo apt-get remove -y packer 2>/dev/null || true
	@pip3 uninstall -y ansible 2>/dev/null || true
