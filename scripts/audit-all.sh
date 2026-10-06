#!/usr/bin/env bash
# Lance authorized-audit.sh sur CHAQUE cible de l'allowlist.
# Appelé par la tâche cron quotidienne. Ne scanne rien hors allowlist.
set -euo pipefail

ALLOWLIST="${ALLOWLIST:-/opt/defender/allowlist.txt}"
AUDIT="$(dirname "$0")/authorized-audit.sh"

[[ -f "$ALLOWLIST" ]] || { echo "allowlist introuvable" >&2; exit 2; }

mapfile -t TARGETS < <(grep -vE '^\s*(#|$)' "$ALLOWLIST")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "[audit-all] allowlist vide, rien à auditer."; exit 0
fi

for t in "${TARGETS[@]}"; do
  echo "[audit-all] -> $t"
  "$AUDIT" "$t" || echo "[audit-all] échec sur $t (on continue)"
done
