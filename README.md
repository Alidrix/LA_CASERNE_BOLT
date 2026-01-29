# 🧑‍🚒🔐 Passbolt HA – Docker – 2 Datacenters – 2000 utilisateurs

> **Contexte critique** : gestion sécurisée des secrets pour une **caserne de pompiers** (~2000 agents).  
> **Exigences** : haute disponibilité, sécurité maximale, continuité de service, traçabilité complète.

## 🎨 Légende pastel

- 🟦 Architecture & Infra
- 🟩 Déploiement & Run
- 🟨 Sécurité
- 🟪 Observabilité & Incidents

---

## 🎯 Objectifs du projet

- 🔐 Gestion des mots de passe avec **Passbolt CE**
- ⚙️ Déploiement **Docker**
- 🏢 **2 Datacenters** (on-prem + externe)
- ♻️ Haute disponibilité (apps + base)
- 🚨 Supervision, alerting, incidents centralisés
- 🔄 Mises à jour **automatisées mais contrôlées**
- 📜 Journalisation complète (audit / forensic)

---

## 🧪 Contexte LAB (PC local)

Ce LAB vise à simuler **2 sites distincts** sur une seule machine afin de valider l’architecture avant un déploiement réel.

### ✅ Environnement cible

- **OS** : Ubuntu 22.04
- **CPU** : Intel Core 7 vPRO
- **RAM** : 16 Go (objectif : **8 Go alloués au LAB**)
- **Conteneurisation** : Docker + Docker Compose

### 📦 Hypothèses du LAB

- Les deux “datacenters” sont simulés par **deux stacks Docker Compose séparées** (dc1/dc2).
- Chaque DC expose ses services sur des **ports différents** (pour éviter les conflits).
- Les résolutions DNS/GSLB sont simulées via le **/etc/hosts** ou un reverse proxy local.
- Les volumes et secrets sont **locaux** (pas de stockage partagé entre DC).

---

## 🧩 Stack technique (versions épinglées)

| Composant | Image Docker | Version | Rôle |
| --- | --- | --- | --- |
| Passbolt CE | `passbolt/passbolt` | `5.9.0-1-ce-non-root` | Application |
| Reverse Proxy | `traefik` | `v3.6.7` | TLS / LB |
| Base de données | `bitnami/mariadb-galera` | `11.4.3-debian-12-r0` | Quorum HA |
| Metrics | `prom/prometheus` | `3.5.1` | Supervision |
| Logs | `grafana/loki` | `3.6.1` | Centralisation logs |
| Dashboards | `grafana/grafana` | `12.0.9` | Visualisation |
| Incidents | `grafana/oncall` | `v1.16.9` | Astreinte |

⚠️ **Jamais de `latest` en production**

---

## 🗂️ Arborescence du dépôt

```text
.
├── README.md
├── compose/
│   ├── dc1/
│   │   ├── reverse-proxy.compose.yml
│   │   ├── passbolt-app.compose.yml
│   │   ├── db-galera.compose.yml
│   │   ├── observability.compose.yml
│   │   └── observability/
│   │       ├── loki-config.yml
│   │       └── prometheus.yml
│   └── dc2/
│       ├── reverse-proxy.compose.yml
│       ├── passbolt-app.compose.yml
│       ├── db-galera.compose.yml
│       ├── observability.compose.yml
│       └── observability/
│           ├── loki-config.yml
│           └── prometheus.yml
├── env/
│   ├── dc1.env.example
│   └── dc2.env.example
├── secrets/        # jamais commit (local uniquement)
│   └── db_password.txt
├── volumes/        # volumes Docker locaux
└── runbooks/
    ├── incident_app.md
    ├── incident_db.md
    ├── incident_dc.md
    ├── backup_restore.md
    └── upgrade.md
```

---

## 🛠️ Démarrage rapide (LAB local)

### 1) Pré-requis

- Docker Engine + Docker Compose v2
- Un utilisateur dans le groupe `docker`
- Accès sudo pour créer les dossiers locaux

### 2) Préparation des dossiers

