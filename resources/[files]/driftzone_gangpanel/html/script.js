'use strict';

const app = document.getElementById('app');
const nav = document.getElementById('nav');
const page = document.getElementById('page');
const pageTitle = document.getElementById('pageTitle');
const pageKicker = document.getElementById('pageKicker');
const profileLine = document.getElementById('profileLine');
const gangBadge = document.getElementById('gangBadge');
const modal = document.getElementById('modal');
const modalBox = document.getElementById('modalBox');
const selector = document.getElementById('selector');
const taxModal = document.getElementById('taxModal');
const incomingTaxTitle = document.getElementById('incomingTaxTitle');
const incomingTaxText = document.getElementById('incomingTaxText');
const claimHint = document.getElementById('claimHint');

let state = { user: {}, access: {}, gangs: [], gang: null, members: [], taxes: [], categories: [], taxAmounts: [100000,70000,40000] };
let activePage = 'taxes';
let selectedGangId = null;
let selectedCategory = 0;
let currentTax = null;
let selectorActive = false;
let selectorTimer = null;
let selectorStartedAt = 0;

function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data) }).then(r => r.json().catch(() => ({}))).catch(() => ({}));
}
function esc(v){return String(v ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#039;')}
function money(v){return '$' + Number(v||0).toLocaleString('en-US')}
function show(el){el.classList.remove('hidden')}
function hide(el){el.classList.add('hidden')}
function rolePower(role){return role === 'Lider' ? 3 : role === 'Co-Lider' ? 2 : role === 'Membru' ? 1 : 0}
function isSyndicate(){return state.user && state.user.syndicate === true}
function isLeader(){return state.user && state.user.role === 'Lider'}
function isBoss(){return isSyndicate() || rolePower(state.user.role) >= 2}
function canRevenue(){return isSyndicate() || rolePower(state.user.role) >= 2}
function canMembers(){return isSyndicate() || rolePower(state.user.role) >= 2}
function closePhone(){nui('close'); hide(app); hide(modal); hide(selector); selectorActive=false}
function refresh(){nui('refresh')}
function setPage(p){activePage = p; hide(modal); render()}
function openModal(html){modalBox.innerHTML = html; show(modal)}
function closeModal(){hide(modal); modalBox.innerHTML=''}
function val(id){const el=document.getElementById(id); return el ? el.value : ''}

function navItems(){
    const items = [];
    if (isSyndicate()) items.push(['gangs','Mafii','Gestionează orașul']);
    if (isBoss()) items.push(['dashboard','Dashboard','Status organizație']);
    if (canMembers()) items.push(['members','Membri','Administrare membri']);
    items.push(['taxes','Taxe','Oferă și urmărește taxe']);
    if (canRevenue()) items.push(['revenue','Venituri','Bani colectați']);
    return items;
}

function normalizePage(){
    const allowed = navItems().map(i => i[0]);
    if (!allowed.includes(activePage)) activePage = allowed[0] || 'taxes';
}

function render(){
    normalizePage();
    document.documentElement.style.setProperty('--main', state.mainColor || '#04c7f7');
    const user = state.user || {};
    profileLine.textContent = `${user.name || 'Necunoscut'} • CNP ${user.cnp || '-'}`;
    const g = state.gang;
    gangBadge.innerHTML = g ? `<span style="background:${esc(g.color || '#04c7f7')}"></span><div><b>${esc(g.shortcut || '')}</b><small>ID ${esc(g.id)} • ${esc(g.type || '')}</small></div>` : `<span></span><div><b>Sindicat</b><small>Control oraș</small></div>`;
    nav.innerHTML = navItems().map(([id,label,sub]) => `<button class="${activePage===id?'active':''}" onclick="setPage('${id}')"><b>${label}</b><small>${sub}</small></button>`).join('');
    if (activePage === 'gangs') return renderGangs();
    if (activePage === 'dashboard') return renderDashboard();
    if (activePage === 'members') return renderMembers();
    if (activePage === 'revenue') return renderRevenue();
    return renderTaxes();
}

function setHeader(k,t){pageKicker.textContent=k; pageTitle.textContent=t}
function statsCards(items){return `<div class="stats">${items.map(i=>`<div class="stat"><span>${esc(i[0])}</span><b>${esc(i[1])}</b><small>${esc(i[2]||'')}</small></div>`).join('')}</div>`}

function renderDashboard(){
    setHeader('Organizație','Dashboard');
    const g = state.gang || {};
    page.innerHTML = `${statsCards([
        ['ID Mafie', g.id || '-', 'identificator intern'],
        ['Membri total', g.members_total || 0, 'în organizație'],
        ['Membri pe oraș', g.members_online || 0, 'online acum'],
        ['Venituri', money(g.revenue || 0), 'taxe colectate']
    ])}<div class="panel-card"><h3>${esc(g.name || 'Fără organizație')}</h3><p>${esc(g.type || '')} • Shortcut ${esc(g.shortcut || '-')}</p><div class="split"><div><b>Garage</b><span>${coords(g,'garage')}</span></div><div><b>Storage</b><span>${coords(g,'storage')}</span></div></div></div>`;
}
function coords(g,p){const x=g[p+'_x']; if(x===null||typeof x==='undefined') return 'Nesetat'; return `${Number(g[p+'_x']).toFixed(2)}, ${Number(g[p+'_y']).toFixed(2)}, ${Number(g[p+'_z']).toFixed(2)}`}

function renderGangs(){
    setHeader('Sindicat','Mafii din oraș');
    const rows = (state.gangs||[]).map(g => `<tr onclick="selectGang(${Number(g.id)})"><td>#${g.id}</td><td><span class="color" style="background:${esc(g.color)}"></span>${esc(g.name)}</td><td>${esc(g.shortcut)}</td><td>${esc(g.type)}</td><td>${g.members_total||0}</td><td>${g.members_online||0}</td><td>${money(g.revenue||0)}</td></tr>`).join('');
    page.innerHTML = `<div class="toolbar"><button class="primary" onclick="openGangModal()">Create Gang</button><button onclick="refresh()">Actualizează</button></div><div class="table-wrap"><table><thead><tr><th>ID</th><th>Mafie</th><th>Shortcut</th><th>Tip</th><th>Total</th><th>Pe oraș</th><th>Venituri</th></tr></thead><tbody>${rows||'<tr><td colspan="7">Nu exista mafii.</td></tr>'}</tbody></table></div>`;
}

function selectGang(id){selectedGangId=id; nui('getGangDetails',{gang_id:id})}
function openGangModal(g={}){
    openModal(`<div class="modal-head"><h3>${g.id?'Editează':'Creează'} mafie</h3><button onclick="closeModal()">×</button></div><div class="form-grid">
        <label>Tip<select id="g_type"><option ${g.type==='Mafie Neoficiala'?'selected':''}>Mafie Neoficiala</option><option ${g.type==='Mafie Oficiala'?'selected':''}>Mafie Oficiala</option></select></label>
        <label>Nume<input id="g_name" value="${esc(g.name||'')}" placeholder="Nume mafie"></label>
        <label>Shortcut<input id="g_shortcut" value="${esc(g.shortcut||'')}" placeholder="EX: B13"></label>
        <label>Culoare HEX<input id="g_color" value="${esc(g.color||'#04c7f7')}" placeholder="#04c7f7"></label>
        <label>CNP Lider<input id="g_leader" type="number" value="${esc(g.leader_uid||'')}" placeholder="CNP"></label>
        <label>Garage X<input id="g_gx" type="number" step="0.001" value="${esc(g.garage_x??'')}"></label>
        <label>Garage Y<input id="g_gy" type="number" step="0.001" value="${esc(g.garage_y??'')}"></label>
        <label>Garage Z<input id="g_gz" type="number" step="0.001" value="${esc(g.garage_z??'')}"></label>
        <label>Storage X<input id="g_sx" type="number" step="0.001" value="${esc(g.storage_x??'')}"></label>
        <label>Storage Y<input id="g_sy" type="number" step="0.001" value="${esc(g.storage_y??'')}"></label>
        <label>Storage Z<input id="g_sz" type="number" step="0.001" value="${esc(g.storage_z??'')}"></label>
    </div><div class="modal-actions"><button onclick="fillCoords('g')">Coordonate actuale</button>${g.id?`<button class="danger" onclick="deleteGang(${g.id})">Dezactivează</button>`:''}<button class="primary" onclick="saveGang(${g.id||0})">Salvează</button></div>`)
}
async function fillCoords(prefix){ const r = await nui('getCoords'); if(!r || !r.ok) return; if(prefix==='g'){ const fields=[['g_gx',r.x],['g_gy',r.y],['g_gz',r.z],['g_sx',r.x],['g_sy',r.y],['g_sz',r.z]]; fields.forEach(([id,v])=>{ const el=document.getElementById(id); if(el && !el.value) el.value=v; }); } }
function saveGang(id){
    const data={id:id||undefined,type:val('g_type'),name:val('g_name'),shortcut:val('g_shortcut'),color:val('g_color'),leader_uid:Number(val('g_leader')),garage_x:Number(val('g_gx')),garage_y:Number(val('g_gy')),garage_z:Number(val('g_gz')),storage_x:Number(val('g_sx')),storage_y:Number(val('g_sy')),storage_z:Number(val('g_sz'))};
    nui(id?'updateGang':'createGang',data); closeModal();
}
function deleteGang(id){nui('deleteGang',{gang_id:id}); closeModal()}

function renderMembers(){
    setHeader('Organizație','Membri');
    const g = state.gang || {};
    const rows = (state.members||[]).map(m => `<tr><td>${m.cnp}</td><td>${esc(m.name||('CNP '+m.cnp))}</td><td><span class="pill">${esc(m.role)}</span></td><td>${m.online?'<b class="ok">Pe oraș</b>':'Plecat'}</td>${isSyndicate()?`<td>${m.server_id||'-'}</td>`:''}<td><button onclick="openRoleModal(${m.cnp},'${esc(m.role)}')">Rol</button><button class="danger" onclick="kickMember(${m.cnp})">Scoate</button></td></tr>`).join('');
    page.innerHTML = `<div class="toolbar"><button class="primary" onclick="openAddMember()">Adaugă membru</button></div><div class="table-wrap"><table><thead><tr><th>CNP</th><th>Nume</th><th>Grad</th><th>Status</th>${isSyndicate()?'<th>ID server</th>':''}<th>Acțiuni</th></tr></thead><tbody>${rows||'<tr><td colspan="6">Nu ai membri afișați.</td></tr>'}</tbody></table></div>`;
}
function openAddMember(){
    const gangOpt = isSyndicate()?`<label>ID Mafie<input id="m_gang" type="number" value="${state.gang?.id||selectedGangId||''}"></label>`:'';
    openModal(`<div class="modal-head"><h3>Adaugă membru</h3><button onclick="closeModal()">×</button></div><div class="form-grid">${gangOpt}<label>CNP<input id="m_cnp" type="number" placeholder="CNP"></label><label>Grad<select id="m_role"><option>Membru</option><option>Co-Lider</option>${isSyndicate()?'<option>Lider</option>':''}</select></label></div><div class="modal-actions"><button class="primary" onclick="addMember()">Adaugă</button></div>`)
}
function addMember(){nui('addMember',{gang_id:Number(val('m_gang')||state.gang?.id),uid:Number(val('m_cnp')),role:val('m_role')}); closeModal()}
function kickMember(cnp){nui('kickMember',{gang_id:state.gang?.id||selectedGangId,uid:cnp})}
function openRoleModal(cnp,role){openModal(`<div class="modal-head"><h3>Schimbă grad</h3><button onclick="closeModal()">×</button></div><label class="single">Grad<select id="r_role"><option ${role==='Membru'?'selected':''}>Membru</option><option ${role==='Co-Lider'?'selected':''}>Co-Lider</option>${isSyndicate()?`<option ${role==='Lider'?'selected':''}>Lider</option>`:''}</select></label><div class="modal-actions"><button class="primary" onclick="changeRole(${cnp})">Salvează</button></div>`)}
function changeRole(cnp){nui('changeRole',{gang_id:state.gang?.id||selectedGangId,uid:cnp,role:val('r_role')}); closeModal()}

function renderTaxes(){
    setHeader('Taxe','Taxe și categorii');
    const cats = [{id:0,name:'Toate'}, ...(state.categories||[])];
    const catButtons = cats.map(c=>`<button class="chip ${selectedCategory===Number(c.id)?'active':''}" onclick="selectedCategory=${Number(c.id)};renderTaxes()">${esc(c.name)}</button>`).join('');
    const filtered = (state.taxes||[]).filter(t=>!selectedCategory || Number(t.category_id)===selectedCategory);
    const rows = filtered.map(t=>`<tr><td>${esc(t.category_name)}</td><td>${money(t.amount)}</td><td>CNP ${t.payer_uid}</td><td>CNP ${t.issuer_uid}</td><td>${esc(t.paid_from||'-')}</td><td><span class="pill ${t.status==='paid'?'paid':'refused'}">${esc(t.status)}</span></td></tr>`).join('');
    page.innerHTML = `<div class="category-strip">${catButtons}</div><div class="toolbar"><button class="primary" onclick="openOfferTax()">Oferă Taxă</button>${isSyndicate()?'<button onclick="openTaxCategory()">Categorie nouă</button>':''}</div><div class="table-wrap"><table><thead><tr><th>Taxă</th><th>Sumă</th><th>CNP plătitor</th><th>CNP emitent</th><th>Din</th><th>Status</th></tr></thead><tbody>${rows||'<tr><td colspan="6">Nu există taxe.</td></tr>'}</tbody></table></div>`;
}
function openTaxCategory(){openModal(`<div class="modal-head"><h3>Categorie taxă</h3><button onclick="closeModal()">×</button></div><div class="form-grid"><label>Nume<input id="tc_name" placeholder="Protecție"></label><label>Descriere<input id="tc_desc" placeholder="Optional"></label></div><div class="modal-actions"><button class="primary" onclick="saveTaxCategory()">Salvează</button></div>`)}
function saveTaxCategory(){nui('createTaxCategory',{name:val('tc_name'),description:val('tc_desc')}); closeModal()}
function openOfferTax(){
    const cats = (state.categories||[]).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');
    const amounts = (state.taxAmounts||[100000,70000,40000]).map(a=>`<button class="amount-choice" onclick="document.getElementById('tax_amount').value='${a}'">${money(a)}</button>`).join('');
    openModal(`<div class="modal-head"><h3>Oferă taxă</h3><button onclick="closeModal()">×</button></div><div class="form-grid"><label>Categorie<select id="tax_category">${cats}</select></label><label>Sumă<input id="tax_amount" type="number" value="100000"></label></div><div class="amounts">${amounts}</div><div class="modal-actions"><button class="primary" onclick="startTaxSelector()">Selectează persoana</button></div>`)
}
function startTaxSelector(){const payload={gang_id:state.gang?.id||selectedGangId,category_id:Number(val('tax_category')),amount:Number(val('tax_amount'))}; closeModal(); selectorActive=true; selectorStartedAt=Date.now(); show(selector); nui('startTaxSelector',payload)}

function renderRevenue(){
    setHeader('Venituri','Bani colectați');
    const g = state.gang || {};
    page.innerHTML = `${statsCards([['Venituri disponibile',money(g.revenue||0),'din taxe plătite'],['ID Mafie',g.id||'-','apare și la membri'],['Membri pe oraș',g.members_online||0,'online acum']])}<div class="panel-card"><h3>Retragere venituri</h3><p>Retragerea trimite banii către o locație discretă. După procesare vei primi waypoint albastru.</p><div class="toolbar"><button class="primary" onclick="requestWithdrawal()">Retrage</button>${isSyndicate()?'<button onclick="openAdjustRevenue()">Adaugă / Șterge venituri</button>':''}</div></div>`;
}
function requestWithdrawal(){nui('requestWithdrawal',{gang_id:state.gang?.id||selectedGangId})}
function openAdjustRevenue(){openModal(`<div class="modal-head"><h3>Venituri mafie</h3><button onclick="closeModal()">×</button></div><div class="form-grid"><label>ID Mafie<input id="rev_gang" type="number" value="${state.gang?.id||selectedGangId||''}"></label><label>Mod<select id="rev_mode"><option value="add">Adaugă</option><option value="remove">Șterge</option></select></label><label>Sumă<input id="rev_amount" type="number" value="100000"></label></div><div class="modal-actions"><button class="primary" onclick="adjustRevenue()">Aplică</button></div>`)}
function adjustRevenue(){nui('adjustRevenue',{gang_id:Number(val('rev_gang')),mode:val('rev_mode'),amount:Number(val('rev_amount'))}); closeModal()}

function payTax(){ if(currentTax){nui('payTax',{requestId:currentTax.requestId}); hide(taxModal); currentTax=null} }
function refuseTax(){ if(currentTax){nui('refuseTax',{requestId:currentTax.requestId}); hide(taxModal); currentTax=null} }

window.addEventListener('mousemove', e=>{ if(!selectorActive) return; if(selectorTimer) return; selectorTimer=setTimeout(()=>{selectorTimer=null; nui('selectorMove',{x:e.clientX/window.innerWidth,y:e.clientY/window.innerHeight})}, 35) });
window.addEventListener('click', e=>{ if(selectorActive){ if(Date.now()-selectorStartedAt<220) return; nui('selectorClick'); selectorActive=false; hide(selector)} });
document.addEventListener('keydown', e=>{ if(e.key==='Escape') closePhone(); if(e.key==='`'||e.code==='Backquote') nui('toggleFocus') });

window.addEventListener('message', event=>{
    const msg=event.data||{};
    if(msg.action==='open'){state=msg.data||state; show(app); render()}
    if(msg.action==='update'){state=msg.data||state; render()}
    if(msg.action==='gangDetails'){state.gang=msg.data.gang||state.gang; state.members=msg.data.members||[]; state.taxes=msg.data.taxes||[]; if(['gangs'].includes(activePage)) activePage='dashboard'; render()}
    if(msg.action==='close'){hide(app); hide(modal); hide(selector)}
    if(msg.action==='openSelector'){selectorActive=true; show(selector)}
    if(msg.action==='closeSelector'){selectorActive=false; hide(selector)}
    if(msg.action==='incomingTax'){currentTax=msg.data||{}; incomingTaxTitle.textContent=currentTax.categoryName||'Taxă'; incomingTaxText.textContent=`${currentTax.gangName||'Mafie'} • Pret: ${money(currentTax.amount||0)} • Emis de CNP ${currentTax.issuerCnp||'-'}`; show(taxModal)}
    if(msg.action==='clearIncomingTax'){if(currentTax&&currentTax.requestId===msg.requestId){currentTax=null; hide(taxModal)}}
    if(msg.action==='claimHint'){claimHint.innerHTML=`Apasă <b>E</b> pentru a revendica ${money(msg.amount||0)}`; claimHint.classList.toggle('hidden', msg.visible!==true)}
    if(msg.action==='focus'){document.body.classList.toggle('no-cursor', msg.enabled===false)}
});

setTimeout(()=>nui('ready'),80);
