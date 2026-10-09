# Local renderer boundaries

The app downloads attachments using its authenticated school session. It passes
only file bytes and a language/extension to the packaged renderer. Account data
and tokens never enter JavaScript. The renderer has no network access: CSP denies
connections, remote images, external fonts, media, frames, forms and object embeds.
The Flutter navigation delegate only permits the bundled initial HTML page.

DOCX HTML altChunks are disabled. PPTX output is sanitized with DOMPurify. Office
hyperlinks cannot navigate away from the document. Macros and formulas are never
executed. Files larger than 25 MiB are not loaded; ZIP metadata is checked before
rendering. The original attachment remains available through the native download
button if preview fails.

For every renderer update, exercise formatted DOCX with a page break/image/table,
XLSX with merged/styled cells and multiple sheets, and PPTX with images and multiple
slides. Verify next/previous controls, fit/zoom, and CSP before bundling a release.
