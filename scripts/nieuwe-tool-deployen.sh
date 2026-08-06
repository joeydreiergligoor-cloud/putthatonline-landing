#!/usr/bin/env bash
# Wizard: nieuwe tool deployen — van een lokale map met Dockerfile tot een
# volledig werkend, publiek subdomein. Automatiseert wat voorheen handmatig
# gebeurde tussen het Coolify-dashboard, het Cloudflare-dashboard en de
# terminal (git push, applicatie aanmaken, domein koppelen, deployen,
# tunnel-route toevoegen, en controleren dat het ook echt werkt).
#
# Gebruik:
#   bash scripts/nieuwe-tool-deployen.sh [--dry-run]
#
# Vereiste environment variables (of eenmalig in .wizard.env, zie
# NIEUWE-TOOL-DEPLOYEN.md):
#   COOLIFY_BASE_URL, COOLIFY_API_TOKEN
#   CLOUDFLARE_API_TOKEN, CLOUDFLARE_TUNNEL_ID
# Optioneel (voor automatisch cache-purgen in stap 7):
#   CLOUDFLARE_ZONE_ID

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd curl "sudo apt install curl"
require_cmd jq "sudo apt install jq"
require_cmd git "sudo apt install git"
require_cmd docker "zie https://docs.docker.com/engine/install/"

# --- CLI-opties ---
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            echo "Gebruik: bash scripts/nieuwe-tool-deployen.sh [--dry-run]"
            echo ""
            echo "  --dry-run   Laat zien welke stappen en API-calls zouden"
            echo "              gebeuren, zonder ze echt uit te voeren."
            exit 0
            ;;
        *)
            err "Onbekende optie: ${arg}"
            exit 1
            ;;
    esac
done

title "Wizard: nieuwe tool deployen"
echo "Dit zet een lokale map met een Dockerfile om in een volledig werkend,"
echo "publiek subdomein — Coolify-applicatie, Cloudflare-route en (optioneel)"
echo "een kaart op de landingspagina, in één doorloop."
if $DRY_RUN; then
    echo ""
    warn "Dry-run modus: er wordt niets aangemaakt, gewijzigd of gedeployed."
fi
echo ""

# ==========================================================================
# Helpers
# ==========================================================================

# --- Geheime waarde vragen zonder ze op het scherm te tonen (bv. PAT) ---
ask_secret() {
    local prompt="$1"
    local result
    read -r -s -p "$(echo -e "${C_BOLD}${prompt}${C_RESET}: ")" result
    echo "" >&2
    echo "$result"
}

