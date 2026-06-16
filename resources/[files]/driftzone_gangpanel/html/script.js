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
const taxModal = document.getElementById('taxModal');
const incomingTaxTitle = document.getElementById('incomingTaxTitle');
const incomingTaxText = document.getElementById('incomingTaxText');
const claimHint = document.getElementById('claimHint');

let state = {
    mainColor: '#04c7f7',
    user: {},
    access: {},
    gangs: [],
    gang: null,
    members: [],
    taxes: [],
    categories: [],
    taxAmounts: [100000, 70000, 40000]
};
let activePage = 'taxes';
let selectedGangId = null;
let selectedCategory = 0;
let currentTax = null;

function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then(r => r.json().catch(() => ({}))).catch(() => ({}));
}
function esc(v) { return String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;'); }
function money(v) { return '$' + Number(v || 0).toLocaleString('en-US'); }
function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }
function val(id) { const el = document.getElementById(id); return el ? el.value : ''; }
function num(id) { const n = Number(val(id)); return Number.isFinite(n) ? n : 0; }
function rolePower(role) { return role === 'Lider' ? 3 : role === 'Co-Lider' ? 2 : role === 'Membru' ? 1 : 0; }
function isSyndicate() { return state.user && state.user.syndicate === true; }
function isBoss() { return isSyndicate() || rolePower(state.user && state.user.role) >= 2; }
function canRevenue() { return isSyndicate() || rolePower(state.user && state.user.role) >= 2; }
function canMembers() { return isSyndicate() || rolePower(state.user && state.user.role) >= 2; }
function currentGangId() { return Number((state.gang && state.gang.id) || selectedGangId || 0); }

function closePanel() {
    nui('close');
    hide(app);
    hide(modal);
}
function refresh() { nui('refresh'); }
function setHeader(kicker, title) { pageKicker.textContent = kicker; pageTitle.textContent = title; }
function setPage(pageId) { activePage = pageId; hide(modal); render(); }
function openModal(html) { modalBox.innerHTML = html; show(modal); }
function closeModal() { hide(modal); modalBox.innerHTML = ''; }
function statusText(online) { return online ? '<span class="status online">Pe oraș</span>' : '<span class="status offline">Plecat</span>'; }
function coords(g, p) {
    if (!g || g[p + '_x'] === null || typeof g[p + '_x'] === 'undefined') return 'Nesetat';
    return `${Number(g[p + '_x']).toFixed(2)}, ${Number(g[p + '_y']).toFixed(2)}, ${Number(g[p + '_z']).toFixed(2)}`;
}

function navItems() {
    const items = [];
    if (isSyndicate()) items.push(['gangs', 'Mafii', 'Control organizații']);
    if (state.gang && isBoss()) items.push(['dashboard', 'Dashboard', 'Situație rapidă']);
    if (state.gang && canMembers()) items.push(['members', 'Membri', 'Administrare']);
    if (state.gang || !isSyndicate()) items.push(['taxes', 'Taxe', 'Taxe și încasări']);
    if (state.gang && canRevenue()) items.push(['revenue', 'Venituri', 'Retrageri']);
    return items;
}
function normalizePage() {
    const allowed = navItems().map(i => i[0]);
    if (!allowed.includes(activePage)) activePage = allowed[0] || 'taxes';
}
function statsCards(items) {
    return `<div class="stats">${items.map(([label, value, sub]) => `<div class="stat"><span>${esc(label)}</span><b>${esc(value)}</b><small>${esc(sub || '')}</small></div>`).join('')}</div>`;
}

