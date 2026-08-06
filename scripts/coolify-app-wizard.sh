#!/usr/bin/env bash
# Wizard: nieuwe applicatie aanmaken in Coolify vanaf een publieke Git-repository.
# Vervangt het handmatig doorlopen van "+ New Resource" in de Coolify-UI.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd curl "sudo apt install curl"
require_cmd python3 "sudo apt install python3"

title "Wizard: applicatie aanmaken in Coolify"
echo "Dit maakt een nieuwe applicatie aan op basis van een publieke Git-repository"
echo "en een Dockerfile — precies zoals bij de handmatige stappen in PUBLICEREN.md,"
echo "maar dan via de Coolify-API."
echo ""
echo "Let op: dit werkt alleen voor een PUBLIEKE repository. Heb je een private"
echo "repository, gebruik dan de handmatige stappen (bijlage in PUBLICEREN.md)."
echo ""

# --- Stap 1: verbindingsgegevens ---
COOLIFY_URL="${COOLIFY_URL:-}"
COOLIFY_TOKEN="${COOLIFY_TOKEN:-}"

if [[ -z "$COOLIFY_URL" ]]; then
    COOLIFY_URL=$(ask "Adres van je Coolify-dashboard (bv. https://coolify.putthatonline.com)")
    save_env_var "COOLIFY_URL" "$COOLIFY_URL"
fi
if [[ -z "$COOLIFY_TOKEN" ]]; then
    COOLIFY_TOKEN=$(ask "Coolify API-token (Keys & Tokens → API tokens aanmaken)")
    save_env_var "COOLIFY_TOKEN" "$COOLIFY_TOKEN"
fi

api() {
    # api METHODE PAD [DATA]
    local method="$1" path="$2" data="${3:-}"
    if [[ -n "$data" ]]; then
        curl -sS -X "$method" "${COOLIFY_URL%/}${path}" \
            -H "Authorization: Bearer ${COOLIFY_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$data"
    else
        curl -sS -X "$method" "${COOLIFY_URL%/}${path}" \
            -H "Authorization: Bearer ${COOLIFY_TOKEN}"
    fi
}

pick_from_list() {
    # Leest JSON (lijst, of {"data": [...]}) van stdin en laat de gebruiker kiezen.
    # Print het gekozen uuid op stdout.
    local label="$1"
    local json="$2"
    local items
    items=$(echo "$json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
items = d if isinstance(d, list) else d.get('data', d)
for i, item in enumerate(items):
    name = item.get('name') or item.get('uuid')
    print(f\"{i}\t{item.get('uuid')}\t{name}\")
")
    if [[ -z "$items" ]]; then
        err "Geen ${label} gevonden op je Coolify-instance."
        exit 1
    fi
    echo "" >&2
    echo "Beschikbare ${label}:" >&2
    while IFS=$'\t' read -r idx uuid name; do
        echo "  ${idx}) ${name}" >&2
    done <<< "$items"
    local keuze
    keuze=$(ask "Kies een nummer" "0")
    echo "$items" | awk -F'\t' -v k="$keuze" '$1==k {print $2}'
}

# --- Stap 2: project en server kiezen ---
info "Projecten ophalen..."
projects_json=$(api GET "/api/v1/projects")
project_uuid=$(pick_from_list "projecten" "$projects_json")
[[ -z "$project_uuid" ]] && { err "Geen geldige keuze."; exit 1; }

info "Servers ophalen..."
servers_json=$(api GET "/api/v1/servers")
server_uuid=$(pick_from_list "servers" "$servers_json")
[[ -z "$server_uuid" ]] && { err "Geen geldige keuze."; exit 1; }

environment_name=$(ask "Naam van de omgeving" "production")

# --- Stap 3: applicatiegegevens ---
app_naam=$(ask "Naam van de applicatie in Coolify" "putthatonline-landing")
git_repository=$(ask "URL van de publieke Git-repository" "https://github.com/<gebruiker>/putthatonline-landing")
git_branch=$(ask "Branch" "main")
poort=$(ask "Poort waarop de container luistert" "80")
domein=$(ask "Domein voor deze applicatie (bv. putthatonline.com)")

payload=$(python3 -c "
import json
print(json.dumps({
    'project_uuid': '${project_uuid}',
    'server_uuid': '${server_uuid}',
    'environment_name': '${environment_name}',
    'git_repository': '${git_repository}',
    'git_branch': '${git_branch}',
    'build_pack': 'dockerfile',
    'ports_exposes': '${poort}',
    'name': '${app_naam}',
    'domains': '${domein}',
}))
")

title "Controleer de gegevens"
echo "$payload" | python3 -m json.tool
echo ""
if ! confirm "Applicatie aanmaken in Coolify?" "j"; then
    warn "Geannuleerd."
    exit 0
fi

# --- Stap 4: aanmaken ---
info "Applicatie aanmaken..."
create_response=$(api POST "/api/v1/applications/public" "$payload")

app_uuid=$(echo "$create_response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('uuid',''))" 2>/dev/null || echo "")

if [[ -z "$app_uuid" ]]; then
    err "Kon de applicatie niet aanmaken. Reactie van Coolify:"
    echo "$create_response"
    echo ""
    echo "Kom je er niet uit? Gebruik dan de handmatige stappen in PUBLICEREN.md."
    exit 1
fi

ok "Applicatie aangemaakt (uuid: ${app_uuid})"
save_env_var "COOLIFY_APP_UUID" "$app_uuid"

# --- Stap 5: direct deployen ---
if confirm "Nu meteen deployen?" "j"; then
    deploy_response=$(api POST "/api/v1/deploy?uuid=${app_uuid}")
    ok "Deploy gestart. Volg de voortgang in Coolify → Deployments."
    echo "$deploy_response" | python3 -m json.tool 2>/dev/null || echo "$deploy_response"
fi

title "Volgende stap"
echo "De applicatie draait nu (of is bezig met bouwen), maar is nog niet bereikbaar"
echo "via internet. Voeg daarvoor een Cloudflare-route toe:"
echo ""
if confirm "Nu meteen de Cloudflare-route instellen?" "j"; then
    "${SCRIPT_DIR}/cloudflare-route-wizard.sh" --hostname "$domein"
else
    echo "  Draai later: scripts/cloudflare-route-wizard.sh"
fi