```bash
sudo mkdir -p /opt/passbolt/{dc1,dc2}/{gpg_volume,jwt_volume}
sudo mkdir -p /opt/passbolt/{dc1,dc2}/db/data
sudo chown -R $USER:$USER /opt/passbolt
```

### 3) Variables d’environnement

```bash
cp env/dc1.env.example env/dc1.env
cp env/dc2.env.example env/dc2.env
```

> Adapter les URLs en local, par exemple :  
> `https://passbolt-dc1.local` et `https://passbolt-dc2.local`

### 4) Secrets (LAB)

```bash
mkdir -p secrets
openssl rand -base64 32 > secrets/db_password.txt
openssl rand -base64 32 > secrets/smtp_password.txt
openssl rand -base64 64 > secrets/jwt_secret.txt
```

### 5) Lancement des stacks DC1 / DC2

```bash
docker compose -f compose/dc1/reverse-proxy.compose.yml \
  -f compose/dc1/passbolt-app.compose.yml \
  -f compose/dc1/db-galera.compose.yml \
  -f compose/dc1/observability.compose.yml up -d

docker compose -f compose/dc2/reverse-proxy.compose.yml \
  -f compose/dc2/passbolt-app.compose.yml \
  -f compose/dc2/db-galera.compose.yml \
  -f compose/dc2/observability.compose.yml up -d
```

### 6) Simulation DNS locale

```bash
sudo tee -a /etc/hosts <<'EOF'
127.0.0.1 passbolt-dc1.local
127.0.0.1 passbolt-dc2.local
EOF
```

### 7) Vérifications rapides

```bash
docker ps
docker compose -f compose/dc1/passbolt-app.compose.yml logs -f
docker compose -f compose/dc2/passbolt-app.compose.yml logs -f
```

---

## 🏗️ Architecture globale (Mermaid)

```mermaid
flowchart TB
  U[👥 Utilisateurs] -->|HTTPS 443| DNS[(🌐 DNS / GSLB)]

  subgraph DC1[🏢 DC1 - On-Prem]
    RP1[Traefik]
    APP1[Passbolt App 1]
    APP2[Passbolt App 2]
    DB1[(DB Galera 1)]
    DB2[(DB Galera 2)]
    OBS1[Prometheus / Loki / Grafana]
  end

  subgraph DC2[🏬 DC2 - Externe]
    RP2[Traefik]
    APP3[Passbolt App 3]
    DB3[(DB Galera 3)]
    OBS2[Prometheus / Loki / Grafana]
  end

  DNS --> RP1
  DNS --> RP2

  RP1 --> APP1
  RP1 --> APP2
  RP2 --> APP3

  APP1 --> DB1
  APP2 --> DB2
  APP3 --> DB3

  DB1 <--> DB2
  DB2 <--> DB3
  DB1 <--> DB3

  APP1 --> OBS1
  APP2 --> OBS1
  APP3 --> OBS2
```

---

## 🔁 Matrice des flux réseau

| Source | Destination | Port | Description |
| --- | --- | --- | --- |
| Users | Traefik | 443 | Accès HTTPS |
| Traefik | Passbolt | 8080 | HTTP interne |
| Passbolt | MariaDB | 3306 | DB privée |
| MariaDB | MariaDB | 4567/4568 | Réplication Galera |
| Passbolt | SMTP | 587 | Envoi mails |
| Services | Loki | 3100 | Logs |
| Services | Prometheus | 9090 | Metrics |
| Alertmanager | OnCall | Webhook | Incident |

---

## 🧩 Docker Compose – Passbolt (extrait)

```yaml
services:
  passbolt:
    image: passbolt/passbolt:5.9.0-1-ce-non-root
    restart: always
    ports:
      - "8080:8080"
    environment:
      APP_FULL_BASE_URL: https://passbolt.example.org
      DATASOURCES_DEFAULT_HOST: db-vip.internal
      DATASOURCES_DEFAULT_DATABASE: passbolt
      DATASOURCES_DEFAULT_USERNAME: passbolt
      DATASOURCES_DEFAULT_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - /opt/passbolt/gpg_volume:/etc/passbolt/gpg
      - /opt/passbolt/jwt_volume:/etc/passbolt/jwt
```

