'use strict';
const panels = ['coordsPanel','addVehPanel','configVehPanel','ownedVehPanel'].map(id => document.getElementById(id));
const $ = (id) => document.getElementById(id);
let currentCoords = '';
let configVehicles = [];
let ownedVehicles = [];
let ownedUid = 0;
let modalCallback = null;

const SUBS = {
    DRIFT: ['starter', 'drifter', 'jdm_legends'],
    HS: ['starter', 'racer', 'legend'],
    PREMIUM: ['drift', 'hs'],
    CUSTOM: ['all']
};
function nui(name, data = {}) { fetch(`https://${GetParentResourceName()}/${name}`, { method:'POST', headers:{'Content-Type':'application/json; charset=UTF-8'}, body:JSON.stringify(data)}).catch(()=>{}); }
function esc(v){return String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]));}
function closePanels(){panels.forEach(p=>p.classList.add('hidden'));}
function closeAll(){hideModal();closePanels();nui('closePanel');}
function showPanel(id){closePanels();$(id).classList.remove('hidden');}
function num(v){return Number(v||0).toLocaleString('ro-RO');}
function money(row){return Number(row.dzcoins_price||0)>0 ? `${num(row.dzcoins_price)} DZC` : `$${num(row.price||0)}`;}
function bool(v){return Number(v||0)===1 || v===true;}

function showModal(title, message, options = {}) {
    const modal = $('confirmModal');
    if (!modal) return;
    $('confirmTitle').textContent = title || 'Confirmare';
    $('confirmMessage').textContent = message || 'Esti sigur?';
    const input = $('confirmInput');
    input.value = '';
    input.placeholder = options.placeholder || '';
    input.classList.toggle('hidden', options.input !== true);
    $('confirmOk').textContent = options.okText || 'CONFIRMA';
    $('confirmCancel').textContent = options.cancelText || 'RENUNTA';
    modalCallback = typeof options.onConfirm === 'function' ? options.onConfirm : null;
    modal.classList.remove('hidden');
    setTimeout(() => { if (options.input === true) input.focus(); else $('confirmOk').focus(); }, 60);
}
function hideModal(){ const modal=$('confirmModal'); if(modal) modal.classList.add('hidden'); modalCallback=null; }
function confirmModalOk(){
    const input = $('confirmInput');
    const value = input ? input.value.trim() : '';
    const fn = modalCallback;
    hideModal();
    if (fn) fn(value);
}
function confirmModalCancel(){ hideModal(); }

async function copyText(text){ try{await navigator.clipboard.writeText(text); $('status').textContent='Coordonatele au fost copiate.';}catch(e){$('coordsInput').select();document.execCommand('copy');} }
function showCoords(data={}){currentCoords=String(data.coords||'');$('coordsInput').value=currentCoords;$('xInput').value=Number(data.x||0).toFixed(6);$('yInput').value=Number(data.y||0).toFixed(6);$('zInput').value=Number(data.z||0).toFixed(6);$('headingInput').value=Number(data.heading||0).toFixed(2);$('dimensionInput').value=Number(data.dimension||0);showPanel('coordsPanel');setTimeout(()=>copyText(currentCoords),100);}
function copyCoords(){copyText(currentCoords);}

function syncSubcategories(value){ const sec = value || $('carSectionInput').value || 'DRIFT'; const sel=$('carSubcategoryInput'); sel.innerHTML=(SUBS[sec]||['all']).map(s=>`<option value="${s}">${s}</option>`).join(''); }
function showAddVeh(){showPanel('addVehPanel');$('addCarStatus').textContent='Completeaza campurile.';$('addCarStatus').className='status';$('carModelInput').value='';$('carNameInput').value='';$('carPriceInput').value='0';$('carDzcoinsInput').value='0';$('carCategoryInput').value='1';$('carSectionInput').value='DRIFT';syncSubcategories('DRIFT');$('carVipInput').value='0';$('carApearInput').value='1';$('carSellingInput').value='1';$('carTradebleInput').value='1';$('carTunableInput').value='1';$('carTypeInput').value='drift';$('carImageInput').value='';$('imagePreviewBox').classList.add('hidden');setTimeout(()=>$('carModelInput').focus(),60);}
function previewCarImage(){const url=String($('carImageInput').value||'').trim(); if(!url){$('imagePreviewBox').classList.add('hidden');return;} $('carImagePreview').src=url;$('imagePreviewBox').classList.remove('hidden');}
function vehPayload(prefix='car'){return {model:$(`${prefix}ModelInput`).value.trim(),name:$(`${prefix}NameInput`).value.trim(),price:Number($(`${prefix}PriceInput`).value||0),dzcoins_price:Number($(`${prefix}DzcoinsInput`).value||0),category:Number($(`${prefix}CategoryInput`).value||1),showroom_section:$(`${prefix}SectionInput`).value,showroom_subcategory:$(`${prefix}SubcategoryInput`).value,vip:Number($(`${prefix}VipInput`).value||0),apear:Number($(`${prefix}ApearInput`).value||1),selling:Number($(`${prefix}SellingInput`).value||1),tradeble:Number($(`${prefix}TradebleInput`).value||1),tunable:Number($(`${prefix}TunableInput`).value||1),type:$(`${prefix}TypeInput`).value,image:$(`${prefix}ImageInput`).value.trim()};}
function submitAddCar(){const p=vehPayload('car'); if(!p.model||!p.name){$('addCarStatus').textContent='Model si nume obligatorii.';$('addCarStatus').className='status error';return;} $('addCarStatus').textContent='Se salveaza...';nui('submitAddCar',p);}
function addVehResult(data){$('addCarStatus').textContent=data.message||'Result';$('addCarStatus').className='status '+(data.ok?'success':'error');}

