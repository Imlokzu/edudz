import JSZip from 'jszip';
import {renderAsync} from 'docx-preview';
import {pptxToHtml} from '@jvmr/pptx-to-html';
import DOMPurify from 'dompurify';
const root=document.getElementById('document');
let chunks=[], workbook=null, pages=[], zoom=1, ext='', language='uk', observer, requestedPage=null;
const labels={uk:{sheet:'Аркуш',empty:'Порожній аркуш',limit:'Показано перші 2 000 рядків і 100 стовпців. Усі дані є в оригіналі.',offline:'Локальний перегляд · без інтернету'},en:{sheet:'Sheet',empty:'Empty sheet',limit:'Showing the first 2,000 rows and 100 columns. The original contains all data.',offline:'Local preview · offline'},de:{sheet:'Blatt',empty:'Leeres Blatt',limit:'Die ersten 2.000 Zeilen und 100 Spalten werden angezeigt. Alle Daten sind im Original enthalten.',offline:'Lokale Vorschau · offline'}};
const emit=(type,value={})=>window.EdudzPreview?.postMessage(JSON.stringify({type,...value}));
const note=()=>labels[language]||labels.uk;
function safeHTML(html){return DOMPurify.sanitize(html,{USE_PROFILES:{html:true,svg:true,svgFilters:true},FORBID_TAGS:['script','iframe','object','embed','video','audio','form','input'],FORBID_ATTR:['onload','onclick','onerror']});}
function lockLinks(){
 root.querySelectorAll('a').forEach(a=>{a.removeAttribute('href');a.removeAttribute('target')});
 root.querySelectorAll('*').forEach(el=>{
  for(const name of ['src','href','xlink:href']) {const value=el.getAttribute(name);if(value && !/^(data:|blob:|#)/.test(value))el.removeAttribute(name)}
 });
}
async function validateZip(buffer){
 const zip=await JSZip.loadAsync(buffer);let total=0;const entries=Object.values(zip.files);
 if(entries.length>10000)throw Error('large');
 for(const entry of entries){
  const size=entry._data?.uncompressedSize||0;total+=size;
  if(size>40*1024*1024 || total>150*1024*1024 || /vbaproject|^basic\/|^scripts\//i.test(entry.name))throw Error('unsupported');
 }
 const required={docx:'word/document.xml',pptx:'ppt/presentation.xml',xlsx:'xl/workbook.xml',ods:'content.xml',odt:'content.xml',odp:'content.xml'}[ext];
 if(required && !zip.file(required))throw Error('invalid');return zip;
}
function fit(){
 const available=Math.max(240,document.documentElement.clientWidth-24);
 for(const wrapper of document.querySelectorAll('.page-shell')){
  const page=wrapper.firstElementChild;const width=Number(wrapper.dataset.width),height=Number(wrapper.dataset.height);
  const scale=available/width*zoom;wrapper.style.width=`${width*scale}px`;wrapper.style.height=`${height*scale}px`;
  page.style.transform=`scale(${scale})`;page.style.transformOrigin='top left';
 }
 if(workbook)root.style.zoom=zoom;
}
function wrapPages(elements){
 pages=elements;
 for(const page of elements){
  const rect=page.getBoundingClientRect();const width=Math.max(rect.width,page.scrollWidth),height=Math.max(rect.height,page.scrollHeight);
  const wrapper=document.createElement('div');wrapper.className='page-shell';wrapper.dataset.width=width;wrapper.dataset.height=height;
  page.parentNode.insertBefore(wrapper,page);wrapper.append(page);page.style.margin='0';
 }
 fit();window.scrollTo(0,0);
 observer?.disconnect();observer=new IntersectionObserver(updateCurrentPage,{threshold:[0,.1,.25,.5,.75,1]});
 pages.forEach(p=>observer.observe(p.parentElement));
 updateCurrentPage();
}
function updateCurrentPage(){
 if(!pages.length)return;
 if(requestedPage!==null){emit('page',{page:requestedPage,count:pages.length});return;}
 let best=0,area=-1;
 pages.forEach((p,index)=>{const rect=p.parentElement.getBoundingClientRect();const visible=Math.max(0,Math.min(innerHeight,rect.bottom)-Math.max(0,rect.top));if(visible>area){area=visible;best=index}});
 emit('page',{page:best+1,count:pages.length});
}
window.addEventListener('scroll',updateCurrentPage,{passive:true});
for(const name of ['touchstart','wheel','pointerdown'])window.addEventListener(name,()=>{requestedPage=null},{passive:true});
function color(value){if(!value)return '';const rgb=value.rgb;return /^[0-9a-f]{6,8}$/i.test(rgb||'') ? '#'+rgb.slice(-6) : '';}
async function enrichSpreadsheetStyles(zip){
 if(!zip || !workbook.Styles)return;
 const xml=async path=>new DOMParser().parseFromString(await zip.file(path).async('string'),'application/xml');
 const book=await xml('xl/workbook.xml'),rels=await xml('xl/_rels/workbook.xml.rels');
 const targets=new Map([...rels.getElementsByTagName('Relationship')].map(r=>[r.getAttribute('Id'),r.getAttribute('Target')]));
 for(const entry of book.getElementsByTagName('sheet')){
  const target=targets.get(entry.getAttribute('r:id'));if(!target)continue;
  const path=target.startsWith('/')?target.slice(1):'xl/'+target.replace(/^\.\//,'');if(!zip.file(path))continue;
  const sheet=workbook.Sheets[entry.getAttribute('name')];if(!sheet)continue;
  const data=await xml(path);
  for(const node of data.getElementsByTagName('c')){
   const cell=sheet[node.getAttribute('r')],xf=workbook.Styles.CellXf?.[Number(node.getAttribute('s')||0)];
   if(cell && xf)cell.edudzStyle={font:workbook.Styles.Fonts?.[xf.fontId],alignment:xf.alignment};
  }
 }
}
function showSheet(index){
 const XLSX=window.XLSX;const name=workbook.SheetNames[index],sheet=workbook.Sheets[name];root.replaceChildren();
 const tabs=document.getElementById('sheets');tabs.replaceChildren();
 workbook.SheetNames.forEach((title,i)=>{const button=document.createElement('button');button.textContent=title;button.className=i===index?'selected':'';button.onclick=()=>showSheet(i);tabs.append(button)});
 const range=XLSX.utils.decode_range(sheet['!ref']||'A1');
 const lastRow=Math.min(range.e.r,range.s.r+1999),lastCol=Math.min(range.e.c,range.s.c+99);
 if(lastRow<range.e.r||lastCol<range.e.c){const warning=document.createElement('p');warning.textContent=note().limit;warning.className='limit';root.append(warning)}
 const table=document.createElement('table');table.className='spreadsheet';const header=document.createElement('tr');header.append(document.createElement('th'));
 for(let c=range.s.c;c<=lastCol;c++){const th=document.createElement('th');th.textContent=XLSX.utils.encode_col(c);header.append(th)}
 const thead=document.createElement('thead');thead.append(header);table.append(thead);const body=document.createElement('tbody');
 const merges=(sheet['!merges']||[]).filter(m=>m.s.r<=lastRow&&m.s.c<=lastCol);const skip=new Set(),starts=new Map();
 for(const m of merges){starts.set(`${m.s.r}:${m.s.c}`,m);for(let r=m.s.r;r<=Math.min(m.e.r,lastRow);r++)for(let c=m.s.c;c<=Math.min(m.e.c,lastCol);c++)if(r!==m.s.r||c!==m.s.c)skip.add(`${r}:${c}`)}
 for(let r=range.s.r;r<=lastRow;r++){
  const tr=document.createElement('tr'),rowLabel=document.createElement('th');rowLabel.textContent=r+1;tr.append(rowLabel);
  const height=sheet['!rows']?.[r]?.hpx;if(height)tr.style.height=`${Math.min(300,height)}px`;
  for(let c=range.s.c;c<=lastCol;c++){
   const key=`${r}:${c}`;if(skip.has(key))continue;
   const td=document.createElement('td'),cell=sheet[XLSX.utils.encode_cell({r,c})];
   const merge=starts.get(key);if(merge){td.colSpan=Math.min(merge.e.c,lastCol)-c+1;td.rowSpan=Math.min(merge.e.r,lastRow)-r+1;}
   td.textContent=cell ? (cell.w ?? XLSX.utils.format_cell(cell) ?? '') : '';
   if(cell?.t==='n')td.style.textAlign='right';
   const extra=cell?.edudzStyle;const font=extra?.font;if(font){if(font.bold)td.style.fontWeight='bold';if(font.italic)td.style.fontStyle='italic';if(font.sz)td.style.fontSize=`${font.sz*4/3}px`;const ink=color(font.color);if(ink)td.style.color=ink;}if(extra?.alignment?.horizontal)td.style.textAlign=extra.alignment.horizontal;
   const style=cell?.s;if(style){const fill=color(style.fgColor||style.fill?.fgColor);if(fill)td.style.backgroundColor=fill;if(style.font?.bold)td.style.fontWeight='bold';const fg=color(style.font?.color);if(fg)td.style.color=fg;}
   const width=sheet['!cols']?.[c]?.wpx;if(width)td.style.minWidth=`${Math.min(600,Math.max(40,width))}px`;
   tr.append(td);
  }body.append(tr);
 }
 table.append(body);root.append(table);fit();emit('sheet',{page:index+1,count:workbook.SheetNames.length});
}
window.Edudz={
 begin(extension,lang){chunks=[];ext=extension;language=lang;workbook=null;pages=[];requestedPage=null;zoom=1;root.replaceChildren();document.getElementById('sheets').replaceChildren();},
 append(chunk){chunks.push(chunk)},
 async render(){
  try{
   const binary=atob(chunks.join(''));chunks=[];if(binary.length>25*1024*1024)throw Error('large');
   const bytes=Uint8Array.from(binary,c=>c.charCodeAt(0));let zip;
   if(['docx','pptx','xlsx','ods'].includes(ext))zip=await validateZip(bytes.buffer);
   if(ext==='docx'){
    await renderAsync(bytes.buffer,root,null,{inWrapper:true,ignoreWidth:false,ignoreHeight:false,breakPages:true,ignoreLastRenderedPageBreak:false,renderHeaders:true,renderFooters:true,renderFootnotes:true,renderEndnotes:true,renderAltChunks:false,useBase64URL:true});
    // Word's common Symbol/Wingdings bullets use private-use code points.
    // Android does not ship those fonts; keep their intended Unicode shapes.
    root.querySelectorAll('style').forEach(style=>{style.textContent=style.textContent.replace(/\uf0b7/g,'•').replace(/\uf0a7/g,'▪').replace(/\uf0d8/g,'▸')});
    lockLinks();await document.fonts.ready;
    await Promise.all([...root.querySelectorAll('img')].map(image=>image.decode().catch(()=>{})));
    wrapPages([...root.querySelectorAll('section.docx')]);
   }else if(ext==='pptx'){
    const xml=new DOMParser().parseFromString(await zip.file('ppt/presentation.xml').async('string'),'application/xml');
    const size=xml.getElementsByTagName('p:sldSz')[0];const width=960,height=size?960*Number(size.getAttribute('cy'))/Number(size.getAttribute('cx')):540;
    const slides=await pptxToHtml(bytes.buffer,{width,height,scaleToFit:true,letterbox:true});
    for(const html of slides){const container=document.createElement('section');container.className='slide';container.style.width=`${width}px`;container.style.height=`${height}px`;container.innerHTML=safeHTML(html);root.append(container)}
    lockLinks();wrapPages([...root.querySelectorAll('section.slide')]);
   }else if(['xlsx','xls','ods','csv'].includes(ext)){
    workbook=window.XLSX.read(bytes,{type:'array',cellStyles:true,cellDates:true,cellText:true});
    if(!workbook.SheetNames.length)throw Error('empty');if(ext==='xlsx')await enrichSpreadsheetStyles(zip);showSheet(0);
   }else{throw Error('unsupported')}
   emit('ready',{count:workbook?workbook.SheetNames.length:pages.length,kind:workbook?'sheet':ext==='pptx'?'slide':'page'});
  }catch(error){emit('error',{reason:['large','unsupported'].includes(error.message)?error.message:'invalid'});}
 },
 setZoom(value){zoom=Math.min(3,Math.max(.75,Number(value)||1));fit()},
 go(page){if(workbook)showSheet(Math.max(0,Math.min(workbook.SheetNames.length-1,page-1)));else {requestedPage=Math.max(1,Math.min(pages.length,page));pages[requestedPage-1]?.parentElement.scrollIntoView({behavior:'smooth',block:'start'});emit('page',{page:requestedPage,count:pages.length})}}
};
window.addEventListener('resize',fit);
window.addEventListener('error',()=>emit('error',{reason:'invalid'}));
emit('boot');
