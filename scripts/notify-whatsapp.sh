#!/usr/bin/env bash
# Envoie un message WhatsApp via l'API gowhatsappwebmultidevice (directe).
# Usage: notify-whatsapp.sh "message texte"
# Variables attendues (depuis .env / environnement du conteneur) :
#   GOWA_URL, GOWA_BASIC_USER, GOWA_BASIC_PASS, WA_RECIPIENT
set -euo pipefail

# Côté HÔTE (appel par fail2ban), charge les variables ici.
# Côté conteneur, elles viennent de .env et ce fichier n'existe pas : aucun effet.
[[ -f /etc/default/hermes-defender ]] && . /etc/default/hermes-defender

MSG="${1:?message requis}"
: "${GOWA_URL:?GOWA_URL manquant}"
: "${WA_RECIPIENT:?WA_RECIPIENT manquant}"

# aldinokemal/go-whatsapp-web-multidevice : POST /send/message
# body JSON: {"phone":"<jid>","message":"<texte>"}
curl -fsS --max-time 20 \
  -u "${GOWA_BASIC_USER:-}:${GOWA_BASIC_PASS:-}" \
  -H "Content-Type: application/json" \
  -X POST "${GOWA_URL%/}/send/message" \
  -d "$(jq -nc --arg p "$WA_RECIPIENT" --arg m "$MSG" '{phone:$p, message:$m}')" \
  && echo "[notify] envoyé" \
  || { echo "[notify] ÉCHEC d'envoi WhatsApp" >&2; exit 1; }
