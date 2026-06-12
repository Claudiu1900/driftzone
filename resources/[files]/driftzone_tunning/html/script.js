"use strict";
const root = document.getElementById('root');
const vehicleInfo = document.getElementById('vehicleInfo');
const moneyEl = document.getElementById('money');
const modeText = document.getElementById('modeText');
const groupsEl = document.getElementById('groups');
const categoriesEl = document.getElementById('categories');
const optionsEl = document.getElementById('options');
const selectedTitle = document.getElementById('selectedTitle');
const cartCount = document.getElementById('cartCount');
const cartItems = document.getElementById('cartItems');
const totalPrice = document.getElementById('totalPrice');
const searchEl = document.getElementById('search');

let data = {};
let activeGroup = 'ALL';
let activeCategory = null;
let cart = [];
let previewTimer = null;
let queuedPreview = null;

const classicColors = [
 ['Black',0,'#050505'],['Graphite',1,'#1c1c1c'],['White',111,'#f2f2f2'],['Red',27,'#c90000'],['Blue',64,'#0055ff'],['Yellow',88,'#ffd500'],['Green',55,'#00a651'],['Orange',38,'#ff7b00'],['Purple',71,'#7d00ff'],['Pink',135,'#ff4ccf'],['Cyan',140,'#00d9ff'],['Chrome',120,'#c7c7c7'],['Gold',99,'#d4af37']
];
const windowTints = [['None',0],['Pure Black',1],['Dark Smoke',2],['Light Smoke',3],['Stock',4],['Limo',5],['Green',6]];
const xenonColors = [['White',0,'#fff'],['Blue',1,'#006eff'],['Electric Blue',2,'#00aaff'],['Mint Green',3,'#00ff9d'],['Lime',4,'#bfff00'],['Yellow',5,'#ffe600'],['Golden',6,'#ffbf00'],['Orange',7,'#ff7300'],['Red',8,'#ff0000'],['Pony Pink',9,'#ff66cc'],['Hot Pink',10,'#ff1493'],['Purple',11,'#8a2be2']];
const plateStyles = [['Blue/White 1',0],['Yellow/Black',1],['Yellow/Blue',2],['Blue/White 2',3],['Blue/White 3',4],['North Yankton',5]];
const quickColors = [['White','#ffffff'],['Black','#050505'],['Red','#ff0000'],['Blue','#006eff'],['Cyan','#04c7f7'],['Green','#00ff6a'],['Yellow','#ffe600'],['Orange','#ff7300'],['Purple','#8a2be2'],['Pink','#ff1493']];

function nui(name, payload = {}) { fetch(`https://${GetParentResourceName()}/${name}`, { method:'POST', headers:{'Content-Type':'application/json; charset=UTF-8'}, body:JSON.stringify(payload) }).catch(()=>{}); }
function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]));}
function money(v){const n=Number(v||0);try{return '$'+n.toLocaleString('ro-RO')}catch(e){return '$'+n}}
function categories(){return Array.isArray(data.categories)?data.categories:[];}
function getCategory(key){return categories().find(c=>c.key===key)||null;}
function getPrice(key){const base=Number(data.vehiclePrice||0);const pct=Number((data.pricePercent||{})[key]||1);return Math.max(1,Math.ceil(base*pct/100));}
function listById(list, val){const f=list.find(x=>Number(x[1])===Number(val));return f?f[0]:String(val);}
function allGroups(){const set=new Set(['ALL']); categories().forEach(c=>set.add(c.group||'Other')); return Array.from(set);}

