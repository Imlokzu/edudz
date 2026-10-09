# edudz on-device document viewer

All scripts run locally inside the app. The renderer never receives school
credentials and uses a Content Security Policy with `connect-src 'none'`.
Images/fonts must be embedded as data/blob URLs. External navigation is blocked.

Supported previews: DOCX, XLSX, XLS, ODS, CSV and PPTX. PDF and images use native
Flutter viewers. Original files remain downloadable. Rendering preserves common
styles, images, tables, merged cells and slides; advanced Office objects, exact
pagination, unavailable fonts and slide animations can differ.

Bundled and pinned:
- docx-preview 0.4.1 — Apache-2.0
- JSZip 3.10.1 — MIT (dual licensed MIT/GPLv3)
- @jvmr/pptx-to-html 1.1.2 — MIT
- DOMPurify 3.3.3 — Apache-2.0/MPL-2.0
- SheetJS CE 0.20.3 — Apache-2.0, official standalone distribution
  https://cdn.sheetjs.com/xlsx-0.20.3/package/dist/xlsx.full.min.js
  SHA-256: `cc015130aa8521e7f088f88898eba949ccdcbfb38df0bd129b44b7273c3a6f41`

Licenses accompany the bundle. Rebuild from the repository root:

```sh
cd tools/document-preview
npm ci --ignore-scripts
npm run build
```

Input is limited to 25 MiB; ZIP previews check entry counts and declared expanded
sizes. Spreadsheets display up to 2,000 rows and 100 columns per sheet with a
visible notice for larger files. Formulas are shown using their saved results,
not executed. Original files preserve all cells and data.