function render() {
    normalizePage();
    document.documentElement.style.setProperty('--main', state.mainColor || '#04c7f7');
    const user = state.user || {};
    profileLine.textContent = `${user.name || 'Necunoscut'} • CNP ${user.cnp || '-'}`;

    const g = state.gang;
    gangBadge.innerHTML = g
        ? `<div class="badge-color" style="background:${esc(g.color || '#04c7f7')}"></div><div><b>${esc(g.name || 'Mafie')}</b><small>ID ${esc(g.id)} • ${esc(g.shortcut || '-')} • ${esc(g.type || '')}</small></div>`
        : `<div class="badge-color"></div><div><b>${isSyndicate() ? 'Sindicat' : 'Fără mafie'}</b><small>${isSyndicate() ? 'Control oraș' : 'Acces limitat'}</small></div>`;

    nav.innerHTML = navItems().map(([id, label, sub]) => `
        <button class="${activePage === id ? 'active' : ''}" onclick="setPage('${id}')">
            <b>${label}</b><small>${sub}</small>
        </button>
    `).join('');

    if (activePage === 'gangs') return renderGangs();
    if (activePage === 'dashboard') return renderDashboard();
    if (activePage === 'members') return renderMembers();
    if (activePage === 'revenue') return renderRevenue();
    return renderTaxes();
}

function renderDashboard() {
    setHeader('Organizație', 'Dashboard');
    const g = state.gang || {};
    page.innerHTML = `
        ${statsCards([
            ['ID Mafie', g.id || '-', 'identificator intern'],
            ['Membri total', g.members_total || 0, 'în organizație'],
            ['Membri pe oraș', g.members_online || 0, 'online acum'],
            ['Venituri', money(g.revenue || 0), 'taxe colectate']
        ])}
        <div class="grid-2">
            <div class="card big-card"><h3>${esc(g.name || 'Fără organizație')}</h3><p>${esc(g.type || '')} • Shortcut ${esc(g.shortcut || '-')}</p></div>
            <div class="card"><h3>Coordonate</h3><div class="split"><div><b>Garage</b><span>${coords(g, 'garage')}</span></div><div><b>Storage</b><span>${coords(g, 'storage')}</span></div></div></div>
        </div>`;
}

function renderGangs() {
    setHeader('Sindicat', 'Mafii din oraș');
    const rows = (state.gangs || []).map(g => `
        <tr onclick="selectGang(${Number(g.id)})">
            <td>#${g.id}</td><td><span class="color" style="background:${esc(g.color)}"></span>${esc(g.name)}</td><td>${esc(g.shortcut)}</td><td>${esc(g.type)}</td><td>${g.members_total || 0}</td><td>${g.members_online || 0}</td><td>${money(g.revenue || 0)}</td>
        </tr>`).join('');
    const catRows = (state.categories || []).map(c => `<tr><td>#${c.id}</td><td>${esc(c.name)}</td><td>${esc(c.description || '-')}</td><td><button class="danger" onclick="deleteTaxCategory(${Number(c.id)})">Șterge</button></td></tr>`).join('');
    page.innerHTML = `
        <div class="toolbar"><button class="primary" onclick="openGangModal()">Creează mafie</button><button onclick="refresh()">Actualizează</button></div>
        <div class="table-wrap"><table><thead><tr><th>ID</th><th>Mafie</th><th>Shortcut</th><th>Tip</th><th>Total</th><th>Pe oraș</th><th>Venituri</th></tr></thead><tbody>${rows || '<tr><td colspan="7">Nu există mafii.</td></tr>'}</tbody></table></div>
        <div class="section-line"></div>
        <div class="toolbar"><h3>Categorii taxe</h3><button class="primary" onclick="openTaxCategory()">Categorie nouă</button></div>
        <div class="table-wrap small"><table><thead><tr><th>ID</th><th>Categorie</th><th>Descriere</th><th>Acțiune</th></tr></thead><tbody>${catRows || '<tr><td colspan="4">Nu există categorii. Creează-le manual din Sindicat.</td></tr>'}</tbody></table></div>`;
}
function selectGang(id) { selectedGangId = id; nui('getGangDetails', { gang_id: id }); }