function open(payload){
 data=payload||{}; cart=[]; activeCategory=null; activeGroup='ALL';
 root.classList.remove('hidden');
 vehicleInfo.textContent=`${data.vehicleName||'Vehicle'} • ${data.vehiclePlate||''}`;
 moneyEl.textContent=money(data.playerMoney||data.cash||0);
 modeText.textContent=data.adminMode?'ADMIN':'OWNER';
 if(searchEl) searchEl.value='';
 renderGroups(); renderCategories(); renderCart();
 selectedTitle.textContent='Selecteaza o categorie';
 optionsEl.className='options empty-state';
 optionsEl.innerHTML='<b>Alege o categorie</b><span>Vor apărea doar modificările reale disponibile pe mașina curentă.</span>';
}
function close(){root.classList.add('hidden'); data={}; cart=[]; activeCategory=null; categoriesEl.innerHTML=''; optionsEl.innerHTML='';}
function setCart(items){ if(!Array.isArray(items)) return; cart=items.map(i=>({...i,variantLabel:i.variantLabel||valueToText(i.key,i.value)})); renderCart(); }
function setCameraMode(enabled){root.classList.toggle('camera-mode', enabled===true);}

function renderGroups(){groupsEl.innerHTML=allGroups().map(g=>`<button class="group ${g===activeGroup?'active':''}" onclick="selectGroup('${esc(g)}')">${esc(g)}</button>`).join('');}
function selectGroup(g){activeGroup=g;activeCategory=null;renderGroups();renderCategories();selectedTitle.textContent='Selecteaza o categorie';optionsEl.className='options empty-state';optionsEl.innerHTML='<b>Alege o categorie</b><span>Selectează din stânga.</span>';}
function renderCategories(){
 const q=String(searchEl?.value||'').toLowerCase().trim();
 let list=categories().filter(c=>(activeGroup==='ALL'||(c.group||'Other')===activeGroup));
 if(q) list=list.filter(c=>`${c.label} ${c.group} ${c.key}`.toLowerCase().includes(q));
 categoriesEl.innerHTML=list.map(c=>`<div class="cat ${activeCategory&&activeCategory.key===c.key?'active':''}" onclick="selectCategory('${esc(c.key)}')"><div><b>${esc(c.label)}</b><span>${esc(c.group||c.type)} • ${c.count||0} opt</span></div><em>${money(getPrice(c.key))}</em></div>`).join('') || '<div class="empty-mini">Nicio categorie.</div>';
}
function selectCategory(key){activeCategory=getCategory(key);renderCategories();renderOptions();}
function renderOptions(){
 if(!activeCategory) return;
 selectedTitle.textContent=`${activeCategory.label} • ${money(getPrice(activeCategory.key))}`;
 if(activeCategory.type==='color') return renderColorOptions();
 if(activeCategory.type==='classicColor'||activeCategory.type==='vehicleColor') return renderColorList(classicColors);
 if(activeCategory.type==='windowTint') return renderSimpleList(windowTints);
 if(activeCategory.type==='xenonColor') return renderColorList(xenonColors);
 if(activeCategory.type==='plateIndex') return renderSimpleList(plateStyles);
 if(activeCategory.type==='toggle'||activeCategory.type==='extra') return renderToggleOptions();
 renderModOptions();
}
function opt(html){optionsEl.className='options';optionsEl.innerHTML=html;}
function renderColorOptions(){
 let html=`<div class="custom-card"><input id="customPicker" type="color" value="#04c7f7"><input id="customHex" value="#04c7f7"><button onclick="applyCustomColor()">APPLY</button></div>`;
 html+=quickColors.map(([n,h])=>`<button class="swatch" title="${esc(n)}" onclick="preview('${activeCategory.key}','${h}')"><i style="background:${h}"></i><span>${esc(n)}</span></button>`).join('');
 opt(html);
 setTimeout(()=>{const p=document.getElementById('customPicker'), h=document.getElementById('customHex'); if(!p||!h)return; p.oninput=()=>{h.value=p.value;preview(activeCategory.key,p.value)}; h.onchange=()=>{if(/^#[0-9A-Fa-f]{6}$/.test(h.value)){p.value=h.value;preview(activeCategory.key,h.value)}}},30);
}
function applyCustomColor(){const h=document.getElementById('customHex');preview(activeCategory.key,h?h.value:'#04c7f7');}
function renderColorList(list){opt(list.map(([n,id,hex])=>`<button class="swatch wide" onclick="preview('${activeCategory.key}',${id})"><i style="background:${hex||'#222'}"></i><span>${esc(n)}</span></button>`).join(''));}
function renderSimpleList(list){opt(list.map(([n,id])=>`<button class="option" onclick="preview('${activeCategory.key}',${id})"><b>${esc(n)}</b><span>${money(getPrice(activeCategory.key))}</span></button>`).join(''));}
function renderToggleOptions(){opt(`<button class="option" onclick="preview('${activeCategory.key}',true)"><b>ENABLED</b><span>${money(getPrice(activeCategory.key))}</span></button><button class="option" onclick="preview('${activeCategory.key}',false)"><b>DISABLED</b><span>${money(getPrice(activeCategory.key))}</span></button>`);}
function renderModOptions(){
 const opts=Array.isArray(activeCategory.options)?activeCategory.options:[];
 let list=opts.length?opts:[{value:-1,label:'Stock'}, ...Array.from({length:Number(activeCategory.count||0)},(_,i)=>({value:i,label:`${activeCategory.label} ${i+1}`}))];
 opt(list.map(o=>`<button class="option" onclick="preview('${activeCategory.key}',${Number(o.value)})"><b>${esc(o.label)}</b><span>${money(getPrice(activeCategory.key))}</span></button>`).join(''));
}
function valueToText(key,value){const c=getCategory(key)||activeCategory;if(!c)return String(value);if(c.type==='color'){if(typeof value==='string')return value.toUpperCase();if(value&&typeof value==='object')return `RGB(${value.r||0}, ${value.g||0}, ${value.b||0})`;return 'Custom Color';}if(c.type==='classicColor'||c.type==='vehicleColor')return listById(classicColors,value);if(c.type==='windowTint')return listById(windowTints,value);if(c.type==='xenonColor')return listById(xenonColors,value);if(c.type==='plateIndex')return listById(plateStyles,value);if(c.type==='toggle'||c.type==='extra')return value===true?'Enabled':'Disabled';if((c.type==='mod'||c.type==='wheel')&&Array.isArray(c.options)){const f=c.options.find(o=>Number(o.value)===Number(value));return f?f.label:(Number(value)===-1?'Stock':`${c.label} ${Number(value)+1}`)}return String(value);}
function preview(key,value){if(!activeCategory)return;if(activeCategory.type==='wheel'){cart=cart.filter(i=>!String(i.key||'').startsWith('wheels_')||i.key===key);}const variantLabel=valueToText(key,value);const found=cart.find(i=>i.key===key);if(found){found.value=value;found.price=getPrice(key);found.variantLabel=variantLabel;}else{cart.push({key,label:activeCategory.label,value,variantLabel,price:getPrice(key)});}renderCart();queuedPreview={key,value,variantLabel};if(previewTimer)return;previewTimer=setTimeout(()=>{const p=queuedPreview;queuedPreview=null;previewTimer=null;if(p)nui('preview',p);},25);}
function removeCartItem(key){cart=cart.filter(i=>i.key!==key);renderCart();nui('remove',{key});}
function renderCart(){cartCount.textContent=`${cart.length} items`;const total=cart.reduce((s,i)=>s+Number(i.price||0),0);totalPrice.textContent=money(total);if(!cart.length){cartItems.innerHTML='<div class="cart-empty"><b>Nicio modificare</b><span>Alege tuning-uri reale din meniu.</span></div>';return;}cartItems.innerHTML=cart.map(i=>`<div class="cart-item"><div><b>${esc(i.label)}</b><small>${esc(i.variantLabel)}</small></div><span>${money(i.price)}</span><button onclick="removeCartItem('${esc(i.key)}')">×</button></div>`).join('');}
function pay(){nui('buy');}
function closeMenu(){nui('close');}
document.addEventListener('keydown',e=>{if(e.key==='Escape')nui('close');if(e.key==='`'||e.code==='Backquote')nui('toggleCamera');});
window.addEventListener('message',e=>{const m=e.data||{};if(m.action==='open')open(m.data||{});if(m.action==='close')close();if(m.action==='cart')setCart(m.items||[]);if(m.action==='camera')setCameraMode(m.enabled===true);});
setTimeout(()=>nui('ready'),50);
