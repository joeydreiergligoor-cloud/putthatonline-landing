#!/usr/bin/env bash
# Gedeelde functies voor alle wizard-scripts.
# Wordt ingeladen met: source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# --- Kleuren voor duidelijke output ---
C_RESET='\033[0m'
C_INFO='\033[0;36m'
C_OK='\033[0;32m'
C_WARN='\033[0;33m'
C_ERR='\033[0;31m'
C_BOLD='\033[1m'

info()  { echo -e "${C_INFO}ℹ ${1}${C_RESET}"; }
ok()    { echo -e "${C_OK}✓ ${1}${C_RESET}"; }
warn()  { echo -e "${C_WARN}⚠ ${1}${C_RESET}"; }
err()   { echo -e "${C_ERR}✗ ${1}${C_RESET}" >&2; }
title() { echo -e "\n${C_BOLD}${1}${C_RESET}\n"; }

# --- Vind de projectroot (map waar dit script-pakket in staat) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.wizard.env"

# --- Controleer of een commando bestaat, anders duidelijke foutmelding ---
require_cmd() {
    local cmd="$1"
    local hint="${2:-}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        err "Dit script heeft '${cmd}' nodig, maar dat is niet geïnstalleerd."
        if [[ -n "$hint" ]]; then
            echo "  Installeren: ${hint}"
        fi
        exit 1
    fi
}

# --- Ja/nee-vraag. Gebruik: if confirm "Weet je het zeker?"; then ... fi ---
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local suffix="[j/N]"
    [[ "$default" == "j" ]] && suffix="[J/n]"
    read -r -p "$(echo -e "${C_BOLD}${prompt}${C_RESET} ${suffix} ")" answer
    answer="${answer:-$default}"
    [[ "$answer" =~ ^([jJ]|[yY])$ ]]
}

# --- Vraag om input met eventuele standaardwaarde ---
ask() {
    local prompt="$1"
    local default="${2:-}"
    local result
    if [[ -n "$default" ]]; then
        read -r -p "$(echo -e "${C_BOLD}${prompt}${C_RESET} [${default}]: ")" result
        echo "${result:-$default}"
    else
        read -r -p "$(echo -e "${C_BOLD}${prompt}${C_RESET}: ")" result
        echo "$result"
    fi
}

# --- .wizard.env laden (bevat opgeslagen API-tokens/instellingen) ---
load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$ENV_FILE"
        set +a
    fi
}

# --- Eén sleutel in .wizard.env opslaan of bijwerken, zonder duplicaten ---
save_env_var() {
    local key="$1"
    local value="$2"
    touch "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    python3 - "$ENV_FILE" "$key" "$value" <<'PYEOF'
import sys

path, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, "r") as f:
        lines = f.readlines()
except FileNotFoundError:
    lines = []

found = False
out = []
for line in lines:
    if line.startswith(f"{key}="):
        out.append(f'{key}="{value}"\n')
        found = True
    else:
        out.append(line)
if not found:
    out.append(f'{key}="{value}"\n')

with open(path, "w") as f:
    f.writelines(out)
PYEOF
}

load_env