function openGangModal(g = {}) {
    openModal(`<div class="modal-head"><h3>${g.id ? 'Editează' : 'Creează'} mafie</h3><button onclick="closeModal()">×</button></div>
        <div class="form-grid">
            <label>Tip<select id="g_type"><option ${g.type === 'Mafie Neoficiala' ? 'selected' : ''}>Mafie Neoficiala</option><option ${g.type === 'Mafie Oficiala' ? 'selected' : ''}>Mafie Oficiala</option></select></label>
            <label>Nume<input id="g_name" value="${esc(g.name || '')}" placeholder="Nume mafie"></label>
            <label>Shortcut<input id="g_shortcut" value="${esc(g.shortcut || '')}" placeholder="EX: B13"></label>
            <label>Culoare HEX<input id="g_color" value="${esc(g.color || '#04c7f7')}" placeholder="#04c7f7"></label>
            <label>CNP Lider<input id="g_leader" inputmode="numeric" value="${esc(g.leader_uid || '')}" placeholder="CNP"></label>
            <label>Garage X<input id="g_gx" inputmode="decimal" value="${esc(g.garage_x ?? '')}"></label>
            <label>Garage Y<input id="g_gy" inputmode="decimal" value="${esc(g.garage_y ?? '')}"></label>
            <label>Garage Z<input id="g_gz" inputmode="decimal" value="${esc(g.garage_z ?? '')}"></label>
            <label>Storage X<input id="g_sx" inputmode="decimal" value="${esc(g.storage_x ?? '')}"></label>
            <label>Storage Y<input id="g_sy" inputmode="decimal" value="${esc(g.storage_y ?? '')}"></label>
            <label>Storage Z<input id="g_sz" inputmode="decimal" value="${esc(g.storage_z ?? '')}"></label>
        </div>
        <div class="modal-actions"><button onclick="fillCoords()">Coordonate actuale</button>${g.id ? `<button class="danger" onclick="deleteGang(${g.id})">Dezactivează</button>` : ''}<button class="primary" onclick="saveGang(${g.id || 0})">Salvează</button></div>`);
}
async function fillCoords() {
    const r = await nui('getCoords');
    if (!r || !r.ok) return;
    [['g_gx', r.x], ['g_gy', r.y], ['g_gz', r.z], ['g_sx', r.x], ['g_sy', r.y], ['g_sz', r.z]].forEach(([id, v]) => { const el = document.getElementById(id); if (el && !el.value) el.value = v; });
}
function saveGang(id) {
    const data = { id: id || undefined, type: val('g_type'), name: val('g_name'), shortcut: val('g_shortcut'), color: val('g_color'), leader_uid: num('g_leader'), garage_x: Number(val('g_gx')), garage_y: Number(val('g_gy')), garage_z: Number(val('g_gz')), storage_x: Number(val('g_sx')), storage_y: Number(val('g_sy')), storage_z: Number(val('g_sz')) };
    nui(id ? 'updateGang' : 'createGang', data); closeModal();
}
function deleteGang(id) { nui('deleteGang', { gang_id: id }); closeModal(); }

function renderMembers() {
    setHeader('Organizație', 'Membri');
    const rows = (state.members || []).map(m => `
        <tr><td>CNP ${m.cnp}</td><td>${esc(m.name || ('CNP ' + m.cnp))}</td><td><span class="pill">${esc(m.role)}</span></td><td>${statusText(m.online)}</td>${isSyndicate() ? `<td>${m.server_id || '-'}</td>` : ''}<td><button onclick="openRoleModal(${m.cnp}, '${esc(m.role)}')">Grad</button><button class="danger" onclick="kickMember(${m.cnp})">Scoate</button></td></tr>`).join('');
    page.innerHTML = `<div class="toolbar"><button class="primary" onclick="openAddMember()">Adaugă membru</button></div><div class="table-wrap"><table><thead><tr><th>CNP</th><th>Nume</th><th>Grad</th><th>Status</th>${isSyndicate() ? '<th>ID oraș</th>' : ''}<th>Acțiuni</th></tr></thead><tbody>${rows || '<tr><td colspan="6">Nu există membri afișați.</td></tr>'}</tbody></table></div>`;
}
function openAddMember() {
    const gangOpt = isSyndicate() ? `<label>ID Mafie<input id="m_gang" inputmode="numeric" value="${currentGangId() || ''}"></label>` : '';
    openModal(`<div class="modal-head"><h3>Adaugă membru</h3><button onclick="closeModal()">×</button></div><div class="form-grid">${gangOpt}<label>CNP<input id="m_cnp" inputmode="numeric" placeholder="CNP"></label><label>Grad<select id="m_role"><option>Membru</option><option>Co-Lider</option>${isSyndicate() ? '<option>Lider</option>' : ''}</select></label></div><div class="modal-actions"><button class="primary" onclick="addMember()">Adaugă</button></div>`);
}
function addMember() { nui('addMember', { gang_id: Number(val('m_gang') || currentGangId()), uid: num('m_cnp'), role: val('m_role') }); closeModal(); }
function kickMember(cnp) { nui('kickMember', { gang_id: currentGangId(), uid: cnp }); }
function openRoleModal(cnp, role) { openModal(`<div class="modal-head"><h3>Schimbă grad</h3><button onclick="closeModal()">×</button></div><label class="single">Grad<select id="r_role"><option ${role === 'Membru' ? 'selected' : ''}>Membru</option><option ${role === 'Co-Lider' ? 'selected' : ''}>Co-Lider</option>${isSyndicate() ? `<option ${role === 'Lider' ? 'selected' : ''}>Lider</option>` : ''}</select></label><div class="modal-actions"><button class="primary" onclick="changeRole(${cnp})">Salvează</button></div>`); }
function changeRole(cnp) { nui('changeRole', { gang_id: currentGangId(), uid: cnp, role: val('r_role') }); closeModal(); }

