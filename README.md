# Hermes VPS Defender — simple & sûr

Agent **défensif** Hermes : détecte les scans, laisse **fail2ban bloquer** les IP
hostiles, lance des **audits sur cibles autorisées**, et **notifie sur WhatsApp**
via `gowhatsappwebmultidevice`.

Repo **dédié** : image fine = *Hermes officiel + nmap/jq* (voir `Dockerfile`),
buildée une fois sur GHCR. Pas de fork, pas de workflows upstream parasites.

**Posture de sécurité :**
- Image buildée sur **GHCR** (GitHub Actions), tirée par le VPS.
- Déployée en **plain `docker compose`** sur l'hôte, sur le bridge
  `whatsapp-shared-network` (même réseau que gowa → DNS interne).
- **Rien d'exposé sur Internet** : pas de port publié, pas de domaine. Le dashboard
  stocke tes clés API → accès admin par **tunnel SSH** uniquement.
- Secrets dans `.env` / env, jamais dans l'image ni le repo.
- **Pas de contre-attaque** (fail2ban bannit) ; **pas de scan hors allowlist**.

## Fichiers

| Fichier | Rôle |
|---|---|
| `Dockerfile` | Image fine : `FROM nousresearch/hermes-agent` + nmap/jq |
| `.github/workflows/ghcr-image.yml` | Build + push de l'image sur `ghcr.io/<toi>/hermes-defender` |
| `docker-compose.yml` | Déploiement hôte, sur `whatsapp-shared-network`, **sans ports** |
| `.env.example` | Clé modèle + API gowhatsapp + destinataire |
| `scripts/notify-whatsapp.sh` | POST direct vers l'API gowa `/send/message` |
| `scripts/authorized-audit.sh` | Audit nmap/nuclei d'**une** cible — refuse hors allowlist |
| `scripts/audit-all.sh` | Audit de **toutes** les cibles de l'allowlist |
| `setup-cron.sh` | Crée les 2 tâches Hermes (veille 15 min + audit quotidien) |
| `fail2ban/jail.local` + `action.d/whatsapp.conf` | Blocage auto + notif WhatsApp |
| `allowlist.txt` | Cibles d'audit autorisées (vide par défaut) |
| `skills/vps-defender/SKILL.md` | Instructions de l'agent |

## Déploiement

### 1. Build de l'image (une fois)
Pousse le contenu de ce repo (avec le `Dockerfile`) sur `main`. Le workflow build et
publie `ghcr.io/<ton-owner>/hermes-defender:main`. Comme c'est un repo neuf (pas un fork),
les Actions sont actives par défaut. Build rapide : juste une couche nmap/jq au-dessus
de l'image Hermes officielle. Ensuite rends le package **public** (Packages → settings →
visibility), ou garde-le privé et fais `docker login ghcr.io` sur le VPS (PAT `read:packages`).

### 2. fail2ban sur l'HÔTE (le blocage s'y fait, pas dans le conteneur)
```bash
apt-get install -y fail2ban jq nmap
mkdir -p /opt/defender/scripts
cp scripts/notify-whatsapp.sh /opt/defender/scripts/ && chmod +x /opt/defender/scripts/*.sh
cp fail2ban/action.d/whatsapp.conf /etc/fail2ban/action.d/
cp fail2ban/jail.local /etc/fail2ban/jail.local
# Depuis l'HÔTE, gowa est joignable via son port mappé (32769 -> 3080 interne).
cat > /etc/default/hermes-defender <<'EOF'
GOWA_URL=http://127.0.0.1:32769
GOWA_BASIC_USER=shalomtehe
GOWA_BASIC_PASS=change-me-apres-rotation
WA_RECIPIENT=225XXXXXXXXXX@s.whatsapp.net
VPS_NAME=vmi3096991
EOF
systemctl restart fail2ban
```

### 3. Hermes
```bash
cp .env.example .env && nano .env         # ANTHROPIC_API_KEY + GOWA_URL + WA_RECIPIENT
# éditer docker-compose.yml : remplacer VOTRE_OWNER par ton owner GHCR
docker ps --format '{{.Names}}' | grep -i whats   # confirmer le nom du conteneur gowa -> GOWA_URL
docker login ghcr.io                      # si package privé
docker compose up -d
docker compose logs -f hermes-defender
```

### 4. Planifier veille + audits
```bash
bash setup-cron.sh
docker compose exec hermes-defender hermes cron list
```

## Test
```bash
docker compose exec hermes-defender /opt/defender/scripts/notify-whatsapp.sh "✅ Hermes Defender en ligne"
# audit : échoue tant que la cible n'est pas dans allowlist.txt (comportement voulu)
docker compose exec hermes-defender /opt/defender/scripts/authorized-audit.sh mon-domaine.com
```

## Accès admin (dashboard) sans exposition
```bash
ssh -L 8080:127.0.0.1:8080 root@ton-vps    # puis ouvrir http://localhost:8080 en local
```

## Limites assumées (par conception)
- **Pas de contre-attaque** contre l'IP source : on bloque (fail2ban), on ne riposte pas.
- **Pas de scan hors `allowlist.txt`.** L'autorisation écrite de ces cibles reste ta
  responsabilité légale.
- **Rien d'exposé sur Internet.** Le seul flux sortant est la notification WhatsApp.
