# Win Finder

Un file manager per macOS che ti fa sentire a casa — per chi viene da Windows.

🇬🇧 [English](README.md) &nbsp; 🇮🇹 Italiano &nbsp; 🇩🇪 [Deutsch](README.de.md) &nbsp; 🇪🇸 [Español](README.es.md) &nbsp; 🇨🇳 [中文](README.zh.md)

![Win Finder screenshot](docs/screenshot.png)

## Perché Win Finder?

macOS è un ottimo sistema operativo. Ma se hai passato anni su Windows, il Finder ti sembrerà sbagliato in modi difficili da spiegare: nessuna barra del percorso modificabile, nessuna ricerca inline, nessun "Nuovo file" col tasto destro, il tasto Canc non cancella. Piccole cose che sommate creano attrito costante.

Win Finder risolve tutto questo. È un file manager nativo per macOS costruito attorno ai flussi di lavoro che gli utenti Windows già conoscono.

## Funzionalità

- **Barra del percorso modificabile** — sempre visibile, occupa l'80% della larghezza. Cliccala, digita un percorso, premi Invio. Funziona esattamente come Esplora risorse di Windows.
- **Navigazione breadcrumb** — la barra del percorso mostra ogni cartella come un token cliccabile. Clicca un segmento per navigare lì. Clicca il separatore `>` per vedere le sottocartelle di quel livello. Clicca lo spazio vuoto a destra per passare alla modalità testo modificabile.
- **Ricerca inline** — campo di ricerca sempre visibile accanto alla barra del percorso. Ricerca ricorsivamente in tutte le sottocartelle per default. Supporta i wildcard (`*.pdf`, `doc*`). I risultati mostrano il percorso relativo.
- **Barra laterale** — Preferiti (Desktop, Documenti, Download, Immagini), Posizioni, Dispositivi e percorsi Recenti — salvati tra le sessioni.
- **Lista stile Esplora risorse** — colonne Nome, Data modifica, Dimensione con intestazioni cliccabili per ordinare. Le cartelle sempre in cima.
- **Icone file colorate** — 404 icone per tipo di file dal set Vivid di [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors). I PDF sono rossi, i ZIP viola, i file Swift arancioni — esattamente come ti aspetteresti su Windows.
- **Menu contestuale tasto destro** — Apri, Apri con, Copia, Taglia, Incolla, Rinomina, Comprimi in ZIP, Nuova cartella, Nuovo file, AirDrop, Elimina.
- **Scorciatoie da tastiera** — `Canc` sposta nel Cestino, `Shift+Canc` elimina definitivamente con conferma, `Cmd+C` / `Cmd+V` copia e incolla file.
- **Type-to-select** — premi una lettera per saltare al primo file che inizia con quella lettera. Premi di nuovo per scorrere tra i risultati.
- **Drag and drop** — tra due finestre di Win Finder e da/verso la barra laterale. Tenendo `Cmd` durante il trascinamento si copia invece di spostare.
- **Selezione multipla** — `Shift+click` per selezionare un intervallo, `Cmd+click` per aggiungere/rimuovere elementi.
- **AirDrop** dal tasto destro — condividi qualsiasi file direttamente senza aprire il Finder.
- **Monitoraggio filesystem in tempo reale** — la lista si aggiorna automaticamente quando i file cambiano su disco.
- **Sistema di estensioni** — aggiungi azioni personalizzate al menu contestuale tramite file JSON. Supporta sottomenu annidati, separatori, icone personalizzate e filtri per contesto. Gestisci tutto da **Win Finder → Gestisci estensioni**.
- **Multilingua** — disponibile in inglese 🇬🇧, italiano 🇮🇹, tedesco 🇩🇪, spagnolo 🇪🇸 e cinese semplificato 🇨🇳. La lingua dell'interfaccia segue automaticamente la lingua del sistema.

## Sistema di estensioni

