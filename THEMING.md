# Vormgeving wisselen (theming)

Deze site is gebouwd als **template**: de structuur (React-componenten) en
de **stijl** (kleur, typografie, randen, snelheid van animaties) staan
volledig los van elkaar. Je hoeft nooit een `.tsx`-bestand te bewerken om
de site een ander uiterlijk te geven.

## Met de wizard (aanbevolen)

```bash
bash scripts/wissel-thema.sh
```

Kies een preset uit de lijst. De wizard maakt een backup, past het thema
toe, en biedt aan om te committen/pushen en Coolify te laten redeployen.

## Hoe het werkt

Alle stijlkeuzes staan in **één bestand**: `src/theme/tokens.css`. Dit zijn
CSS-variabelen (custom properties) die kleur, lettertype, randafronding en
animatiesnelheid bepalen:

```css
:root {
  --color-bg: 18 21 27;        /* achtergrond, als "R G B" */
  --color-accent: 201 162 39;  /* hoofdaccentkleur */
  --font-display: "JetBrains Mono", ui-monospace, monospace;
  --font-body: "IBM Plex Sans", system-ui, sans-serif;
  --radius-card: 0.5rem;       /* hoekafronding van kaarten */
  --motion-medium: 400ms;      /* snelheid van instap-animaties */
  /* ... */
}
```

Componenten gebruiken **nooit** een kleur- of lettertypenaam rechtstreeks —
altijd een Tailwind-klasse die naar deze variabelen verwijst (bv.
`bg-panel`, `text-accent`, `font-display`). Daardoor verandert het hele
uiterlijk zodra je alleen dit ene bestand aanpast.

## Zelf een kleur/lettertype aanpassen

Open `src/theme/tokens.css` en pas een waarde aan. Bijvoorbeeld, een andere
accentkleur:

```css
--color-accent: 59 130 246; /* nu blauw i.p.v. brass */
```

Test lokaal met `npm run dev`. Wil je een ander lettertype? Zorg dat het
geladen wordt (voeg toe aan de Google Fonts-link in `index.html`, of laad
je eigen font-bestand), en verwijs ernaar in `--font-display` / `--font-body`.

## Een volledig nieuwe stijl (preset) maken

1. Kopieer `src/theme/tokens.css` naar `src/theme/presets/<naam>.css`.
2. Pas de waarden aan naar de nieuwe stijl.
3. Draai `bash scripts/wissel-thema.sh` — je preset verschijnt automatisch
   in het lijstje (geen code-wijziging nodig om hem te laten "meedoen").

Er staat één voorbeeld-preset in de map ter inspiratie:

- **Veldnotities** (`src/theme/presets/veldnotities.css`) — warm papier,
  typemachine + serif, bosgroen accent, scherpe hoeken. Compleet andere
  sfeer dan het standaardthema, met exact dezelfde componenten.

## Wat wél en niet "theming" is

Bewust **wel** aanpasbaar via tokens: kleur, lettertype, hoekafronding,
animatiesnelheid. Dit dekt het overgrote deel van "een andere stijl".

Bewust **niet** onderdeel van het thema-systeem: de lay-out-structuur zelf
(hero → schema → filter → kaartgrid → footer) blijft vast. Dat is een
bewuste keuze: een stabiele, geteste structuur hergebruiken is
betrouwbaarder dan bij elke restyle ook de opbouw opnieuw te bouwen. Wil je
een wezenlijk andere pagina-opbouw, dan pas je de componenten in
`src/components/` aan — de tokens blijven dan gewoon werken.

## Lettertypen die al klaarstaan

`index.html` laadt nu alvast de fonts voor beide meegeleverde presets
(IBM Plex Sans, JetBrains Mono, Source Serif 4, Courier Prime), zodat
wisselen tussen die twee presets werkt zonder de HTML te hoeven aanpassen.
Gebruik je een preset met een ander lettertype, voeg die dan toe aan de
`<link>`-tag in `index.html`.
