# Image "Hermes Defender" = Hermes officiel + outils de sécurité.
# Couche fine au-dessus de l'image publiée : build rapide (pas de compilation Hermes).
#
# Base : image officielle Hermes sur Docker Hub.
#   - épingle une version précise en prod si tu veux (ex. :vX.Y.Z) au lieu de :latest.
FROM nousresearch/hermes-agent:latest

USER root

# nmap + jq + curl : requis par scripts/authorized-audit.sh et notify-whatsapp.sh.
# Double chemin apt (Debian/Ubuntu) OU apk (Alpine) selon la base de l'image.
RUN set -eux; \
    if command -v apt-get >/dev/null 2>&1; then \
        apt-get update && \
        apt-get install -y --no-install-recommends nmap jq curl ca-certificates && \
        rm -rf /var/lib/apt/lists/*; \
    elif command -v apk >/dev/null 2>&1; then \
        apk add --no-cache nmap jq curl ca-certificates; \
    else \
        echo "gestionnaire de paquets inconnu" >&2; exit 1; \
    fi

# nuclei (optionnel) : le script d'audit le détecte et s'en passe s'il est absent.
# Décommente pour l'ajouter (pèse ~100 Mo). Version à épingler manuellement :
# RUN set -eux; cd /tmp; \
#     curl -fsSL -o nuclei.zip \
#       "https://github.com/projectdiscovery/nuclei/releases/download/v3.4.7/nuclei_3.4.7_linux_amd64.zip" && \
#     unzip -o nuclei.zip nuclei -d /usr/local/bin && rm -f nuclei.zip

# L'image garde l'ENTRYPOINT/CMD de Hermes (s6 /init). On ne le surcharge pas.
