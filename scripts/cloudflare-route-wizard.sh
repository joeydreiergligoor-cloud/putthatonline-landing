#!/usr/bin/env bash
# Wizard: publieke route toevoegen aan een bestaande Cloudflare Tunnel.
# Haalt eerst de huidige configuratie op, voegt de nieuwe route toe vóór de
# catch-all regel, toont een preview, en zet pas na bevestiging terug.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd curl "sudo apt install curl"
require_cmd python3 "sudo apt install python3"

# --- Optioneel: gegevens direct meegeven vanuit een ander script ---
preset_hostname=""
preset_service=""
no_tls_verify=false
auto_confirm=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hostname) preset_hostname="$2"; shift 2 ;;
        --service) preset_service="$2"; shift 2 ;;
        --no-tls-verify) no_tls_verify=true; shift ;;
        --yes) auto_confirm=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) shift ;;
    esac
done

title "Wizard: Cloudflare Tunnel-route toevoegen"
echo "Hiermee koppel je een subdomein aan een service die al in Coolify draait,"
echo "zonder dat je zelf in het Cloudflare-dashboard hoeft te klikken."
echo ""
echo "Je hebt hiervoor een Cloudflare API-token nodig met minimaal de rechten"
echo "'Cloudflare Tunnel: Edit' (aan te maken via dash.cloudflare.com → My Profile"
echo "→ API Tokens → Create Token)."
echo ""

# --- Stap 1: gegevens laden of opvragen (eenmalig, daarna onthouden) ---
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-}"
CF_TUNNEL_ID="${CF_TUNNEL_ID:-}"

if [[ -z "$CF_API_TOKEN" ]]; then
    CF_API_TOKEN=$(ask "Cloudflare API-token")
    if confirm "Dit token onthouden voor volgende keer? (opgeslagen in .wizard.env, niet in git)" "j"; then
        save_env_var "CF_API_TOKEN" "$CF_API_TOKEN"
    fi
fi
if [[ -z "$CF_ACCOUNT_ID" ]]; then
    CF_ACCOUNT_ID=$(ask "Cloudflare Account ID (te vinden rechtsonder in het dashboard)")
    save_env_var "CF_ACCOUNT_ID" "$CF_ACCOUNT_ID"
fi
if [[ -z "$CF_TUNNEL_ID" ]]; then
    CF_TUNNEL_ID=$(ask "Tunnel ID (Zero Trust → Networks → Tunnels → jouw tunnel)")
    save_env_var "CF_TUNNEL_ID" "$CF_TUNNEL_ID"
fi

API_BASE="https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${CF_TUNNEL_ID}/configurations"

# --- Stap 2: hostname en interne service opvragen ---
hostname="${preset_hostname:-$(ask "Subdomein voor deze route (bv. flow.putthatonline.com)")}"
if [[ -n "$preset_service" ]]; then
    service="$preset_service"
else
    echo ""
    echo "Het 'interne adres' is waar Coolify de container op laat luisteren."
    echo "Zelfde patroon als bij markitdown, bv. containernaam:poort — bv. putthatonline-landing:80"
    service=$(ask "Intern adres (service)")
fi
if [[ ! "$service" =~ ^(http|https|tcp|ssh):// ]] && [[ "$service" != http_status:* ]]; then
    service="http://${service}"
fi

# --- Stap 3: huidige configuratie ophalen ---
info "Huidige tunnel-configuratie ophalen..."
get_response=$(curl -sS -X GET "$API_BASE" -H "Authorization: Bearer ${CF_API_TOKEN}")

success=$(echo "$get_response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
if [[ "$success" != "True" ]]; then
    err "Kon de tunnel-configuratie niet ophalen. Reactie van Cloudflare:"
    echo "$get_response"
    exit 1
fi

# --- Stap 4: nieuwe ingress-lijst opbouwen (bestaande routes blijven staan) ---
new_config=$(echo "$get_response" | python3 - "$hostname" "$service" "$no_tls_verify" <<'PYEOF'
import json
import sys

hostname, service, no_tls_verify = sys.argv[1], sys.argv[2], sys.argv[3] == "true"
data = json.load(sys.stdin)
ingress = data.get("result", {}).get("config", {}).get("ingress", []) or []

# Verwijder een eventueel al bestaande regel voor dezelfde hostname
ingress = [r for r in ingress if r.get("hostname") != hostname]

# Laatste regel is meestal de catch-all (geen hostname). Nieuwe regel ervoor zetten.
new_rule = {"hostname": hostname, "service": service}
if no_tls_verify:
    new_rule["originRequest"] = {"noTLSVerify": True}
if ingress and "hostname" not in ingress[-1]:
    ingress.insert(len(ingress) - 1, new_rule)
else:
    ingress.append(new_rule)
    ingress.append({"service": "http_status:404"})

print(json.dumps({"config": {"ingress": ingress}}, indent=2))
PYEOF
)

title "Preview van de nieuwe configuratie"
echo "$new_config"
echo ""
warn "Dit vervangt de volledige route-lijst van de tunnel. Bestaande routes"
warn "(zoals markitdown) blijven staan, maar controleer de preview hierboven."

if $DRY_RUN; then
    info "[dry-run] PUT ${API_BASE} zou hierboven getoond worden doorgevoerd."
    exit 0
fi

if ! $auto_confirm && ! confirm "Doorvoeren bij Cloudflare?" "n"; then
    warn "Geannuleerd, er is niets gewijzigd bij Cloudflare."
    exit 0
fi

# --- Stap 5: doorvoeren ---
put_response=$(curl -sS -X PUT "$API_BASE" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$new_config")

put_success=$(echo "$put_response" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success', False))" 2>/dev/null || echo "False")
if [[ "$put_success" == "True" ]]; then
    ok "Route toegevoegd: https://${hostname} → ${service}"
    echo "Let op: DNS/SSL kan 1-2 minuten nodig hebben voordat het werkt."
else
    err "Cloudflare gaf een foutmelding:"
    echo "$put_response"
    exit 1
fi
