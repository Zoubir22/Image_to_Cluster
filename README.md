------------------------------------------------------------------------------------------------------
ATELIER FROM IMAGE TO CLUSTER
------------------------------------------------------------------------------------------------------
L'idée en 30 secondes : Cet atelier consiste à **industrialiser le cycle de vie d'une application** simple en construisant une **image applicative Nginx** personnalisée avec **Packer**, puis en déployant automatiquement cette application sur un **cluster Kubernetes** léger (K3d) à l'aide d'**Ansible**, le tout dans un environnement reproductible via **GitHub Codespaces**.
L'objectif est de comprendre comment des outils d'Infrastructure as Code permettent de passer d'un artefact applicatif maîtrisé à un déploiement cohérent et automatisé sur une plateforme d'exécution.

## 📋 Table des matières

1. [Séquence 1 : Codespace de Github](#séquence-1--codespace-de-github)
2. [Séquence 2 : Création du cluster K3d](#séquence-2--création-du-cluster-kubernetes-k3d)
3. [Séquence 3 : Solution complète](#séquence-3--solution-complète)
4. [Séquence 4 : Guide d'utilisation](#séquence-4--guide-dutilisation)
5. [Évaluation](#évaluation)

---

## Séquence 1 : Codespace de Github

**Objectif** : Création d'un Codespace Github  
**Difficulté** : Très facile (~5 minutes)

**Faites un Fork de ce projet**. Si besoin, voici une vidéo d'accompagnement pour vous aider dans les "Forks" : [Forker ce projet](https://youtu.be/p33-7XQ29zQ) 
  
Ensuite depuis l'onglet [CODE] de votre nouveau Repository, **ouvrez un Codespace Github**.

---

## Séquence 2 : Création du cluster Kubernetes K3d

**Objectif** : Créer votre cluster Kubernetes K3d  
**Difficulté** : Simple (~5 minutes)

Vous allez dans cette séquence mettre en place un cluster Kubernetes K3d contenant un master et 2 workers.  
Dans le terminal du Codespace copier/coller les codes ci-dessous étape par étape :  

**Création du cluster K3d**  
```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```
```bash
k3d cluster create lab \
  --servers 1 \
  --agents 2
```

**Vérification du cluster**  
```bash
kubectl get nodes
```

**Déploiement d'une application (Docker Mario)**  
```bash
kubectl create deployment mario --image=sevenajay/mario
kubectl expose deployment mario --type=NodePort --port=80
kubectl get svc
```

**Forward du port 80**  
```bash
kubectl port-forward svc/mario 8080:80 >/tmp/mario.log 2>&1 &
```

**Récupération de l'URL de l'application Mario** 
Votre application Mario est déployée sur le cluster K3d. Pour obtenir votre URL cliquez sur l'onglet **[PORTS]** dans votre Codespace et rendez public votre port **8080** (Visibilité du port).
Ouvrez l'URL dans votre navigateur et jouez !

---

## Séquence 3 : Solution complète

**Objectif** : Customiser une image Docker avec Packer et déploiement sur K3d via Ansible  
**Difficulté** : Moyen/Difficile (~2h)

### 🏗️ Architecture de la solution

```
Image_to_Cluster/
├── index.html              # Page web personnalisée (HTML/CSS moderne)
├── Makefile                # Automatisation complète du workflow
├── packer/
│   └── nginx.pkr.hcl       # Template Packer pour build Docker
└── ansible/
    ├── inventory.yml       # Inventaire Ansible (localhost)
    ├── deploy.yml          # Playbook de déploiement K3d
    └── k8s/
        ├── deployment.yml  # Deployment Kubernetes (2 replicas)
        └── service.yml     # Service NodePort (port 30080)
```

### 🔧 Outils utilisés

| Outil | Rôle | Version |
|-------|------|---------|
| **Packer** | Construction d'image Docker avec IaC | >= 1.8 |
| **Docker** | Runtime de conteneurs | >= 20.0 |
| **Ansible** | Automatisation du déploiement | >= 2.9 |
| **K3d** | Cluster Kubernetes léger | >= 5.0 |
| **kubectl** | Client Kubernetes | >= 1.25 |

### 📦 Détail des composants

#### 1. Template Packer (`packer/nginx.pkr.hcl`)

Le template Packer utilise le plugin Docker pour créer une image personnalisée :

```hcl
source "docker" "nginx" {
  image  = "nginx:alpine"    # Image de base légère
  commit = true              # Commit les changements
}

build {
  provisioner "file" {
    source      = "../index.html"
    destination = "/usr/share/nginx/html/index.html"
  }
  
  post-processor "docker-tag" {
    repository = "custom-nginx"
    tags       = ["latest"]
  }
}
```

**Points clés** :
- Utilise `nginx:alpine` comme base (image légère ~40MB)
- Copie notre `index.html` personnalisé dans Nginx
- Tag l'image `custom-nginx:latest` pour l'import K3d

#### 2. Playbook Ansible (`ansible/deploy.yml`)

Le playbook Ansible orchestre le déploiement complet :

1. **Vérification** du cluster K3d
2. **Import** de l'image Docker dans K3d
3. **Déploiement** des ressources Kubernetes
4. **Attente** de la disponibilité des pods

#### 3. Manifests Kubernetes (`ansible/k8s/`)

**Deployment** :
- 2 replicas pour la haute disponibilité
- `imagePullPolicy: Never` pour utiliser l'image locale
- Probes de health check (liveness/readiness)
- Limites de ressources définies

**Service** :
- Type NodePort pour l'accès externe
- Port 80 exposé sur le nodePort 30080

### 🎯 Architecture cible

![Architecture cible](Architecture_cible.png)

---

## Séquence 4 : Guide d'utilisation

**Difficulté** : Facile (~30 minutes)

### 🚀 Déploiement rapide (une seule commande)

```bash
make all
```

Cette commande exécute automatiquement :
1. Installation de Packer, Ansible, K3d et kubectl
2. Création du cluster K3d
3. Build de l'image Docker avec Packer
4. Déploiement sur K3d via Ansible
5. Configuration du port-forward

### 📖 Déploiement étape par étape

#### Étape 1 : Installation des prérequis

```bash
make install
```

Cette commande installe :
- **Packer** : Outil HashiCorp pour construire des images
- **Ansible** : Outil d'automatisation et de déploiement
- **K3d** : Distribution Kubernetes légère
- **kubectl** : Client Kubernetes

#### Étape 2 : Création du cluster K3d

```bash
make cluster
```

Crée un cluster nommé `lab` avec :
- 1 nœud server (control plane)
- 2 nœuds agents (workers)

Vérification :
```bash
kubectl get nodes
```

Résultat attendu :
```
NAME                STATUS   ROLES                  AGE   VERSION
k3d-lab-server-0    Ready    control-plane,master   1m    v1.28.x
k3d-lab-agent-0     Ready    <none>                 1m    v1.28.x
k3d-lab-agent-1     Ready    <none>                 1m    v1.28.x
```

#### Étape 3 : Build de l'image avec Packer

```bash
make build
```

Cette commande :
1. Initialise Packer et télécharge le plugin Docker
2. Construit l'image `custom-nginx:latest`
3. L'image contient Nginx + notre `index.html`

Vérification :
```bash
docker images | grep custom-nginx
```

#### Étape 4 : Déploiement via Ansible

```bash
make deploy
```

Le playbook Ansible :
1. Importe l'image dans le cluster K3d
2. Crée le Deployment (2 pods Nginx)
3. Crée le Service NodePort
4. Attend que les pods soient prêts

Vérification :
```bash
kubectl get pods -l app=custom-nginx
kubectl get svc custom-nginx
```

#### Étape 5 : Accès à l'application

Pour accéder à l'application dans **GitHub Codespaces**, exécutez la commande suivante :

```bash
kubectl port-forward svc/custom-nginx 8080:80
```

Ensuite, pour accéder à l'application :
1. Ouvrez l'onglet **PORTS** dans votre Codespace
2. Faites un **clic droit** sur le port **8080**
3. Sélectionnez **"Port Visibility"** → **"Public"**
4. Cliquez sur l'icône 🌐 (ou l'URL) pour ouvrir l'application dans votre navigateur

> **💡 Astuce** : Vous pouvez aussi utiliser `make forward` qui exécute la même commande en arrière-plan.

### 🔍 Commandes utiles

| Commande | Description |
|----------|-------------|
| `make all` | Déploiement complet automatisé |
| `make help` | Affiche l'aide |
| `make status` | Statut du cluster et du déploiement |
| `make clean` | Supprime le cluster et les images |
| `make deploy-simple` | Déploiement alternatif sans Ansible |

### 🛠️ Dépannage

**Le cluster n'existe pas**
```bash
make cluster
```

**L'image n'a pas été construite**
```bash
make build
```

**Les pods ne démarrent pas**
```bash
kubectl describe pod -l app=custom-nginx
kubectl logs -l app=custom-nginx
```

**Le port-forward ne fonctionne pas**
```bash
pkill -f "port-forward"
make forward
```

---

## Évaluation

Cet atelier, **noté sur 20 points**, est évalué sur la base du barème suivant :

| Critère | Points |
|---------|--------|
| Repository exécutable sans erreur majeure | 4 pts |
| Fonctionnement conforme au scénario annoncé | 4 pts |
| Degré d'automatisation (Makefile) | 4 pts |
| Qualité du README (lisibilité, clarté) | 4 pts |
| Processus de travail (commits, cohérence) | 4 pts |

---

## 📜 Licence

Projet réalisé dans le cadre de l'atelier DevOps - EFREI Paris

## 👤 Auteur

- **Nom Prénom** : LOUVOIS Arnaud
- **Promotion** : 2026
- **Date** : Février 2026