function showConfigVeh(data={}){configVehicles=Array.isArray(data.vehicles)?data.vehicles:[];showPanel('configVehPanel');renderConfigVeh();}
function getConfigFilter(){return String($('configSearch').value||'').toLowerCase().trim();}
function renderConfigVeh(){const q=getConfigFilter();const list=configVehicles.filter(v=>!q||`${v.id} ${v.model} ${v.name} ${v.plate||''} ${v.showroom_section} ${v.showroom_subcategory}`.toLowerCase().includes(q));$('configList').innerHTML=list.map(v=>configCard(v)).join('')||'<div class="empty">Nu exista masini.</div>';}
function configCard(v){const id=Number(v.id||0);return `<div class="veh-config-card" data-id="${id}">
 <div class="card-head"><b>#${id} ${esc(v.name)}</b><span>${esc(v.model)} • ${money(v)}</span></div>
 <div class="grid four compact">
  <div><label>MODEL</label><input id="cfg${id}ModelInput" value="${esc(v.model)}"></div><div><label>NAME</label><input id="cfg${id}NameInput" value="${esc(v.name)}"></div><div><label>CASH</label><input id="cfg${id}PriceInput" type="number" value="${Number(v.price||0)}"></div><div><label>DZC</label><input id="cfg${id}DzcoinsInput" type="number" value="${Number(v.dzcoins_price||0)}"></div>
 </div>
 <div class="grid five compact">
  <div><label>SECTION</label><select id="cfg${id}SectionInput" onchange="syncConfigSub(${id})">${['DRIFT','HS','PREMIUM','CUSTOM'].map(s=>`<option ${String(v.showroom_section||'').toUpperCase()===s?'selected':''}>${s}</option>`).join('')}</select></div>
  <div><label>SUB</label><select id="cfg${id}SubcategoryInput"></select></div><div><label>CAT NR</label><input id="cfg${id}CategoryInput" type="number" value="${Number(v.category||1)}"></div><div><label>TYPE</label><select id="cfg${id}TypeInput">${['drift','hs','premium','custom'].map(s=>`<option value="${s}" ${String(v.type||'')===s?'selected':''}>${s}</option>`).join('')}</select></div><div><label>IMAGE</label><input id="cfg${id}ImageInput" value="${esc(v.image)}"></div>
 </div>
 <div class="grid five compact">
  ${select01(`cfg${id}VipInput`,'VIP',v.vip)}${select01(`cfg${id}ApearInput`,'APEAR',v.apear)}${select01(`cfg${id}SellingInput`,'SELLING',v.selling)}${select01(`cfg${id}TradebleInput`,'TRADE',v.tradeble)}${select01(`cfg${id}TunableInput`,'TUNABLE',v.tunable)}
 </div>
 <div class="buttons right"><button onclick="saveConfigVeh(${id})">EDIT / SAVE</button><button class="danger" onclick="deleteConfigVeh(${id})">DELETE</button></div>
 </div>`;}
