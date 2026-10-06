#!/usr/bin/env bash
# Audit de sécurité SUR CIBLES AUTORISÉES UNIQUEMENT.
# Refuse toute cible absente de allowlist.txt. Envoie le rapport sur WhatsApp.
#
# Usage: authorized-audit.sh <cible>
#   <cible> = domaine ou IP, qui DOIT figurer dans $ALLOWLIST.
#
# ⚠️  L'autorisation écrite de scanner ces cibles est TA responsabilité.
#     L'allowlist est un garde-fou technique, pas une autorisation légale.
set -euo pipefail

ALLOWLIST="${ALLOWLIST:-/opt/defender/allowlist.txt}"
NOTIFY="$(dirname "$0")/notify-whatsapp.sh"
TARGET="${1:?cible requise}"

# --- Garde-fou : la cible doit être explicitement listée ---
if [[ ! -f "$ALLOWLIST" ]]; then
  echo "allowlist introuvable ($ALLOWLIST) — audit refusé" >&2; exit 2
fi
# match exact, lignes vides et commentaires (#) ignorés
if ! grep -vE '^\s*(#|$)' "$ALLOWLIST" | grep -Fxq "$TARGET"; then
  echo "REFUSÉ : '$TARGET' n'est pas dans l'allowlist. Ajoute-la d'abord." >&2
  exit 3
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="/tmp/audit_${TARGET//[^a-zA-Z0-9]/_}_$STAMP"

echo "[audit] $TARGET (autorisée) -> $OUT"
# Scan de services + scripts de vulnérabilité "safe" seulement.
nmap -sV -T3 --script "default,safe" -oN "$OUT.nmap" "$TARGET" || true
# nuclei si présent (templates non intrusifs) ; ne bloque pas si absent.
if command -v nuclei >/dev/null 2>&1; then
  nuclei -silent -severity medium,high,critical -u "$TARGET" -o "$OUT.nuclei" || true
fi

SUMMARY="🛡️ Audit autorisé — ${VPS_NAME:-vps}
Cible: $TARGET
$(date -u)
--- nmap (extrait) ---
$(grep -E '^(PORT|[0-9]+/|Nmap scan|Service)' "$OUT.nmap" 2>/dev/null | head -25)
$( [[ -s "$OUT.nuclei" ]] && echo "--- nuclei ---" && head -15 "$OUT.nuclei" )"

"$NOTIFY" "$SUMMARY"
echo "[audit] terminé, rapport envoyé."
