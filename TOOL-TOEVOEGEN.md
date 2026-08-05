# Nieuwe tool toevoegen aan de landingspagina

Er zijn twee manieren om dit te doen:

- **Met de wizard** (aanbevolen) — beantwoord een paar vragen, de rest gaat
  automatisch.
- **Handmatig** — bewerk zelf het bestand `tools.json` op GitHub (zie
  bijlage onderaan).

**Let op:** zorg dat de tool zelf al werkt op zijn eigen subdomein
(bijvoorbeeld al gedeployed in Coolify) vóórdat je hem toevoegt aan de
landingspagina.

---

## Met de wizard

Open een terminal (in WSL) in de projectmap en voer uit:

```bash
bash scripts/wizard.sh
```

Kies optie **2) Nieuwe tool toevoegen aan de landingspagina**. Of draai het
script direct:

```bash
bash scripts/voeg-tool-toe.sh
```

De wizard vraagt achtereenvolgens:

1. **Naam van de tool** — bv. "ActivePieces".
2. **Unieke code (slug)** — wordt automatisch voorgesteld op basis van de
   naam, je kunt hem aanpassen.
3. **Subdomein** — wordt automatisch voorgesteld als `<slug>.putthatonline.com`.
4. **Korte omschrijving** — één zin die uitlegt wat de tool doet.
5. **Categorie** — bv. "Automation" of "Conversie".
6. **Status** — kies uit een menu: online (klikbaar), soon (aangekondigd) of
   offline.

Daarna:

- Laat de wizard een **overzicht** zien — controleer dit voordat je
  bevestigt.
- Maakt automatisch een **backup** van `tools.json` (`tools.json.bak`) en
  controleert dat het resultaat geldig blijft, dus je kunt niets stuk
  maken aan de bestandsopmaak.
- Vraagt of je de wijziging naar GitHub wilt **committen en pushen**.
- Vraagt of Coolify de landingspagina meteen moet **redeployen**.
- Vraagt of je meteen ook de **Cloudflare-route** voor het nieuwe
  subdomein wilt instellen (alleen bij status "online").

Ga je een tool bijwerken die al bestaat (zelfde slug)? Dan overschrijft de
wizard automatisch het bestaande item, zonder dubbele kaarten te maken.

### Controleren

Open `https://putthatonline.com`, ververs de pagina (eventueel met een
harde refresh: Ctrl+F5 of Cmd+Shift+R). Staat je nieuwe tool erbij? Dan is
het gelukt.

---

## Bijlage: handmatig (zonder wizard)

### Stap 1: open het bestand in GitHub

1. Ga naar je repository op GitHub.
2. Open de map **public** → bestand **tools.json**.
3. Klik rechtsboven op het potlood-icoon om te bewerken.

### Stap 2: voeg het blokje voor je nieuwe tool toe

```json
{
  "slug": "unieke-korte-naam",
  "name": "Naam van de tool",
  "subdomain": "naam.putthatonline.com",
  "description": "Korte, duidelijke omschrijving van wat de tool doet.",
  "category": "bv. Automation, Conversie, Monitoring",
  "status": "online"
}
```

| Veld | Uitleg |
|---|---|
| `slug` | Een unieke, korte code zonder spaties. Alleen intern gebruikt. |
| `name` | De naam zoals hij op de kaart getoond wordt. |
| `subdomain` | Het volledige webadres van de tool. |
| `description` | Eén korte zin. |
| `category` | Een label om tools te groeperen. |
| `status` | `"online"`, `"soon"` of `"offline"`. |

Zet een komma `,` achter het laatste bestaande blokje, plak je nieuwe
blokje erna, en zorg dat het állerlaatste blokje **geen** komma achter
zich heeft.

**Tip:** twijfel je of het bestand nog klopt? Plak de inhoud op
[jsonlint.com](https://jsonlint.com) om te controleren.

### Stap 3: opslaan

Klik **Commit changes**.

### Stap 4: opnieuw deployen in Coolify

Open de applicatie **putthatonline-landing** in Coolify en klik
**Redeploy**.

### Vergeet niet: de tool zelf moet ook bereikbaar zijn

Heb je een nieuw subdomein gebruikt, zorg dan dat je daarvoor ook een
aparte route hebt toegevoegd in Cloudflare Tunnel (**Zero Trust** →
**Networks** → **Tunnels** → **Public Hostname**).