Qualsiasi app può integrarsi con Win Finder creando una cartella in `~/.config/winfinder/actions/` con un file `action.json` e un `icon.png` opzionale:

```
~/.config/winfinder/actions/
  my-app/
    action.json
    icon.png        ← caricata automaticamente se il campo icon è omesso nel JSON
```

```json
{
  "name": "Git",
  "extensions": ["*"],
  "context": ["folder", "background"],
  "submenu": [
    { "name": "Pull", "command": "cd '{file}' && git pull" },
    { "name": "Push", "command": "cd '{file}' && git push" },
    { "separator": true },
    {
      "name": "Branch",
      "submenu": [
        { "name": "Pull da main", "command": "cd '{file}' && git pull origin main" },
        { "name": "Pull da develop", "command": "cd '{file}' && git pull origin develop" }
      ]
    }
  ]
}
```

**Campi:**
- `name` — etichetta mostrata nel menu
- `extensions` — estensioni file da abbinare, o `["*"]` per tutti i file
- `context` — dove appare l'azione: `"file"`, `"folder"`, `"background"` (default: `["file", "folder"]`)
- `command` — comando shell da eseguire, `{file}` viene sostituito con il percorso del file selezionato
- `submenu` — array di voci annidate (esclusivo con `command`)
- `icon` — percorso opzionale a un file PNG (se omesso, `icon.png` nella stessa cartella viene usata automaticamente)
- `separator` — imposta a `true` per un divisore nel menu

Win Finder legge questi file all'avvio e aggiunge le azioni al menu contestuale automaticamente — nessuna API, nessun SDK, nessun processo di approvazione. Usa **Win Finder → Gestisci estensioni** per abilitare, disabilitare o eliminare le estensioni senza toccare il filesystem.

## Installazione

### Requisiti
- macOS 13 Ventura o successivo
- Mac Apple Silicon o Intel

### Compila dal sorgente

```bash
git clone https://github.com/Skimmenthal13/winfinder.git
cd winfinder
open winfinder.xcodeproj
```

Poi premi `Cmd+R` in Xcode per compilare e avviare.

## Roadmap

- [ ] `Option+Tab` per navigare tra le finestre di Win Finder
- [ ] Ridimensionamento colonne
- [ ] Vista icone e anteprima miniature
- [ ] Personalizzazione scorciatoie da tastiera
- [ ] Libreria estensioni community — un repo separato con azioni JSON pronte per le app più popolari (VS Code, iTerm2, Git, FFmpeg...)
- [ ] **"Apri con Win Finder"** nel menu contestuale del Finder — Finder Sync Extension
- [ ] **WinFinderPicker** — permetti agli sviluppatori di terze parti di usare Win Finder come file picker alternativo nelle loro app. Due approcci in valutazione: Swift Package (SPM) o XPC Service.

## Contribuire

Win Finder è open source e accoglie contributi. Se sei passato da Windows e qualcosa non ti convince, apri una issue — è esattamente il tipo di feedback che migliora questo progetto.

1. Fai il fork del repo
2. Crea un branch (`git checkout -b feature/tua-feature`)
3. Fai il commit delle tue modifiche
4. Apri una pull request

## Crediti

Icone per tipo di file da [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors) di [@dmhendricks](https://github.com/dmhendricks) — una fantastica collezione di 400+ icone SVG per tipo di file, licenza CC BY-SA 4.0. Grazie per averla resa disponibile alla community.

## Licenza

MIT — fai quello che vuoi.

---

Creato da [@Skimmenthal13](https://github.com/Skimmenthal13) — un rifugiato da Windows che ne aveva abbastanza del Finder.

> 🤖 Questo intero progetto è stato costruito con **vibe coding** usando [Claude Code](https://claude.ai/code) — dalla prima riga di Swift al sistema di estensioni, la navigazione breadcrumb e le icone dei file. Nessuna vergogna, solo orgoglio.
