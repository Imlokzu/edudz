import {build} from 'esbuild';
import {copyFile} from 'node:fs/promises';
await build({entryPoints:['src.js'],bundle:true,format:'iife',minify:true,platform:'browser',target:['chrome100'],outfile:'../../assets/document-preview/renderer.js',legalComments:'eof'});
for(const [name,path] of [['docx-preview','docx-preview/LICENSE'],['jszip','jszip/LICENSE.markdown'],['dompurify','dompurify/LICENSE'],['pptx-to-html','@jvmr/pptx-to-html/LICENSE']]){
 await copyFile(`node_modules/${path}`,`../../assets/document-preview/LICENSE-${name}.txt`);
}
