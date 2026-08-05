#!/usr/bin/env bash
# Startpunt voor alle wizards. Draai dit met: bash scripts/wizard.sh

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

title "putthatonline.com — installatiewizard"
cat <<'EOF'
Wat wil je doen?

  1) Landingspagina voor het eerst publiceren
     (Coolify-applicatie aanmaken + Cloudflare-route, in één keer)

  2) Nieuwe tool toevoegen aan de landingspagina
     (tools.json bijwerken + optioneel redeploy + Cloudflare-route)

  3) Alleen een Cloudflare-route toevoegen of aanpassen

  4) Alleen Coolify laten redeployen

  5) Van thema/vormgeving wisselen

  0) Afsluiten
EOF
echo ""
keuze=$(ask "Kies een nummer" "0")

case "$keuze" in
    1) exec "${SCRIPT_DIR}/coolify-app-wizard.sh" ;;
    2) exec "${SCRIPT_DIR}/voeg-tool-toe.sh" ;;
    3) exec "${SCRIPT_DIR}/cloudflare-route-wizard.sh" ;;
    4) exec "${SCRIPT_DIR}/coolify-deploy.sh" ;;
    5) exec "${SCRIPT_DIR}/wissel-thema.sh" ;;
    *) echo "Tot ziens."; exit 0 ;;
esac
