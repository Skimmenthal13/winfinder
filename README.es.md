# Win Finder

Un gestor de archivos para macOS que se siente como en casa — para quienes vienen de Windows.

🇬🇧 [English](README.md) &nbsp; 🇮🇹 [Italiano](README.it.md) &nbsp; 🇩🇪 [Deutsch](README.de.md) &nbsp; 🇪🇸 Español &nbsp; 🇨🇳 [中文](README.zh.md) &nbsp; [🇲🇬 Malagasy ❤️](README.mg.md)

![Win Finder screenshot](docs/screenshot.png)

## ¿Por qué Win Finder?

macOS es un gran sistema operativo. Pero si pasaste años en Windows, el Finder te parecerá incorrecto de formas difíciles de explicar: sin barra de ruta editable, sin búsqueda inline, sin "Nuevo archivo" con clic derecho, Supr no elimina. Pequeñas cosas que acumulan fricción constante.

Win Finder lo soluciona. Es un gestor de archivos nativo para macOS construido alrededor de los flujos de trabajo que los usuarios de Windows ya conocen.

## Características

- **Barra de ruta editable** — siempre visible, ocupa el 80% del ancho. Haz clic, escribe una ruta, pulsa Enter. Funciona exactamente como el Explorador de Windows.
- **Navegación breadcrumb** — la barra de ruta muestra cada carpeta como un token clicable. Haz clic en un segmento para navegar ahí. Haz clic en `>` para ver subcarpetas de ese nivel. Haz clic en el espacio vacío a la derecha para cambiar al modo de texto editable.
- **Búsqueda inline** — campo de búsqueda siempre visible junto a la barra de ruta. Busca recursivamente en todas las subcarpetas por defecto. Soporta comodines (`*.pdf`, `doc*`). Los resultados muestran la ruta relativa.
- **Barra lateral** — Favoritos (Escritorio, Documentos, Descargas, Imágenes), Ubicaciones, Dispositivos y rutas Recientes — guardadas entre sesiones.
- **Lista estilo Explorador de Windows** — columnas Nombre, Fecha de modificación, Tamaño con encabezados clicables para ordenar. Las carpetas siempre arriba.
- **Iconos de archivo coloridos** — 404 iconos de tipo de archivo del conjunto Vivid de [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors). Los PDFs son rojos, los ZIPs morados, los archivos Swift naranja.
- **Menú contextual (clic derecho)** — Abrir, Abrir con, Copiar, Cortar, Pegar, Renombrar, Comprimir en ZIP, Nueva carpeta, Nuevo archivo, AirDrop, Eliminar.
- **Atajos de teclado** — `Supr` mueve a la Papelera, `Shift+Supr` elimina permanentemente con confirmación, `Cmd+C` / `Cmd+V` copia y pega archivos.
- **Type-to-select** — pulsa una letra para saltar al primer archivo que empiece por esa letra. Pulsa de nuevo para recorrer coincidencias.
- **Arrastrar y soltar** — entre dos ventanas de Win Finder y hacia/desde la barra lateral. Mantener `Cmd` al arrastrar copia en lugar de mover.
- **Selección múltiple** — `Shift+clic` para seleccionar un rango, `Cmd+clic` para alternar elementos individuales.
- **AirDrop** desde el clic derecho — comparte cualquier archivo directamente sin abrir el Finder.
- **Monitoreo del sistema de archivos en tiempo real** — la lista se actualiza automáticamente cuando los archivos cambian en disco.
- **Sistema de extensiones** — añade acciones personalizadas al menú contextual mediante archivos JSON. Soporta submenús anidados, separadores, iconos personalizados y filtrado por contexto. Gestiona todo desde **Win Finder → Gestionar extensiones**.
- **Multiidioma** — disponible en inglés 🇬🇧, italiano 🇮🇹, alemán 🇩🇪, español 🇪🇸, chino simplificado 🇨🇳 y malgache 🇲🇬 ❤️. El idioma de la interfaz sigue automáticamente el idioma del sistema.

## Sistema de extensiones

Cualquier app puede integrarse con Win Finder creando una carpeta en `~/.config/winfinder/actions/` con un archivo `action.json` y un `icon.png` opcional.

**Campos:**
- `name` — etiqueta mostrada en el menú
- `extensions` — extensiones de archivo a coincidir, o `["*"]` para todos los archivos
- `context` — dónde aparece la acción: `"file"`, `"folder"`, `"background"`
- `command` — comando shell a ejecutar, `{file}` se reemplaza con la ruta del archivo
- `submenu` — array de elementos anidados
- `icon` — ruta opcional a un archivo PNG
- `separator` — establece en `true` para un divisor de menú

## Instalación

### Requisitos
- macOS 13 Ventura o posterior
- Mac Apple Silicon o Intel

### Compilar desde el código fuente

```bash
git clone https://github.com/Skimmenthal13/winfinder.git
cd winfinder
open winfinder.xcodeproj
```

Luego pulsa `Cmd+R` en Xcode para compilar y ejecutar.

## Contribuir

Win Finder es open source y acepta contribuciones. Si cambiaste de Windows y algo no se siente bien, abre un issue.

1. Haz fork del repositorio
2. Crea una rama (`git checkout -b feature/tu-feature`)
3. Haz commit de tus cambios
4. Abre un pull request

## Créditos

Iconos de tipo de archivo de [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors) por [@dmhendricks](https://github.com/dmhendricks) — una fantástica colección de 400+ iconos SVG, licencia CC BY-SA 4.0. Gracias por ponerla a disposición de la comunidad.

## Licencia

MIT — haz lo que quieras con esto.

---

Creado por [@Skimmenthal13](https://github.com/Skimmenthal13) — un refugiado de Windows que se cansó de luchar con el Finder.

> 🤖 Todo este proyecto fue construido con **vibe coding** usando [Claude Code](https://claude.ai/code) — desde la primera línea de Swift hasta el sistema de extensiones, la navegación breadcrumb y los iconos de archivo. Sin vergüenza, solo orgullo.

## Legal
- [Política de Privacidad](https://skimmenthal13.github.io/winfinder/privacy-policy.html)
- [Términos de Servicio](https://skimmenthal13.github.io/winfinder/terms-of-service.html)