function select01(id,label,val){return `<div><label>${label}</label><select id="${id}"><option value="1" ${bool(val)?'selected':''}>1</option><option value="0" ${!bool(val)?'selected':''}>0</option></select></div>`;}
function syncConfigSub(id){const sec=$(`cfg${id}SectionInput`).value;const sel=$(`cfg${id}SubcategoryInput`);const old=(configVehicles.find(v=>Number(v.id)===id)||{}).showroom_subcategory;sel.innerHTML=(SUBS[sec]||['all']).map(s=>`<option value="${s}" ${old===s?'selected':''}>${s}</option>`).join('');}
function hydrateConfigSubs(){configVehicles.forEach(v=>{const id=Number(v.id||0); if($(`cfg${id}SubcategoryInput`)) syncConfigSub(id);});}
const oldRenderConfigVeh = renderConfigVeh; renderConfigVeh=function(){oldRenderConfigVeh();setTimeout(hydrateConfigSubs,0);};
function cfgPayload(id){return {model:$(`cfg${id}ModelInput`).value.trim(),name:$(`cfg${id}NameInput`).value.trim(),price:Number($(`cfg${id}PriceInput`).value||0),dzcoins_price:Number($(`cfg${id}DzcoinsInput`).value||0),category:Number($(`cfg${id}CategoryInput`).value||1),showroom_section:$(`cfg${id}SectionInput`).value,showroom_subcategory:$(`cfg${id}SubcategoryInput`).value,vip:Number($(`cfg${id}VipInput`).value||0),apear:Number($(`cfg${id}ApearInput`).value||1),selling:Number($(`cfg${id}SellingInput`).value||1),tradeble:Number($(`cfg${id}TradebleInput`).value||1),tunable:Number($(`cfg${id}TunableInput`).value||1),type:$(`cfg${id}TypeInput`).value,image:$(`cfg${id}ImageInput`).value.trim()};}
function saveConfigVeh(id){nui('configVehSave',{id,payload:cfgPayload(id)});$('configStatus').textContent='Se salveaza...';}
function deleteConfigVeh(id){showModal('Stergere vehiclenames', `Stergi masina din vehiclenames ID ${id}?`, { okText:'STERGE', onConfirm:()=>{nui('configVehDelete',{id});$('configStatus').textContent='Se sterge...';} });}

function showOwnedVehs(data={}){ownedUid=Number(data.uid||0);ownedVehicles=Array.isArray(data.vehicles)?data.vehicles:[];$('ownedTitle').textContent=`VEHS UID ${ownedUid}`;showPanel('ownedVehPanel');renderOwnedVehs();}
function renderOwnedVehs(){const q=String($('ownedSearch').value||'').toLowerCase().trim();const list=ownedVehicles.filter(v=>!q||`${v.id} ${v.name} ${v.model} ${v.plate} ${v.gradient}`.toLowerCase().includes(q));$('ownedList').innerHTML=list.map(v=>ownedCard(v)).join('')||'<div class="empty">UID-ul nu are masini.</div>';}
function ownedCard(v){const spawned=bool(v.spawned);const img=String(v.image||'').length>5?`<img src="${esc(v.image)}" onerror="this.style.display='none'">`:'<div class="noimg">DZ</div>';return `<div class="owned-card">
 <div class="owned-img">${img}</div><div class="owned-info"><b>${esc(v.name)}</b><span>Model: ${esc(v.model)}</span><span>Plate: ${esc(v.plate)}</span><span>SQL ID: ${Number(v.id||0)} • Gradient: ${Number(v.gradient||0)>0?Number(v.gradient):'none'}</span><span>${spawned?`Spawned • Net ID: ${Number(v.netId||0)} • VS ID: ${Number(v.vsId||0)}`:'Not spawned'}</span></div>
 <div class="owned-actions"><button onclick="ownedAction('spawn',${v.id})">${spawned?'BRING':'SPAWN'}</button>${spawned?`<button onclick="ownedAction('goto',${v.id})">GO TO</button><button onclick="ownedAction('bring',${v.id})">BRING</button>`:''}<button onclick="transferOwned(${v.id})">TRANSFER</button><button class="danger" onclick="takeOwned(${v.id})">TAKE</button></div>
 </div>`;}
function ownedAction(action,id,extra={}){nui('ownedVehAction',{action,uid:ownedUid,vehicleId:id,extra});$('ownedStatus').textContent='Se executa...';}
function takeOwned(id){showModal('Stergere masina', `Esti sigur ca stergi masina SQL ID ${id}?`, { okText:'STERGE', onConfirm:()=>ownedAction('take',id) });}
function transferOwned(id){showModal('Transfer masina', `Introdu UID-ul noului owner pentru masina SQL ID ${id}.`, { input:true, placeholder:'UID nou owner', okText:'TRANSFERA', onConfirm:(target)=>{const uid=Number(target); if(!uid||uid<=0){$('ownedStatus').textContent='UID invalid.';$('ownedStatus').className='status error';return;} ownedAction('transfer',id,{targetUid:uid});} });}
function panelResult(data){const el = $('configVehPanel').classList.contains('hidden') ? $('ownedStatus') : $('configStatus');el.textContent=data.message||'';el.className='status '+(data.ok?'success':'error');}

window.addEventListener('message', (event)=>{const data=event.data||{}; if(data.action==='coords')showCoords(data.data||{}); if(data.action==='addVeh')showAddVeh(data.data||{}); if(data.action==='addVehResult'||data.action==='addCarResult')addVehResult(data); if(data.action==='configVeh')showConfigVeh(data.data||{}); if(data.action==='ownedVehs')showOwnedVehs(data.data||{}); if(data.action==='panelResult')panelResult(data);});
document.addEventListener('keydown',(e)=>{if(e.key==='Escape')closeAll();});
