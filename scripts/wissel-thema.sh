#!/usr/bin/env bash
# Wizard: wissel het uiterlijk (kleur/typografie/vorm) van de site.
# Kopieert een preset uit src/theme/presets/ naar src/theme/tokens.css.
# Componenten hoeven hiervoor NOOIT aangepast te worden.

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

TOKENS="${PROJECT_ROOT}/src/theme/tokens.css"
PRESETS_DIR="${PROJECT_ROOT}/src/theme/presets"

title "Wizard: thema wisselen"

if [[ ! -d "$PRESETS_DIR" ]]; then
    err "Geen presets-map gevonden op ${PRESETS_DIR}."
    exit 1
fi

echo "Beschikbare presets:"
echo "  0) Signaal (huidige/standaard thema, brass op inkt)"
i=1
declare -A preset_paths
for f in "$PRESETS_DIR"/*.css; do
    [[ -e "$f" ]] || continue
    naam=$(basename "$f" .css)
    echo "  ${i}) ${naam}"
    preset_paths[$i]="$f"
    i=$((i + 1))
done

echo ""
keuze=$(ask "Kies een nummer" "0")

if [[ "$keuze" == "0" ]]; then
    warn "Dit is al het standaardthema. Niets gewijzigd."
    exit 0
fi

gekozen_bestand="${preset_paths[$keuze]:-}"
if [[ -z "$gekozen_bestand" ]]; then
    err "Ongeldige keuze."
    exit 1
fi

cp "$TOKENS" "${TOKENS}.bak"
ok "Backup gemaakt: src/theme/tokens.css.bak"

cp "$gekozen_bestand" "$TOKENS"
ok "Thema '$(basename "$gekozen_bestand" .css)' toegepast."

echo ""
echo "Lokaal bekijken: npm run dev"
echo ""

if confirm "Wijziging committen en pushen naar GitHub?" "j"; then
    if command -v git >/dev/null 2>&1 && git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$PROJECT_ROOT" add src/theme/tokens.css
        git -C "$PROJECT_ROOT" commit -m "Wissel thema naar $(basename "$gekozen_bestand" .css)"
        if confirm "Nu ook pushen (git push)?" "j"; then
            git -C "$PROJECT_ROOT" push
            ok "Gepusht naar GitHub."
        fi
    else
        warn "Geen git-repository gevonden — sla dit over."
    fi
fi

if confirm "Coolify nu laten redeployen?" "j"; then
    "${SCRIPT_DIR}/coolify-deploy.sh"
fi
