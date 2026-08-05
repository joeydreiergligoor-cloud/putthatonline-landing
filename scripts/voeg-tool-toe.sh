#!/usr/bin/env bash
# Wizard: nieuwe tool toevoegen aan de landingspagina.
# Vervangt het handmatig bewerken van public/tools.json.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

require_cmd python3 "sudo apt install python3"
TOOLS_JSON="${PROJECT_ROOT}/public/tools.json"

title "Wizard: nieuwe tool toevoegen"

if [[ ! -f "$TOOLS_JSON" ]]; then
    err "Kan ${TOOLS_JSON} niet vinden. Draai dit script vanuit de projectmap."
    exit 1
fi

# --- Stap 1: gegevens van de nieuwe tool ---
naam=$(ask "Naam van de tool (bv. ActivePieces)")
if [[ -z "$naam" ]]; then
    err "Naam mag niet leeg zijn."
    exit 1
fi

slug_default=$(echo "$naam" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')
slug=$(ask "Unieke code (slug, geen spaties)" "$slug_default")

subdomein_default="${slug}.putthatonline.com"
subdomein=$(ask "Subdomein" "$subdomein_default")
if ! [[ "$subdomein" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]]; then
    err "Dat ziet er niet uit als een geldig domein (bv. naam.putthatonline.com)."
    exit 1
fi

omschrijving=$(ask "Korte omschrijving (één zin)")
categorie=$(ask "Categorie (bv. Automation, Conversie, Monitoring)" "Overig")

echo ""
echo "Status van de tool:"
echo "  1) online   — direct klikbaar, groen bolletje"
echo "  2) soon     — zichtbaar maar nog niet klikbaar"
echo "  3) offline  — grijs, niet klikbaar"
status_keuze=$(ask "Kies 1, 2 of 3" "1")
case "$status_keuze" in
    2) status="soon" ;;
    3) status="offline" ;;
    *) status="online" ;;
esac

# --- Stap 2: voorbeeld tonen ---
title "Controleer de gegevens"
cat <<EOF
  Naam        : ${naam}
  Slug        : ${slug}
  Subdomein   : ${subdomein}
  Omschrijving: ${omschrijving}
  Categorie   : ${categorie}
  Status      : ${status}
EOF
echo ""
if ! confirm "Toevoegen aan tools.json?" "j"; then
    warn "Geannuleerd, er is niets gewijzigd."
    exit 0
fi

# --- Stap 3: backup + veilig toevoegen via python (geen handmatige komma's) ---
cp "$TOOLS_JSON" "${TOOLS_JSON}.bak"
ok "Backup gemaakt: public/tools.json.bak"

python3 - "$TOOLS_JSON" "$slug" "$naam" "$subdomein" "$omschrijving" "$categorie" "$status" <<'PYEOF'
import json
import sys

path, slug, naam, subdomein, omschrijving, categorie, status = sys.argv[1:8]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

data.setdefault("tools", [])

# Bestaat de slug al? Dan bijwerken in plaats van dupliceren.
existing = next((t for t in data["tools"] if t["slug"] == slug), None)
entry = {
    "slug": slug,
    "name": naam,
    "subdomain": subdomein,
    "description": omschrijving,
    "category": categorie,
    "status": status,
}

if existing:
    idx = data["tools"].index(existing)
    data["tools"][idx] = entry
else:
    data["tools"].append(entry)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

# --- Stap 4: valideren dat het resultaat geldig JSON is ---
if python3 -c "import json; json.load(open('${TOOLS_JSON}'))" 2>/dev/null; then
    ok "tools.json is bijgewerkt en geldig."
else
    err "Er ging iets mis — tools.json is teruggezet naar de vorige versie."
    cp "${TOOLS_JSON}.bak" "$TOOLS_JSON"
    exit 1
fi

# --- Stap 5: optioneel git commit + push ---
if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if confirm "Wijziging committen en pushen naar GitHub?" "j"; then
        git -C "$PROJECT_ROOT" add public/tools.json
        git -C "$PROJECT_ROOT" commit -m "Voeg tool toe: ${naam}"
        if confirm "Nu ook pushen (git push)?" "j"; then
            git -C "$PROJECT_ROOT" push
            ok "Gepusht naar GitHub."
        fi
    fi
else
    warn "Geen git-repository gevonden — sla dit over. Vergeet niet zelf te committen/pushen."
fi

# --- Stap 6: optioneel Coolify redeployen ---
if confirm "Coolify nu laten redeployen?" "j"; then
    "${SCRIPT_DIR}/coolify-deploy.sh"
fi

# --- Stap 7: optioneel Cloudflare-route toevoegen ---
if [[ "$status" == "online" ]]; then
    if confirm "Cloudflare Tunnel-route voor ${subdomein} nu toevoegen?" "j"; then
        "${SCRIPT_DIR}/cloudflare-route-wizard.sh" --hostname "$subdomein"
    fi
fi

title "Klaar"
echo "${naam} staat nu in tools.json. Zodra Coolify klaar is met (re)deployen"
echo "en de Cloudflare-route actief is, verschijnt de tool op je landingspagina."
