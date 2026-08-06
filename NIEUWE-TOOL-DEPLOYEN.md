# Nieuwe tool deployen (volledig automatisch)

Dit is de opvolger van de handmatige workflow: een lokale map met een
`Dockerfile` wordt in één doorloop omgezet in een volledig werkend, publiek
subdomein op `putthatonline.com` — zonder dat je zelf nog hoeft te
schakelen tussen het Coolify-dashboard, het Cloudflare-dashboard en de
terminal.

Deze instructie is geschreven voor als je dit voor het eerst doet: volg de
stappen in volgorde, sla niets over, en je hoeft verder niets te weten dan
wat hier staat.

---

## Checklist voordat je begint

- [ ] Je weet hoe je een **WSL-terminal** opent (stap 1 hieronder legt dit uit).
- [ ] Je hebt toegang tot het **Coolify-dashboard** van je server.
- [ ] Je hebt toegang tot het **Cloudflare-dashboard** van `putthatonline.com`.
- [ ] Docker draait op je machine (Docker Desktop, of de Docker-service in
      WSL) — zonder Docker kan stap 7 van het script (de container-check)
      niet werken.
- [ ] Je hebt 4 tokens/ID's verzameld (stap 3 hieronder legt exact uit hoe).

---

## Stap 1: de juiste terminal openen

Dit script draait in **WSL** (Ubuntu), niet in PowerShell, cmd of Git Bash
op Windows zelf. Twee manieren om er te komen:

**Manier A — Windows Terminal (aanbevolen):**
1. Open de app **Windows Terminal**.
2. Klik op het kleine pijltje-omlaag naast het **+**-tabblad, bovenaan.
3. Kies **Ubuntu-26.04** uit de lijst. Er opent een nieuw tabblad met een
   Linux-prompt (ziet er ongeveer zo uit: `joeydg67@laptop:~$`).

**Manier B — vanuit een gewone Windows-terminal:**
1. Open PowerShell of cmd.
2. Typ:
   ```
   wsl -d Ubuntu-26.04
   ```
3. Je zit nu in dezelfde Linux-prompt als bij manier A.

Vanaf hier werk je alleen nog met Linux-commando's (die hieronder steeds
in code-blokjes staan) — niet meer met PowerShell-syntax.

---

## Stap 2: naar de juiste projectmap

```bash
cd ~/putthatonline-landing
```

**Let op — een valkuil:** er staat op je systeem ook een kopie van dit
project op `C:\pkg\putthatonline-landing`. Die kopie heeft **geen**
git-geschiedenis (`.git`-map) en is niet de plek waar je moet werken.
De echte, met git bijgehouden versie staat altijd op het WSL-pad
`~/putthatonline-landing` (dat is hetzelfde als
`/home/joeydg67/putthatonline-landing`, en vanuit Windows Verkenner
zichtbaar als `\\wsl.localhost\Ubuntu-26.04\home\joeydg67\putthatonline-landing`).
Werk je toch per ongeluk in de `C:\pkg`-kopie, dan gaat er niets naar
GitHub en mis je alle scripts die hier beschreven staan.

Controleer dat je op de juiste plek zit:

```bash
git status
```

Zie je `On branch main` en geen foutmelding, dan zit je goed. Zie je
`fatal: not a git repository`, dan zit je in de verkeerde map.

---

## Stap 3: de 4 verplichte credentials verzamelen

Het script heeft vier gegevens nodig om zelfstandig met Coolify en
Cloudflare te kunnen praten. Zonder deze vier stopt het script meteen met
een duidelijke foutmelding — het gaat nooit "zomaar" door. Verzamel ze nu
één voor één.

### 3a. `COOLIFY_BASE_URL`

Het webadres van je Coolify-dashboard, bijvoorbeeld:
```
https://coolify.putthatonline.com
```
(Dit is het adres dat je al gebruikt om in te loggen op Coolify.)

### 3b. `COOLIFY_API_TOKEN`