function renderTaxes() {
    setHeader('Taxe', 'Taxe și încasări');
    const categories = state.categories || [];
    const chips = [{ id: 0, name: 'Toate' }, ...categories].map(c => `<button class="chip ${selectedCategory === Number(c.id) ? 'active' : ''}" onclick="selectedCategory=${Number(c.id)};renderTaxes()">${esc(c.name)}</button>`).join('');
    const filtered = (state.taxes || []).filter(t => !selectedCategory || Number(t.category_id) === selectedCategory);
    const rows = filtered.map(t => `<tr><td>${esc(t.category_name)}</td><td>${money(t.amount)}</td><td>CNP ${t.payer_uid}</td><td>CNP ${t.issuer_uid}</td><td>${esc(t.paid_from || '-')}</td><td><span class="pill ${t.status === 'paid' ? 'paid' : 'refused'}">${esc(t.status)}</span></td></tr>`).join('');
    page.innerHTML = `<div class="category-strip">${chips || '<span class="empty-note">Nu există categorii.</span>'}</div><div class="toolbar"><button class="primary" onclick="openOfferTax()">Oferă taxă</button>${isSyndicate() ? '<button onclick="openTaxCategory()">Categorie nouă</button>' : ''}</div><div class="table-wrap"><table><thead><tr><th>Taxă</th><th>Sumă</th><th>CNP plătitor</th><th>CNP emitent</th><th>Din</th><th>Status</th></tr></thead><tbody>${rows || '<tr><td colspan="6">Nu există taxe înregistrate.</td></tr>'}</tbody></table></div>`;
}
function openTaxCategory() { openModal(`<div class="modal-head"><h3>Categorie taxă</h3><button onclick="closeModal()">×</button></div><div class="form-grid"><label>Nume<input id="tc_name" placeholder="Ex: Control zonă"></label><label>Descriere<input id="tc_desc" placeholder="Opțional"></label></div><div class="modal-actions"><button class="primary" onclick="saveTaxCategory()">Salvează</button></div>`); }
function saveTaxCategory() { nui('createTaxCategory', { name: val('tc_name'), description: val('tc_desc') }); closeModal(); }
function deleteTaxCategory(id) { nui('deleteTaxCategory', { category_id: id }); }
function openOfferTax() {
    const categories = state.categories || [];
    if (categories.length <= 0) {
        openModal(`<div class="modal-head"><h3>Nu există categorii</h3><button onclick="closeModal()">×</button></div><p class="modal-text">Categoriile de taxe se creează manual din contul de Sindicat.</p><div class="modal-actions"><button class="primary" onclick="closeModal()">OK</button></div>`);
        return;
    }
    const cats = categories.map(c => `<option value="${c.id}">${esc(c.name)}</option>`).join('');
    const amounts = (state.taxAmounts || [100000, 70000, 40000]).map(a => `<button class="amount-choice" onclick="document.getElementById('tax_amount').value='${a}'">${money(a)}</button>`).join('');
    openModal(`<div class="modal-head"><h3>Oferă taxă</h3><button onclick="closeModal()">×</button></div><div class="form-grid"><label>Categorie<select id="tax_category">${cats}</select></label><label>Sumă<input id="tax_amount" inputmode="numeric" value="100000"></label></div><div class="amounts">${amounts}</div><div class="modal-actions"><button class="primary" onclick="startTaxSelector()">Selectează persoana</button></div>`);
}
function startTaxSelector() {
    const payload = { gang_id: currentGangId(), category_id: Number(val('tax_category')), amount: Number(val('tax_amount')) };
    closeModal();
    hide(app);
    nui('startTaxSelector', payload);
}

