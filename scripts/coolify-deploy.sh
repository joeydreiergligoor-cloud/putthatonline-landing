#!/usr/bin/env bash
# Wizard: bestaande Coolify-applicatie redeployen via de API.
# Wordt hergebruikt door voeg-tool-toe.sh en kan ook los gedraaid worden.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd curl "sudo apt install curl"
require_cmd python3 "sudo apt install python3"

COOLIFY_URL="${COOLIFY_URL:-}"
COOLIFY_TOKEN="${COOLIFY_TOKEN:-}"
COOLIFY_APP_UUID="${COOLIFY_APP_UUID:-}"

if [[ -z "$COOLIFY_URL" ]]; then
    COOLIFY_URL=$(ask "Adres van je Coolify-dashboard (bv. https://coolify.putthatonline.com)")
    save_env_var "COOLIFY_URL" "$COOLIFY_URL"
fi
if [[ -z "$COOLIFY_TOKEN" ]]; then
    COOLIFY_TOKEN=$(ask "Coolify API-token (Keys & Tokens → API tokens)")
    save_env_var "COOLIFY_TOKEN" "$COOLIFY_TOKEN"
fi
if [[ -z "$COOLIFY_APP_UUID" ]]; then
    COOLIFY_APP_UUID=$(ask "UUID van de putthatonline-landing applicatie in Coolify")
    save_env_var "COOLIFY_APP_UUID" "$COOLIFY_APP_UUID"
fi

info "Redeploy starten voor applicatie ${COOLIFY_APP_UUID}..."
response=$(curl -sS -X POST "${COOLIFY_URL%/}/api/v1/deploy?uuid=${COOLIFY_APP_UUID}" \
    -H "Authorization: Bearer ${COOLIFY_TOKEN}")

if echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'deployments' in d or 'message' in d else 1)" 2>/dev/null; then
    ok "Deploy gestart. Volg de voortgang in Coolify → Deployments."
else
    err "Kon geen deploy starten. Reactie van Coolify:"
    echo "$response"
    exit 1
fi