---

## 🟩 Procédures de remédiation

### 🔧 Panne d’un nœud applicatif

```bash
docker logs passbolt
docker restart passbolt
```

### 🗄️ Panne d’un nœud DB

- Vérifier le quorum Galera.
- Réintégrer le nœud après correction réseau/disque.

### 🏬 Panne complète d’un DC

- DNS bascule vers l’autre DC.
- Vérifier le quorum DB.
- Si besoin : restauration depuis backup chiffré.

---

## 🔄 Plan de mise à jour & maintien en condition opérationnelle

### Automatisation contrôlée

| Besoin | Outil |
| --- | --- |
| PR automatiques | Renovate |
| CI/CD | GitHub Actions |
| Scan CVE | Trivy |
| Signature images | Cosign |
| Déploiement | Argo CD (GitOps) |
| Logs & Metrics | Grafana Stack |
| Incidents | Grafana OnCall |

### Cycle de mise à jour

1. Renovate ouvre une PR.
2. CI : lint + scan + tests.
3. Validation humaine.
4. Déploiement progressif (rolling update).
5. Supervision & rollback auto.

---

## 🟪 Observabilité & incidents

- 📊 Dashboards Grafana (infra, app, DB)
- 📜 Logs centralisés Loki
- 🚨 Alertes Prometheus
- ☎️ Astreinte via Grafana OnCall
- 🧾 Post-mortem documenté

---

## 🔐 Sécurité (checklist)

- TLS partout (HSTS, TLS 1.2/1.3)
- DB jamais exposée
- Secrets hors repo
- Sauvegardes chiffrées & testées
- Journalisation centralisée
- Principe du moindre privilège

---

## ✅ Definition of Done (DoD)

- 2 DC opérationnels
- Quorum DB valide
- HA applicative fonctionnelle
- Backups restaurables
- Supervision & alerting actifs
- Runbooks testés
- Mises à jour automatisées

---

## 🧪 LAB local (Ubuntu 22.04, 8 Go RAM)

### 1) Pré-requis
- Docker + Docker Compose v2 installés
- Ports disponibles sur la machine locale

### 2) Préparer les variables d’environnement
```bash
cp env/dc1.env.example env/dc1.env
cp env/dc2.env.example env/dc2.env
```

### 3) Créer les secrets locaux
```bash
mkdir -p secrets
echo "ChangeDbMe!" > secrets/db_password.txt
```
> Le contenu du secret doit correspondre à `DB_PASSWORD` dans vos fichiers `.env`.

### 4) Créer les réseaux partagés
```bash
docker network create dc1-net
docker network create dc2-net
docker network create galera-net
```

### 5) Démarrer DC1 & DC2
```bash
docker compose -f compose/dc1/reverse-proxy.compose.yml up -d
docker compose -f compose/dc1/db-galera.compose.yml up -d
docker compose -f compose/dc1/passbolt-app.compose.yml up -d
docker compose -f compose/dc1/observability.compose.yml up -d

docker compose -f compose/dc2/reverse-proxy.compose.yml up -d
docker compose -f compose/dc2/db-galera.compose.yml up -d
docker compose -f compose/dc2/passbolt-app.compose.yml up -d
docker compose -f compose/dc2/observability.compose.yml up -d
```

### 6) (Optionnel) Démarrer Grafana OnCall
```bash
docker compose -f compose/dc1/observability.compose.yml --profile oncall up -d
docker compose -f compose/dc2/observability.compose.yml --profile oncall up -d
```

### 7) Accès locaux
- Passbolt DC1 : http://passbolt-dc1.local (Traefik exposé sur `:8081`)
- Passbolt DC2 : http://passbolt-dc2.local (Traefik exposé sur `:8082`)
- Grafana DC1 : http://localhost:3001
- Grafana DC2 : http://localhost:3002

> Pensez à ajouter les entrées `passbolt-dc1.local` et `passbolt-dc2.local` dans `/etc/hosts`.