function renderRevenue() {
    setHeader('Venituri', 'Bani colectați');
    const g = state.gang || {};
    page.innerHTML = `${statsCards([['Venituri disponibile', money(g.revenue || 0), 'din taxe plătite'], ['ID Mafie', g.id || '-', 'organizație'], ['Membri pe oraș', g.members_online || 0, 'online acum']])}<div class="card"><h3>Retragere venituri</h3><p>Retragerea este procesată discret. După confirmare, liderul primește o locație GPS pentru ridicare.</p><div class="toolbar"><button class="primary" onclick="requestWithdrawal()">Retrage</button>${isSyndicate() ? '<button onclick="openAdjustRevenue()">Ajustează venituri</button>' : ''}</div></div>`;
}
function requestWithdrawal() { nui('requestWithdrawal', { gang_id: currentGangId() }); }
function openAdjustRevenue() { openModal(`<div class="modal-head"><h3>Venituri mafie</h3><button onclick="closeModal()">×</button></div><div class="form-grid"><label>ID Mafie<input id="rev_gang" inputmode="numeric" value="${currentGangId() || ''}"></label><label>Mod<select id="rev_mode"><option value="add">Adaugă</option><option value="remove">Șterge</option></select></label><label>Sumă<input id="rev_amount" inputmode="numeric" value="100000"></label></div><div class="modal-actions"><button class="primary" onclick="adjustRevenue()">Aplică</button></div>`); }
function adjustRevenue() { nui('adjustRevenue', { gang_id: num('rev_gang'), mode: val('rev_mode'), amount: num('rev_amount') }); closeModal(); }

function payTax() { if (currentTax) { nui('payTax', { requestId: currentTax.requestId }); hide(taxModal); currentTax = null; } }
function refuseTax() { if (currentTax) { nui('refuseTax', { requestId: currentTax.requestId }); hide(taxModal); currentTax = null; } }

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') closePanel();
    if (e.key === '`' || e.code === 'Backquote') nui('toggleFocus');
});

window.addEventListener('message', event => {
    const msg = event.data || {};
    if (msg.action === 'open') { state = msg.data || state; show(app); render(); }
    if (msg.action === 'update') { state = msg.data || state; render(); }
    if (msg.action === 'gangDetails') { state.gang = msg.data.gang || state.gang; state.members = msg.data.members || []; state.taxes = msg.data.taxes || []; activePage = 'dashboard'; show(app); render(); }
    if (msg.action === 'close') { hide(app); hide(modal); }
    if (msg.action === 'incomingTax') { currentTax = msg.data || {}; incomingTaxTitle.textContent = currentTax.categoryName || 'Taxă'; incomingTaxText.textContent = `${currentTax.gangName || 'Mafie'} • Preț: ${money(currentTax.amount || 0)} • Emis de CNP ${currentTax.issuerCnp || '-'}`; show(taxModal); }
    if (msg.action === 'clearIncomingTax') { if (currentTax && currentTax.requestId === msg.requestId) { currentTax = null; hide(taxModal); } }
    if (msg.action === 'claimHint') { claimHint.innerHTML = `Apasă <b>E</b> pentru a revendica ${money(msg.amount || 0)}`; claimHint.classList.toggle('hidden', msg.visible !== true); }
    if (msg.action === 'focus') { document.body.classList.toggle('no-cursor', msg.enabled === false); }
});

setTimeout(() => nui('ready'), 80);
