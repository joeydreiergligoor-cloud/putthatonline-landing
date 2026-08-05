# Landingspagina publiceren (zichtbaar voor de buitenwereld)

Er zijn twee manieren om dit te doen:

- **Met de wizard** (aanbevolen) — beantwoord een paar vragen, de rest gaat
  automatisch.
- **Handmatig** — klik zelf door de Coolify- en Cloudflare-dashboards
  (zie bijlage onderaan). Gebruik dit alleen als je geen API-tokens wilt
  aanmaken.

---

## Met de wizard

### Wat je nodig hebt

Eén keer instellen, daarna onthoudt de wizard alles voor je (in het bestand
`.wizard.env`, dat nooit wordt meegestuurd naar GitHub):

| Wat | Waar te vinden |
|---|---|
| Coolify-adres | De URL van je Coolify-dashboard, bv. `https://coolify.putthatonline.com` |
| Coolify API-token | In Coolify: **Keys & Tokens** → **API tokens** → **Create New Token** |
| Cloudflare API-token | Op [dash.cloudflare.com](https://dash.cloudflare.com) → **My Profile** → **API Tokens** → **Create Token**. Kies rechten **Cloudflare Tunnel: Edit**. |
| Cloudflare Account ID | Rechtsonder op elke pagina van het Cloudflare-dashboard |
| Cloudflare Tunnel ID | **Zero Trust** → **Networks** → **Tunnels** → klik op je tunnel |

### Stap 1: project op GitHub zetten

De wizard maakt de Coolify-applicatie aan vanaf een **publieke**
Git-repository. Zet het project dus eerst op GitHub:

1. Ga naar [github.com](https://github.com) → **+** → **New repository**.
2. Naam bijvoorbeeld `putthatonline-landing`. Kies **Public**.
3. **Add file** → **Upload files** → sleep alle bestanden uit de zip erin →
   **Commit changes**.

### Stap 2: de wizard draaien

Open een terminal (in WSL) in de projectmap en voer uit:

```bash
bash scripts/wizard.sh
```

Kies optie **1) Landingspagina voor het eerst publiceren**. De wizard:

1. Vraagt je Coolify-gegevens (of gebruikt wat je eerder hebt opgeslagen).
2. Laat je een project en server kiezen uit een lijstje.
3. Vraagt de repository-URL, branch, poort (standaard `80`) en het domein
   (`putthatonline.com`).
4. Toont een overzicht — controleer dit voordat je bevestigt.
5. Maakt de applicatie aan en start (optioneel) meteen een deploy.
6. Vraagt of je meteen ook de Cloudflare-route wilt instellen, en doet dat
   dan automatisch — zonder dat je bestaande routes (zoals markitdown)
   worden aangetast.

### Stap 3: testen

Open `https://putthatonline.com` in je browser. Zie je de pagina? Dan is
het gelukt. Werkt het nog niet meteen, wacht dan 1–2 minuten (DNS/SSL heeft
soms wat tijd nodig) en ververs de pagina.

---

## Bijlage: handmatig (zonder wizard)

**Twee vaktermen vooraf:**
- **Repository (repo)**: een online opslagplaats voor code, bijvoorbeeld op GitHub.
- **Cloudflare Tunnel**: de beveiligde verbinding die je server met internet
  verbindt, zonder dat je poorten op je router hoeft open te zetten.

### Stap 1: project op GitHub zetten
Zie hierboven, stap 1.

### Stap 2: nieuwe applicatie aanmaken in Coolify

1. Log in op je Coolify-dashboard.
2. Klik op **+ New Resource** → **Application**.
3. Kies **Public Repository** en vul de link naar je repository in.
4. Kies bij **Build Pack**: **Dockerfile**.
5. Zet de **Port** op **80**.
6. Klik **Save**.

### Stap 3: domein koppelen

1. Ga naar **Domains** en vul in: `putthatonline.com`.
2. Sla op.

### Stap 4: deployen

1. Klik op **Deploy** en wacht tot de status **Running** is.
2. Foutmelding? Klik op **Logs** om te zien wat er misging.

### Stap 5: route toevoegen in Cloudflare Tunnel

1. Log in op [dash.cloudflare.com](https://dash.cloudflare.com).
2. Ga naar **Zero Trust** → **Networks** → **Tunnels**.
3. Open je bestaande tunnel.
4. **Public Hostname** → **Add a public hostname**.
5. Vul in: Subdomain leeg, Domain `putthatonline.com`, Type HTTP, URL het
   interne adres van je Coolify-applicatie (bv. `putthatonline-landing:80`).
6. **Save hostname**.

### Stap 6: testen

Open `https://putthatonline.com` in je browser.