1. Log in op je Coolify-dashboard.
2. Ga naar **Keys & Tokens** (in het menu links).
3. Open het tabblad **API tokens**.
4. Klik **Create New Token**.
5. Geef het een herkenbare naam, bv. `nieuwe-tool-deployen`.
6. Geef het **volledige rechten** (root/read-write) — het script maakt en
   wijzigt applicaties en start deploys, dus een read-only token is niet
   genoeg.
7. Klik **Create**. Het token wordt maar **één keer** getoond — kopieer het
   meteen naar een tijdelijke plek (bv. een leeg Kladblok-venster) totdat
   je het in stap 4 hieronder wegzet.

### 3c. `CLOUDFLARE_API_TOKEN`

1. Ga naar [dash.cloudflare.com](https://dash.cloudflare.com) en log in.
2. Klik rechtsboven op je profielicoon → **My Profile**.
3. Open het tabblad **API Tokens**.
4. Klik **Create Token** → **Create Custom Token**.
5. Geef het een naam, bv. `nieuwe-tool-deployen`.
6. Voeg twee permissions toe (via **+ Add more**):
   - **Account** → **Cloudflare Tunnel** → **Edit**
   - **Zone** → **Cache Purge** → **Purge**
7. Beperk bij **Zone Resources** tot de zone van `putthatonline.com` (niet
   "All zones", tenzij je dat bewust wilt).
8. Klik **Continue to summary** → **Create Token**.
9. Kopieer het token — ook dit wordt maar één keer getoond.

### 3d. `CLOUDFLARE_TUNNEL_ID`

1. Ga in het Cloudflare-dashboard naar **Zero Trust** → **Networks** →
   **Tunnels** (de menunamen kunnen ook "Networks" heten zonder "Zero
   Trust" ervoor, afhankelijk van je dashboard-versie).
2. Klik op je tunnel, genaamd `putthatonline-vps`.
3. Op de detailpagina van de tunnel staat de **Tunnel ID** (een lange
   reeks letters/cijfers met streepjes, een zogeheten UUID). Kopieer die.

### 3e. Optioneel: `CLOUDFLARE_ZONE_ID`

Alleen nodig als je wilt dat het script automatisch de Cloudflare-cache
kan legen wanneer een nieuwe tool nog niet meteen zichtbaar is (stap 7 van
het script). Zonder deze variabele werkt de rest van het script gewoon,
maar moet je in dat ene geval zelf even de cache legen via het dashboard.

1. Ga in het Cloudflare-dashboard naar je site **putthatonline.com** (klik
   erop in je lijst met websites).
2. Blijf op het tabblad **Overview**.
3. Scroll naar beneden tot je rechts een blokje **API** ziet.
4. Daar staat **Zone ID** met een kopieer-icoontje ernaast. Klik erop.

---

## Stap 4: de credentials opslaan in `.wizard.env`

Dit bestand staat al in `.gitignore` — het gaat dus nooit naar GitHub.

1. Zorg dat je in de projectmap zit (zie stap 2):
   ```bash
   cd ~/putthatonline-landing
   ```
2. Open (of maak) het bestand met een simpele teksteditor in de terminal:
   ```bash
   nano .wizard.env
   ```
3. Typ (of plak) de volgende regels, en vervang de `...` door de waarden
   die je in stap 3 hebt verzameld. Elke waarde tussen aanhalingstekens:
   ```bash
   COOLIFY_BASE_URL="https://coolify.putthatonline.com"
   COOLIFY_API_TOKEN="..."
   CLOUDFLARE_API_TOKEN="..."
   CLOUDFLARE_TUNNEL_ID="..."
   CLOUDFLARE_ZONE_ID="..."
   ```
   (Liet je stap 3e over, laat die laatste regel dan gewoon weg.)
4. Opslaan in `nano`: druk op **Ctrl+O**, dan **Enter** om de bestandsnaam
   te bevestigen, en daarna **Ctrl+X** om de editor te sluiten.
5. Controleer dat het bestand er staat en niet leeg is:
   ```bash
   cat .wizard.env
   ```
   Je zou nu je eigen regels moeten terugzien (met de echte tokens, niet
   `...`).

Dit hoef je maar **één keer** te doen — zolang je in dezelfde projectmap
blijft werken, leest het script deze waarden voortaan automatisch in.

**Al eerder `coolify-app-wizard.sh` of `cloudflare-route-wizard.sh`
gedraaid?** Dan staan `COOLIFY_URL`/`COOLIFY_TOKEN` en
`CF_API_TOKEN`/`CF_TUNNEL_ID` mogelijk al in je `.wizard.env`. Dit script
herkent en hergebruikt die automatisch — je hoeft ze dan niet nog een keer
onder de nieuwe naam toe te voegen. Alleen `CLOUDFLARE_ZONE_ID` is sowieso
nieuw, want dat had geen van de oudere scripts nodig.

De Cloudflare-route-stap (stap 6 van het script) heeft daarnaast ook nog
een **Cloudflare Account ID** nodig (voor de Tunnel-API). Staat die nog
niet in je `.wizard.env`, dan vraagt het script daar op dat moment zelf
om (rechtsonder op elke pagina van het Cloudflare-dashboard) en onthoudt
'm meteen voor de volgende keer.

---

## Stap 5: wat het script precies doet

Zodra je het script start (zie stap 6 en verder), doorloopt het deze acht
stappen automatisch:

1. **Gegevens verzamelen** — het vraagt je: het pad naar de lokale map met
   je nieuwe tool (met daarin een `Dockerfile`), het gewenste subdomein
   (bv. `nieuwetool`, zonder `.putthatonline.com` erachter), de
   GitHub-repo-URL, en de containerpoort (druk gewoon op **Enter** om de
   standaardwaarde `80` te gebruiken als je twijfelt).
2. **Git-status controleren** — maakt zo nodig een git-repository aan in
   je toolmap, vraagt je git-naam/e-mail als die nog niet ingesteld zijn,
   commit eventuele wijzigingen, en pusht naar GitHub. Werkt wachtwoord-
   inloggen niet meer (GitHub staat dat sinds 2021 niet meer toe), dan
   legt het script exact uit hoe je een Personal Access Token aanmaakt en
   vraagt dat op (verborgen invoerveld, wordt nergens automatisch
   opgeslagen tenzij je dat expliciet bevestigt).
3. **Coolify-applicatie aanmaken of bijwerken** — via de API, met Build
   Pack `dockerfile`. Gebruik je een subdomein dat al eerder is aangemaakt
   met dit script, dan wordt de bestaande applicatie bijgewerkt in plaats
   van dat er een dubbele ontstaat.
4. **Domein correct instellen** — altijd met het volledige
   `https://<subdomein>.putthatonline.com`, nooit alleen de kale naam
   (dat zit verwerkt in de payload van stap 3, geen aparte vraag).
5. **Deployen en volgen** — start de deploy en toont live de status, tot
   die `finished` of `failed` is. Gaat het mis, dan stopt het script
   direct en toont de laatste logregels — het gaat niet automatisch door
   naar de volgende stap.
6. **Cloudflare-route toevoegen** — Type HTTPS, target `localhost:443`,
   met "No TLS Verify" aan, altijd vóór de bestaande wildcard-regel (zodat
   er geen HTTP→HTTPS-redirect-lus ontstaat). Bestaat de route al voor dit
   subdomein, dan wordt hij bijgewerkt in plaats van gedupliceerd.
7. **Verifiëren** — controleert zelf of het ook echt werkt:
   - `docker ps` — draait de container?
   - een lokale test rechtstreeks naar `https://localhost:443` — is de
     Coolify-kant gezond, los van Cloudflare?
   - een test naar de echte publieke URL — komt dat overeen met de lokale
     test? Zo niet, dan wijst dat meestal op een verouderde
     Cloudflare-cache, en biedt het script aan die gericht te legen
     (alleen deze ene URL, nooit "Purge Everything").
8. **Optioneel: landingspagina bijwerken** — vraagt of de tool ook als
   kaart op `putthatonline.com` moet verschijnen, en roept daarvoor het
   bestaande `scripts/voeg-tool-toe.sh` aan.

Onderweg waarschuwt het script ook nog voor twee bekende valkuilen:
- **CORS**: roept de tool vanuit browser-JS een aparte backend/API op een
  ander subdomein aan? Dan raadt het script een nginx reverse-proxy aan in
  plaats van CORS-headers op die backend te zetten.
- **Docker Compose**: staat er een `ports:`- of `networks:`-regel in een
  `docker-compose.yml` in je toolmap, dan waarschuwt het script — beide
  kunnen de Coolify-proxy (Traefik) omzeilen of de container onbereikbaar
  maken.

---

## Stap 6: eerst een droogloop (`--dry-run`)

Voordat er ook maar iets echt gebeurt, kun je het hele traject laten
voorspellen zonder dat er iets wordt aangemaakt, gewijzigd of gedeployed:

```bash
cd ~/putthatonline-landing
bash scripts/nieuwe-tool-deployen.sh --dry-run
```

Beantwoord de vragen zoals je dat ook bij een echte run zou doen. Je ziet
dan bij elke stap een regel die begint met `[dry-run]`, gevolgd door
precies welke API-aanroep zou gebeuren en met welke gegevens. Er wordt
niets naar Coolify of Cloudflare geschreven, en er wordt niet gepusht naar
GitHub. (Lees-acties, zoals je lijst projecten/servers bij Coolify ophalen
om een kloppend voorbeeld te tonen, gebeuren wél — die zijn onschadelijk.)

Klopt alles wat je in de droogloop ziet? Ga dan pas verder naar stap 7.

---

## Stap 7: één keer oefenen met een wegwerp-subdomein

Doe dit vóór je het voor een echte tool gebruikt, zodat je het hele
traject een keer in het echt ziet zonder risico.

1. Maak een tijdelijke testmap met een minimale website erin:
   ```bash
   mkdir -p ~/test-deploy
   cd ~/test-deploy
   echo "<h1>Testpagina</h1>" > index.html
   ```
2. Maak daarin een `Dockerfile`:
   ```bash
   nano Dockerfile
   ```
   Plak deze inhoud:
   ```dockerfile
   FROM nginx:alpine
   COPY index.html /usr/share/nginx/html/index.html
   EXPOSE 80
   ```
   Opslaan: **Ctrl+O**, **Enter**, **Ctrl+X**.
3. Maak op [github.com](https://github.com) een nieuwe, lege **publieke**
   repository aan (bv. genaamd `test-deploy`) — geen bestanden hoeven erin
   te staan, het script pusht ze zelf.
4. Ga terug naar het landingspagina-project en start het script, zonder
   `--dry-run`:
   ```bash
   cd ~/putthatonline-landing
   bash scripts/nieuwe-tool-deployen.sh
   ```
5. Vul bij de vragen in:
   - Pad naar de projectmap: `~/test-deploy`
   - Subdomein: iets unieks, bv. `test-<jouwnaam>`
   - GitHub-repo-URL: de URL van de repository die je in stap 3 aanmaakte
   - Containerpoort: gewoon **Enter** (standaard `80`)
6. Volg de rest van de vragen en bevestig steeds als het script iets wil
   aanmaken of wijzigen.
7. Zodra het script klaar is: open `https://test-<jouwnaam>.putthatonline.com`
   in je browser en controleer of je de testpagina ziet.
8. **Opruimen**: het script verwijdert nooit zelf resources, dus ruim dit
   handmatig weer op:
   - Verwijder de test-applicatie in Coolify (**Application** → **Delete**).
   - Verwijder de route in Cloudflare (**Zero Trust** → **Networks** →
     **Tunnels** → je tunnel → **Public Hostname** → verwijder de regel
     voor `test-<jouwnaam>.putthatonline.com`).
   - Verwijder de GitHub-repository als je die niet wilt bewaren.
   - Als je in stap 8 van het script "ja" zei op de vraag om de tool aan
     de landingspagina toe te voegen: draai daarna
     `bash scripts/voeg-tool-toe.sh`, kies dezelfde slug, en verwijder het
     item weer (of bewerk `public/tools.json` handmatig en verwijder het
     blokje, gevolgd door een commit + push + Coolify-redeploy).

Werkte dit naar wens? Dan weet je zeker dat je credentials en de wizard
goed werken, en kun je 'm voortaan voor je echte tools gebruiken.

---

## Stap 8: een echte tool deployen

Zelfde commando, met je eigen toolmap, subdomein en repository:

```bash
cd ~/putthatonline-landing
bash scripts/nieuwe-tool-deployen.sh
```

Of via het menu:

```bash
bash scripts/wizard.sh
```
en kies optie **6**.

Draai je dit later nog een keer voor **hetzelfde** subdomein (bijvoorbeeld
omdat je iets aan de tool hebt aangepast en opnieuw wilt deployen)? Dat
kan gewoon opnieuw met hetzelfde commando — het script herkent de
bestaande Coolify-applicatie en Cloudflare-route en werkt die bij in
plaats van dubbele aan te maken.

---

## Problemen oplossen

**"COOLIFY_BASE_URL en/of COOLIFY_API_TOKEN ontbreken"**
Je `.wizard.env` mist deze regels, of je zit niet in de juiste projectmap.
Controleer met `cat .wizard.env` (stap 4) en met `pwd` of je in
`~/putthatonline-landing` zit.

**"Wachtwoord-authenticatie werkt niet meer bij GitHub"**
Normaal — GitHub accepteert sinds augustus 2021 geen wachtwoorden meer via
de terminal. Volg de instructies die het script zelf toont om een
Personal Access Token aan te maken; je hoeft niets handmatig te fixen.

**Deploy mislukt (status "failed")**
Het script stopt en toont de laatste logregels van de Coolify-build. Lees
die door — meestal is het een fout in de `Dockerfile` of een ontbrekend
bestand. Los het op in je toolmap, commit/push opnieuw, en draai het
script nogmaals voor hetzelfde subdomein.

**De publieke URL geeft nog een oude/foute pagina, maar de lokale check in
stap 7 van het script was al goed (2xx)**
Dat is een verouderde Cloudflare-cache. Het script biedt automatisch aan
om te purgen als `CLOUDFLARE_ZONE_ID` is ingesteld (stap 3e/4 hierboven).
Zonder die variabele: log in op Cloudflare → **Caching** → **Configuration**
→ **Purge Cache** → **Custom Purge** → vul de volledige URL in (met
`https://` en een `/` erachter).

**Ik weet niet meer zeker of ik in de juiste map zit**
```bash
pwd
git remote -v
```
Dit toont je huidige pad en, als je in een git-repo zit, naar welke
GitHub-repository die verwijst.

---

## Overzicht: alle environment variables

| Variabele | Verplicht | Waar vandaan (zie stap 3) |
|---|---|---|
| `COOLIFY_BASE_URL` | Ja | 3a |
| `COOLIFY_API_TOKEN` | Ja | 3b |
| `CLOUDFLARE_API_TOKEN` | Ja | 3c |
| `CLOUDFLARE_TUNNEL_ID` | Ja | 3d |
| `CLOUDFLARE_ZONE_ID` | Nee — alleen voor automatisch cache-purgen | 3e |

Al deze variabelen leest het script automatisch in via `.wizard.env` in de
projectmap (stap 4), zolang je daar met je terminal in staat. Je kunt ze
ook als "echte" environment variables zetten (bv. met `export` in
`~/.bashrc`), maar voor de meeste mensen is `.wizard.env` eenvoudiger.