# --- Leest JSON (lijst, of {"data": [...]}) en laat de gebruiker kiezen.
#     Print het gekozen uuid op stdout. (Zelfde patroon als in
#     coolify-app-wizard.sh, maar met jq in plaats van python3.) ---
pick_from_list() {
    local label="$1" json="$2"
    local items
    items=$(echo "$json" | jq -r '
        (if type == "array" then . else (.data // []) end) as $list
        | $list
        | to_entries[]
        | "\(.key)\t\(.value.uuid)\t\(.value.name // .value.uuid)"
    ')
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

# --- Coolify API-aanroep (leesacties, draaien ook tijdens --dry-run) ---
coolify_api() {
    local method="$1" path="$2" data="${3:-}"
    if [[ -n "$data" ]]; then
        curl -sS -X "$method" "${COOLIFY_BASE_URL%/}${path}" \
            -H "Authorization: Bearer ${COOLIFY_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "$data"
    else
        curl -sS -X "$method" "${COOLIFY_BASE_URL%/}${path}" \
            -H "Authorization: Bearer ${COOLIFY_API_TOKEN}"
    fi
}

# --- Coolify API-aanroep die iets wijzigt: in --dry-run alleen tonen ---
coolify_api_mutate() {
    local method="$1" path="$2" data="${3:-}"
    if $DRY_RUN; then
        echo "" >&2
        info "[dry-run] ${method} ${COOLIFY_BASE_URL%/}${path}"
        [[ -n "$data" ]] && echo "$data" | jq . >&2
        echo '{}'
        return 0
    fi
    coolify_api "$method" "$path" "$data"
}

# --- git-commando dat in --dry-run alleen getoond wordt ---
run_git() {
    if $DRY_RUN; then
        info "[dry-run] git $*"
        return 0
    fi
    git "$@"
}

# --- Zorgt dat .gitignore de nodige regels bevat, zonder iets te
#     overschrijven. Schrijft het hele bestand in één keer weg. ---
ensure_gitignore_entries() {
    local file="${PROJECT_ROOT}/.gitignore"
    local required=(".wizard.env" ".env" ".env.*" "node_modules/" "dist/" "*.bak")
    local existing=()
    [[ -f "$file" ]] && mapfile -t existing < "$file"
    local missing=() entry line found
    for entry in "${required[@]}"; do
        found=false
        for line in "${existing[@]}"; do
            [[ "$line" == "$entry" ]] && { found=true; break; }
        done
        $found || missing+=("$entry")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi
    if $DRY_RUN; then
        info "[dry-run] .gitignore zou aangevuld worden met: ${missing[*]}"
        return 0
    fi
    {
        printf '%s\n' "${existing[@]}"
        [[ ${#existing[@]} -gt 0 ]] && echo ""
        echo "# Toegevoegd door nieuwe-tool-deployen.sh"
        printf '%s\n' "${missing[@]}"
    } > "${file}.new"
    mv "${file}.new" "$file"
    ok ".gitignore aangevuld met: ${missing[*]}"
}

# ==========================================================================
# Vereiste credentials controleren (voordat we vragen gaan stellen)
# ==========================================================================

title "Environment variables controleren"

COOLIFY_BASE_URL="${COOLIFY_BASE_URL:-${COOLIFY_URL:-}}"
COOLIFY_API_TOKEN="${COOLIFY_API_TOKEN:-${COOLIFY_TOKEN:-}}"
if [[ -z "$COOLIFY_BASE_URL" || -z "$COOLIFY_API_TOKEN" ]]; then
    err "COOLIFY_BASE_URL en/of COOLIFY_API_TOKEN ontbreken."
    echo ""
    echo "  Zet ze als environment variable, of eenmalig in ${ENV_FILE}"
    echo "  (wordt automatisch geladen, staat niet in git):"
    echo "    COOLIFY_BASE_URL=\"https://coolify.putthatonline.com\""
    echo "    COOLIFY_API_TOKEN=\"...\""
    echo ""
    echo "  Token aanmaken: open je Coolify-dashboard → Keys & Tokens →"
    echo "  API tokens → Create New Token."
    echo ""
    echo "  (Draaide je eerder al coolify-app-wizard.sh of coolify-deploy.sh?"
    echo "  Dan wordt het daar opgeslagen COOLIFY_URL/COOLIFY_TOKEN"
    echo "  automatisch hergebruikt.)"
    exit 1
fi

CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"
CLOUDFLARE_TUNNEL_ID="${CLOUDFLARE_TUNNEL_ID:-${CF_TUNNEL_ID:-}}"
if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
    err "CLOUDFLARE_API_TOKEN ontbreekt."
    echo ""
    echo "  Zet 'm als environment variable, of eenmalig in ${ENV_FILE}:"
    echo "    CLOUDFLARE_API_TOKEN=\"...\""
    echo ""
    echo "  Token aanmaken: dash.cloudflare.com → My Profile → API Tokens →"
    echo "  Create Token, met rechten 'Cloudflare Tunnel: Edit' + 'Zone:"
    echo "  Cache Purge' voor de zone van putthatonline.com."
    echo ""
    echo "  (Draaide je eerder al cloudflare-route-wizard.sh? Dan wordt het"
    echo "  daar opgeslagen CF_API_TOKEN automatisch hergebruikt.)"
    exit 1
fi
if [[ -z "$CLOUDFLARE_TUNNEL_ID" ]]; then
    err "CLOUDFLARE_TUNNEL_ID ontbreekt."
    echo "  Te vinden via: Zero Trust → Networks → Tunnels → jouw tunnel."
    echo "  Zet 'm als environment variable, of eenmalig in ${ENV_FILE} als"
    echo "  CLOUDFLARE_TUNNEL_ID=\"...\"."
    exit 1
fi
ok "Coolify- en Cloudflare-credentials gevonden."

CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
if [[ -z "$CLOUDFLARE_ZONE_ID" ]]; then
    warn "CLOUDFLARE_ZONE_ID niet gezet — automatisch cache-purgen (stap 7)"
    warn "is dan niet mogelijk, de rest werkt gewoon door. Te vinden op het"
    warn "Cloudflare-dashboard van putthatonline.com, rechts in de zijbalk."
fi

ensure_gitignore_entries

TOOLS_JSON="${PROJECT_ROOT}/public/tools.json"
domain_root="putthatonline.com"
if [[ -f "$TOOLS_JSON" ]]; then
    root_from_json=$(jq -r '.root // empty' "$TOOLS_JSON" 2>/dev/null || true)
    [[ -n "$root_from_json" ]] && domain_root="$root_from_json"
fi

# ==========================================================================
# Stap 1: gegevens verzamelen
# ==========================================================================

title "Stap 1: gegevens verzamelen"

project_path_input=$(ask "Pad naar de lokale projectmap (met Dockerfile)")
project_path="${project_path_input/#\~/$HOME}"
if [[ ! -d "$project_path" ]]; then
    err "Map niet gevonden: ${project_path}"
    exit 1
fi
project_path="$(cd "$project_path" && pwd)"
if [[ ! -f "${project_path}/Dockerfile" ]]; then
    err "Geen Dockerfile gevonden in ${project_path}."
    exit 1
fi
ok "Dockerfile gevonden in ${project_path}."

# Geleerde les: 'ports:'/'networks:' in Compose omzeilt de Traefik-proxy.
compose_file=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    [[ -f "${project_path}/${f}" ]] && compose_file="${project_path}/${f}"
done
if [[ -n "$compose_file" ]] && grep -qE '^\s*(ports|networks):' "$compose_file"; then
    warn "Gevonden in $(basename "$compose_file"): een 'ports:' en/of 'networks:'-regel."
    warn "Coolify's documentatie waarschuwt hier expliciet voor: 'ports:' omzeilt"
    warn "de proxy, en een eigen 'networks:' kan Traefik de container laten"
    warn "kwijtraken. Verwijder deze regel(s) handmatig, tenzij je weet wat je doet."
fi

# Geleerde les: CORS op de backend vermijden, reverse-proxy gebruiken.
if confirm "Roept deze tool vanuit browser-JS een aparte backend/API op een ander subdomein aan?" "n"; then
    warn "Zet dan geen CORS-headers op die backend — gebruik in plaats daarvan"
    warn "een nginx reverse-proxy (proxy_pass server-naar-server) met een"
    warn "relatieve URL in de frontend. CORS-headers toevoegen vereist vaak"
    warn "een fork van een extern project; een reverse-proxy niet."
fi

subdomain_input=$(ask "Gewenst subdomein (bv. nieuwetool)")
subdomain=$(echo "$subdomain_input" | tr '[:upper:]' '[:lower:]')
if ! [[ "$subdomain" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    err "Dat is geen geldig subdomein-label (alleen a-z, 0-9 en -, bv. 'nieuwetool')."
    exit 1
fi
fqdn_host="${subdomain}.${domain_root}"
fqdn="https://${fqdn_host}"

git_repo_url=$(ask "GitHub-repo-URL (bestaand of nog aan te maken)")
if [[ -z "$git_repo_url" ]]; then
    err "Repo-URL mag niet leeg zijn."
    exit 1
fi

container_port=$(ask "Containerpoort" "80")
if ! [[ "$container_port" =~ ^[0-9]+$ ]] || (( container_port < 1 || container_port > 65535 )); then
    err "Ongeldige poort: ${container_port}"
    exit 1
fi

# ==========================================================================
# Stap 2: git-status controleren
# ==========================================================================

title "Stap 2: git-status controleren"

if ! git -C "$project_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "Nog geen git-repository in ${project_path}."
    if $DRY_RUN; then
        info "[dry-run] git init -b main"
    elif confirm "Repository hier initialiseren?" "j"; then
        git -C "$project_path" init -b main
        ok "Git-repository geïnitialiseerd."
    else
        err "Zonder git-repository kan er niet gepusht worden."
        exit 1
    fi
fi

name_set=$(git -C "$project_path" config user.name || true)
email_set=$(git -C "$project_path" config user.email || true)
if [[ -z "$name_set" ]]; then
    git_name=$(ask "Git user.name (voor commits in deze map)")
    run_git -C "$project_path" config user.name "$git_name"
fi
if [[ -z "$email_set" ]]; then
    git_email=$(ask "Git user.email (voor commits in deze map)")
    run_git -C "$project_path" config user.email "$git_email"
fi

current_origin=$(git -C "$project_path" remote get-url origin 2>/dev/null || true)
if [[ -z "$current_origin" ]]; then
    run_git -C "$project_path" remote add origin "$git_repo_url"
    $DRY_RUN || ok "Remote 'origin' toegevoegd."
elif [[ "$current_origin" != "$git_repo_url" ]]; then
    warn "Remote 'origin' wijst nu naar: ${current_origin}"
    if confirm "Bijwerken naar ${git_repo_url}?" "n"; then
        run_git -C "$project_path" remote set-url origin "$git_repo_url"
    else
        git_repo_url="$current_origin"
    fi
fi

if [[ -n "$(git -C "$project_path" status --porcelain)" ]]; then
    if $DRY_RUN; then
        info "[dry-run] git add -A && git commit -m 'Deploy: ${subdomain}'"
    elif confirm "Er zijn (nieuwe) wijzigingen — toevoegen en committen?" "j"; then
        git -C "$project_path" add -A
        git -C "$project_path" commit -m "Deploy: ${subdomain}"
        ok "Gecommit."
    fi
fi

git_branch=$(git -C "$project_path" branch --show-current)
[[ -z "$git_branch" ]] && git_branch="main"

if $DRY_RUN; then
    info "[dry-run] git push -u origin ${git_branch}"
else
    push_ok=true
    push_output=$(git -C "$project_path" push -u origin "$git_branch" 2>&1) || push_ok=false
    if $push_ok; then
        ok "Gepusht naar GitHub."
    elif echo "$push_output" | grep -qiE "password authentication|could not read username|authentication failed|support for password"; then
        warn "Wachtwoord-authenticatie werkt niet meer bij GitHub."
        echo "Je hebt een Personal Access Token (PAT) nodig:"
        echo "  github.com → Settings → Developer settings → Personal access"
        echo "  tokens → Fine-grained tokens → Generate new token"
        echo "  Rechten: 'Contents: Read and write', alleen voor deze repository."
        echo ""
        pat=$(ask_secret "Personal Access Token")
        if [[ -z "$pat" ]]; then
            err "Geen token opgegeven — kan niet pushen."
            exit 1
        fi
        if confirm "Dit token onthouden voor volgende keer (git credential.helper store, onversleuteld op schijf)?" "n"; then
            git -C "$project_path" config credential.helper store
            printf 'protocol=https\nhost=github.com\nusername=git\npassword=%s\n\n' "$pat" | git -C "$project_path" credential approve
            ok "Token opgeslagen via credential.helper store."
        fi
        # Token alleen voor déze ene push in de URL, nooit op schijf opgeslagen
        # tenzij hierboven expliciet bevestigd.
        auth_url="${git_repo_url/https:\/\//https://${pat}@}"
        git -C "$project_path" push -u "$auth_url" "$git_branch"
        ok "Gepusht naar GitHub."
    else
        err "Push mislukt:"
        echo "$push_output"
        exit 1
    fi
fi

# ==========================================================================
# Stap 3 + 4: Coolify-applicatie aanmaken/bijwerken (met volledig schema
# in het domeinveld — zonder https:// blijft COOLIFY_FQDN leeg en werkt de
# routing niet).
# ==========================================================================

title "Stap 3: Coolify-applicatie"

app_uuid_var="APP_UUID_$(echo "$subdomain" | tr '[:lower:]-' '[:upper:]_')"
app_uuid="${!app_uuid_var:-}"
app_name="putthatonline-${subdomain}"

if [[ -z "$app_uuid" ]]; then
    info "Bestaande applicaties ophalen om te controleren of '${subdomain}' al bestaat..."
    apps_json=$(coolify_api GET "/api/v1/applications")
    app_uuid=$(echo "$apps_json" | jq -r --arg n "$app_name" '[.[] | select(.name==$n)][0].uuid // empty')
fi

if [[ -n "$app_uuid" ]]; then
    ok "Bestaande Coolify-applicatie gevonden (${app_uuid}) — deze wordt bijgewerkt."
    payload=$(jq -n \
        --arg repo "$git_repo_url" \
        --arg branch "$git_branch" \
        --arg port "$container_port" \
        --arg domain "$fqdn" \
        '{git_repository:$repo, git_branch:$branch, build_pack:"dockerfile", ports_exposes:$port, domains:$domain}')
    echo "$payload" | jq .
    if $DRY_RUN || confirm "Deze wijzigingen doorvoeren?" "j"; then
        coolify_api_mutate PATCH "/api/v1/applications/${app_uuid}" "$payload" >/dev/null
        $DRY_RUN || ok "Applicatie bijgewerkt."
    else
        warn "Geannuleerd."
        exit 0
    fi
else
    project_uuid="${COOLIFY_PROJECT_UUID:-}"
    server_uuid="${COOLIFY_SERVER_UUID:-}"

    if [[ -z "$project_uuid" ]]; then
        projects_json=$(coolify_api GET "/api/v1/projects")
        project_uuid=$(pick_from_list "projecten" "$projects_json")
        [[ -z "$project_uuid" ]] && { err "Geen geldige keuze."; exit 1; }
        confirm "Dit project onthouden voor volgende keer?" "j" && save_env_var "COOLIFY_PROJECT_UUID" "$project_uuid"
    fi
    if [[ -z "$server_uuid" ]]; then
        servers_json=$(coolify_api GET "/api/v1/servers")
        server_uuid=$(pick_from_list "servers" "$servers_json")
        [[ -z "$server_uuid" ]] && { err "Geen geldige keuze."; exit 1; }
        confirm "Deze server onthouden voor volgende keer?" "j" && save_env_var "COOLIFY_SERVER_UUID" "$server_uuid"
    fi
    environment_name="${COOLIFY_ENVIRONMENT_NAME:-production}"

    payload=$(jq -n \
        --arg project "$project_uuid" \
        --arg server "$server_uuid" \
        --arg env "$environment_name" \
        --arg repo "$git_repo_url" \
        --arg branch "$git_branch" \
        --arg port "$container_port" \
        --arg name "$app_name" \
        --arg domain "$fqdn" \
        '{project_uuid:$project, server_uuid:$server, environment_name:$env, git_repository:$repo, git_branch:$branch, build_pack:"dockerfile", ports_exposes:$port, name:$name, domains:$domain}')

    title "Nieuwe Coolify-applicatie"
    echo "$payload" | jq .
    if ! $DRY_RUN && ! confirm "Aanmaken?" "j"; then
        warn "Geannuleerd."
        exit 0
    fi

    create_response=$(coolify_api_mutate POST "/api/v1/applications/public" "$payload")
    app_uuid=$(echo "$create_response" | jq -r '.uuid // empty')

    if $DRY_RUN; then
        app_uuid="dry-run-app-uuid"
    elif [[ -z "$app_uuid" ]]; then
        err "Kon de applicatie niet aanmaken. Reactie van Coolify:"
        echo "$create_response"
        exit 1
    else
        ok "Applicatie aangemaakt (uuid: ${app_uuid})"
        save_env_var "$app_uuid_var" "$app_uuid"
    fi
fi

# ==========================================================================
# Stap 5: deployen en pollen
# ==========================================================================

title "Stap 5: deployen"

if $DRY_RUN; then
    info "[dry-run] POST /api/v1/deploy?uuid=${app_uuid}"
    info "[dry-run] Deployment-status zou gepolld worden tot finished/failed."
else
    deploy_response=$(coolify_api POST "/api/v1/deploy?uuid=${app_uuid}")
    deployment_uuid=$(echo "$deploy_response" | jq -r '.deployments[0].deployment_uuid // empty')
    if [[ -z "$deployment_uuid" ]]; then
        err "Kon geen deploy starten. Reactie van Coolify:"
        echo "$deploy_response"
        exit 1
    fi
    info "Deploy gestart (${deployment_uuid}), voortgang volgen..."

    status="queued"
    elapsed=0
    interval=5
    timeout=900
    deployment_json='{}'
    while [[ "$status" == "queued" || "$status" == "in_progress" ]]; do
        sleep "$interval"
        elapsed=$((elapsed + interval))
        deployment_json=$(coolify_api GET "/api/v1/deployments/${deployment_uuid}")
        status=$(echo "$deployment_json" | jq -r '.status // "unknown"')
        echo -ne "  status: ${status}   (${elapsed}s)\r"
        if (( elapsed >= timeout )); then
            echo ""
            err "Timeout: deployment is na ${timeout} seconden nog niet klaar."
            exit 1
        fi
    done
    echo ""

    raw_logs=$(echo "$deployment_json" | jq -r '.logs // empty')
    log_lines=$(echo "$raw_logs" | jq -r '.[] | .output // empty' 2>/dev/null) || true
    [[ -z "$log_lines" ]] && log_lines="$raw_logs"

    if [[ "$status" == "finished" ]]; then
        ok "Deploy geslaagd. Laatste logregels:"
        echo "$log_lines" | tail -n 20
    else
        err "Deploy mislukt (status: ${status}). Laatste logregels:"
        echo "$log_lines" | tail -n 60
        exit 1
    fi
fi

# ==========================================================================
# Stap 6: Cloudflare Tunnel-route toevoegen
# ==========================================================================

title "Stap 6: Cloudflare Tunnel-route"

# Geef de credentials door aan de bestaande route-wizard onder zijn eigen
# variabelenamen, zodat die niet opnieuw hoeft te vragen.
export CF_API_TOKEN="${CF_API_TOKEN:-$CLOUDFLARE_API_TOKEN}"
export CF_TUNNEL_ID="${CF_TUNNEL_ID:-$CLOUDFLARE_TUNNEL_ID}"

cf_args=(--hostname "$fqdn_host" --service "https://localhost:443" --no-tls-verify --yes)
$DRY_RUN && cf_args+=(--dry-run)

"${SCRIPT_DIR}/cloudflare-route-wizard.sh" "${cf_args[@]}"

# ==========================================================================
# Stap 7: verificatie
# ==========================================================================

title "Stap 7: verificatie"

if $DRY_RUN; then
    info "[dry-run] docker ps, lokale curl en externe curl worden overgeslagen."
else
    echo "Container-status (uuid ${app_uuid}):"
    if docker ps --filter "name=${app_uuid}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "${app_uuid}"; then
        docker ps --filter "name=${app_uuid}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        warn "Geen container gevonden op naam — proberen via Coolify-label..."
        docker ps --filter "label=coolify.applicationId=${app_uuid}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi

    info "Origin (Traefik) rechtstreeks testen, los van Cloudflare..."
    origin_code=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost:443" -H "Host: ${fqdn_host}" || echo "000")
    echo "  https://localhost:443 (Host: ${fqdn_host}) → ${origin_code}"

    info "Even wachten zodat DNS/SSL bij Cloudflare kan bijtrekken..."
    sleep 5

    info "Publieke URL testen..."
    external_code=$(curl -s -o /dev/null -w "%{http_code}" "https://${fqdn_host}" || echo "000")
    echo "  https://${fqdn_host} → ${external_code}"

    if [[ "$origin_code" =~ ^[23][0-9][0-9]$ && "$origin_code" != "$external_code" ]]; then
        warn "Origin (${origin_code}) en publieke URL (${external_code}) wijken af."
        warn "Dit wijst meestal op een verouderde Cloudflare edge-cache."
        if [[ -n "$CLOUDFLARE_ZONE_ID" ]]; then
            if confirm "Cache voor ${fqdn}/ purgen bij Cloudflare (Custom Purge, niet alles)?" "j"; then
                purge_payload=$(jq -n --arg u "${fqdn}/" '{files: [$u]}')
                purge_response=$(curl -sS -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/purge_cache" \
                    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
                    -H "Content-Type: application/json" \
                    --data "$purge_payload")
                if echo "$purge_response" | jq -e '.success == true' >/dev/null 2>&1; then
                    ok "Cache gepurged voor ${fqdn}/."
                else
                    err "Cache purgen mislukt. Reactie van Cloudflare:"
                    echo "$purge_response"
                fi
            fi
        else
            warn "CLOUDFLARE_ZONE_ID niet gezet — purge zelf handmatig via het"
            warn "Cloudflare-dashboard, of zet deze env var en draai opnieuw."
        fi
    elif [[ "$origin_code" == "$external_code" && "$origin_code" =~ ^[23][0-9][0-9]$ ]]; then
        ok "Origin en publieke URL komen overeen (${origin_code}) — het werkt."
    else
        warn "Status is nog niet groen (origin: ${origin_code}, extern: ${external_code})."
        warn "Geef DNS/SSL wat meer tijd en controleer daarna opnieuw."
    fi
fi

# ==========================================================================
# Stap 8: optioneel toevoegen aan de landingspagina
# ==========================================================================

title "Stap 8: landingspagina"

if confirm "Deze tool ook toevoegen aan tools.json op de landingspagina?" "j"; then
    if $DRY_RUN; then
        info "[dry-run] scripts/voeg-tool-toe.sh zou aangeroepen worden voor ${subdomain}."
    else
        tool_naam=$(ask "Naam zoals die op de kaart moet komen" "$subdomain")
        tool_omschrijving=$(ask "Korte omschrijving (één zin)")
        tool_categorie=$(ask "Categorie" "Overig")
        "${SCRIPT_DIR}/voeg-tool-toe.sh" \
            --naam "$tool_naam" \
            --subdomein "$fqdn_host" \
            --omschrijving "$tool_omschrijving" \
            --categorie "$tool_categorie" \
            --status online \
            --yes
    fi
fi

# ==========================================================================
title "Klaar"
# ==========================================================================

if $DRY_RUN; then
    echo "Dry-run afgerond — er is niets aangemaakt of gewijzigd."
    echo "Draai zonder --dry-run om deze stappen echt uit te voeren."
else
    echo "${fqdn} zou nu bereikbaar moeten zijn."
    echo "Coolify-applicatie-uuid: ${app_uuid}"
fi
