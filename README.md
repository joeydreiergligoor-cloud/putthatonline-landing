# putthatonline.com — landingspagina

Directory-pagina voor je self-hosted tools. Elke tool staat op een eigen
subdomein; deze pagina toont ze in een overzicht en linkt ernaartoe.

## Lokaal draaien

```bash
npm install
npm run dev
```

## Publiceren en tools toevoegen: gebruik de wizards

```bash
bash scripts/wizard.sh
```

Dit hoofdmenu leidt je naar:
1. **Landingspagina voor het eerst publiceren** — maakt de Coolify-applicatie
   aan en stelt de Cloudflare-route in, via de API's van beide diensten.
2. **Nieuwe tool toevoegen** — vult `public/tools.json` correct aan
   (met backup en validatie), commit/pusht optioneel naar GitHub, en kan
   meteen redeployen en een Cloudflare-route toevoegen.
3. **Alleen een Cloudflare-route toevoegen of aanpassen**.
4. **Alleen Coolify laten redeployen**.

Zie **PUBLICEREN.md** en **TOOL-TOEVOEGEN.md** voor de uitgebreide,
beginner-vriendelijke uitleg per stap (inclusief een handmatige bijlage
voor wie liever geen API-tokens gebruikt).

Benodigdheden op je machine: `bash`, `curl`, `python3`, `git` — op WSL
Ubuntu staan die er meestal al op.

API-tokens en andere instellingen worden na de eerste keer opgeslagen in
`.wizard.env` (niet in git, staat in `.gitignore`).

## Vormgeving wisselen

```bash
bash scripts/wissel-thema.sh
```

De hele stijl (kleur, typografie, randen, animatiesnelheid) zit in één
bestand: `src/theme/tokens.css`. Componenten verwijzen er alleen naar, dus
een preset toepassen verandert het hele uiterlijk zonder dat je ergens in
`src/components/` hoeft te komen. Zie **THEMING.md** voor de uitleg en hoe
je een eigen preset maakt. Er staat één alternatief voorbeeld klaar in
`src/theme/presets/veldnotities.css` ter inspiratie.

## Wat er verder in zit (SOTA-polish)

- **Geanimeerd routingschema** — de takken naar elke tool "tekenen"
  zichzelf bij het laden, met een "+N"-knoop zodra er meer dan 7 tools
  zijn (`src/components/RoutingDiagram.tsx`).
- **Zoeken en filteren op categorie** — verschijnt automatisch zodra dat
  nuttig wordt (meer dan 5 tools of meer dan 1 categorie).
- **Skeleton-loader** tijdens het laden van `tools.json`, in plaats van
  kale laadtekst.
- **Eigen favicon** (`public/favicon.svg`) en **OG-afbeelding**
  (`public/og-image.png`) passend bij het schema-motief, zodat gedeelde
  links er ook op sociale media/Slack goed uitzien.
- **Toegankelijkheid**: focus-states, semantische HTML,
  `prefers-reduced-motion` volledig gerespecteerd (animaties + delays
  worden dan uitgeschakeld, niet alleen versneld).

## Belangrijk om te weten

- Pure static site, geen backend, geen data-opslag.
- `tools.json` wordt at runtime opgehaald (`fetch`), niet ingebakken in de
  React-bundle — vandaar de no-cache header in `nginx.conf`. Na de wizard
  is een redeploy dus voldoende, een rebuild is niet strikt nodig zolang
  het bestand in de image wordt meegebouwd.
- Toegankelijkheid: focus-states, semantische HTML, `prefers-reduced-motion`
  gerespecteerd (het schema-diagram is decoratief en verborgen op mobiel).
