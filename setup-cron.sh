#!/usr/bin/env bash
# À exécuter UNE fois après `docker compose up -d` pour planifier les deux tâches.
#   bash setup-cron.sh
# Enregistre dans Hermes :
#   - veille VPS toutes les 15 min (analyse logs + bans, notifie si du nouveau)
#   - audit quotidien des cibles autorisées (03:00 UTC)
set -euo pipefail
C="docker compose exec -T hermes-defender"

# 1) Veille défensive — agent + skill vps-defender, toutes les 15 min.
$C hermes cron create \
  --name "veille-vps" \
  --schedule "*/15 * * * *" \
  --skill vps-defender \
  --prompt "Lis les nouvelles entrées de /host/var/log (auth.log, nginx) et les bans fail2ban récents. S'il y a une activité notable (scan, brute-force, ban), envoie UN résumé concis sur WhatsApp via /opt/defender/scripts/notify-whatsapp.sh. Sinon, ne notifie pas."

# 2) Audit quotidien des cibles autorisées — sans agent, script direct.
$C hermes cron create \
  --name "audit-autorise-quotidien" \
  --schedule "0 3 * * *" \
  --no-agent \
  --script "/opt/defender/scripts/audit-all.sh"

echo "Tâches créées. Vérifie : docker compose exec hermes-defender hermes cron list"
