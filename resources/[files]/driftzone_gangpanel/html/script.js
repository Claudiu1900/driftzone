'use strict';

const root = document.getElementById('root');
const nav = document.getElementById('nav');
const view = document.getElementById('view');
const selfInfo = document.getElementById('selfInfo');
const pageTitle = document.getElementById('pageTitle');
const pageSubtitle = document.getElementById('pageSubtitle');
const createGangBtn = document.getElementById('createGangBtn');
const modal = document.getElementById('modal');
const modalTitle = document.getElementById('modalTitle');
const modalBody = document.getElementById('modalBody');
const toast = document.getElementById('toast');

let state = {};
let activePage = 'gangs';
let selectedGangId = null;
let focusEnabled = true;
let toastTimer = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function esc(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function money(n) { return Number(n || 0).toLocaleString('ro-RO'); }
function gangColor(g) { return esc((g && g.color) || '#04c7f7'); }
function isSyndicate() { return state.self && state.self.syndicate === true; }
function myRole() { return (state.self && state.self.role) || 'Membru'; }
function canManageMembers() { return isSyndicate() || myRole() === 'Lider' || myRole() === 'Co-Lider'; }
function canChangeRole(role) { return isSyndicate() || myRole() === 'Lider'; }

function showToast(type, message) {
    if (!message) return;
    toast.className = `toast ${type || 'info'}`;
    toast.textContent = message;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 2600);
}

function setTitle(title, subtitle) {
    pageTitle.textContent = title;
    pageSubtitle.textContent = subtitle || '';
}

function open(data) {
    state = data || {};
    selectedGangId = (state.details && state.details.gang && state.details.gang.id) || (state.gangs && state.gangs[0] && state.gangs[0].id) || null;
    activePage = 'gangs';
    document.documentElement.style.setProperty('--main', state.mainColor || '#04c7f7');
    root.classList.remove('hidden');
    render();
}

function closeLocal() {
    root.classList.add('hidden');
    closeModal();
}

function closePanel() { nui('close'); closeLocal(); }
function refreshData() { nui('refresh'); }

function mergeUpdate(data) {
    if (!data) return;
    if (data.detailsOnly) {
        state.details = data.details;
        render();
        return;
    }
    state = { ...state, ...data };
    if (!selectedGangId && state.gangs && state.gangs[0]) selectedGangId = state.gangs[0].id;
    render();
}

const navItemsBase = [
    ['gangs', 'Gangs', 'gangs.svg'],
    ['members', 'Members', 'members.svg'],
    ['taxes', 'Taxes', 'wallet.svg'],
    ['settings', 'Settings', 'settings.svg']
];

function renderNav() {
    const items = navItemsBase.filter(([key]) => {
        if (key === 'settings') return isSyndicate();
        if (key === 'members') return isSyndicate() || (state.self && state.self.gangId);
        return true;
    });

    nav.innerHTML = items.map(([key, label, icon]) => `
        <button class="nav-item ${activePage === key ? 'active' : ''}" onclick="goPage('${key}')">
            <img src="assets/icons/${icon}" draggable="false">
            <span>${label}</span>
        </button>
    `).join('');
}

function render() {
    const self = state.self || {};
    selfInfo.textContent = `${self.username || 'Player'} • ${self.role || self.access || ''}`;
    createGangBtn.classList.toggle('hidden', !isSyndicate() || activePage !== 'gangs');
    renderNav();

    if (activePage === 'gangs') renderGangs();
    else if (activePage === 'members') renderMembers();
    else if (activePage === 'taxes') renderTaxes();
    else if (activePage === 'settings') renderSettings();
}

function goPage(page) {
    activePage = page;
    render();
}

function getSelectedGang() {
    const gangs = Array.isArray(state.gangs) ? state.gangs : [];
    return gangs.find(g => Number(g.id) === Number(selectedGangId)) || gangs[0] || null;
}

function selectGang(id) {
    selectedGangId = Number(id);
    nui('getGangDetails', { gangId: selectedGangId });
    render();
}

function renderGangs() {
    setTitle('Gangs', isSyndicate() ? 'Administrare completa pentru toate gangurile.' : 'Informatii despre gangul tau.');
    const gangs = Array.isArray(state.gangs) ? state.gangs : [];

    if (gangs.length <= 0) {
        view.innerHTML = `<div class="empty-card">Nu exista ganguri disponibile.</div>`;
        return;
    }

    view.innerHTML = `
        <div class="gang-grid">
            ${gangs.map(g => `
                <article class="gang-card ${Number(selectedGangId) === Number(g.id) ? 'selected' : ''}" onclick="selectGang(${Number(g.id)})" style="--gang:${gangColor(g)}">
                    <div class="gang-card-top">
                        <div class="gang-badge">${esc(g.shortcut || 'G')}</div>
                        <div>
                            <h3>${esc(g.name)}</h3>
                            <p>${esc(g.type || 'Neo')} • ID ${Number(g.id)}</p>
                        </div>
                    </div>
                    <div class="stats-row">
                        <div><b>${Number(g.totalMembers || 0)}</b><span>Total</span></div>
                        <div><b>${Number(g.onlineMembers || 0)}</b><span>Online</span></div>
                        <div><b>${Number(g.coleaders || 0)}</b><span>Co-Lideri</span></div>
                    </div>
                    <div class="gang-line"></div>
                </article>
            `).join('')}
        </div>
    `;
}

function detailsGang() {
    return (state.details && state.details.gang) || getSelectedGang();
}

function renderMembers() {
    const gang = detailsGang();
    if (!gang) {
        setTitle('Members', 'Nu ai gang selectat.');
        view.innerHTML = `<div class="empty-card">Selecteaza un gang.</div>`;
        return;
    }
    setTitle('Members', `${gang.name || ''} • membri si grade`);

    const members = (state.details && Array.isArray(state.details.members)) ? state.details.members : [];
    const addBox = canManageMembers() ? `
        <section class="action-card">
            <h3>Adauga membru</h3>
            <div class="inline-form">
                <input id="addUid" type="number" placeholder="UID jucator">
                <select id="addRole">
                    <option>Membru</option>
                    ${myRole() === 'Lider' || isSyndicate() ? '<option>Co-Lider</option>' : ''}
                    ${isSyndicate() ? '<option>Lider</option>' : ''}
                </select>
                <button class="primary-btn" onclick="addMember()">Adauga</button>
            </div>
        </section>
    ` : '';

    view.innerHTML = `
        ${addBox}
        <section class="table-card">
            <div class="table-head">
                <b>Lista membri</b>
                <span>${members.length} membri</span>
            </div>
            <div class="member-list">
                ${members.map(m => renderMemberRow(m, gang)).join('') || '<div class="empty-row">Nu sunt membri.</div>'}
            </div>
        </section>
    `;
}

function renderMemberRow(m, gang) {
    const online = m.online === true;
    const role = esc(m.role || 'Membru');
    const uidText = isSyndicate() ? `<span class="uid">UID ${Number(m.uid || 0)} ${m.source ? ' • ID ' + Number(m.source) : ''}</span>` : '';
    const canKick = canManageMembers() && !(m.role === 'Lider' && !isSyndicate()) && Number(m.uid) !== Number(state.self && state.self.uid);
    const canRole = canChangeRole(m.role) && Number(m.uid) !== Number(state.self && state.self.uid);

    return `
        <div class="member-row">
            <div class="member-main">
                <div class="avatar ${online ? 'online' : ''}">${esc(String(m.username || '?').charAt(0).toUpperCase())}</div>
                <div>
                    <b>${esc(m.username || 'Membru')}</b>
                    ${uidText}
                </div>
            </div>
            <div class="role-pill">${role}</div>
            <div class="status ${online ? 'on' : 'off'}">${online ? 'Online' : 'Offline'}</div>
            <div class="row-actions">
                ${canRole ? `<select onchange="changeRole(${Number(m.uid)}, this.value)"><option>${role}</option><option>Membru</option><option>Co-Lider</option>${isSyndicate() ? '<option>Lider</option>' : ''}</select>` : ''}
                ${canKick ? `<button class="danger-soft" onclick="kickMember(${Number(m.uid)})">Kick</button>` : ''}
            </div>
        </div>
    `;
}

function renderTaxes() {
    setTitle('Taxes', 'Sectiune pregatita pentru sistemul de taxe.');
    view.innerHTML = `
        <div class="tax-grid">
            <div class="metric-card"><span>Status</span><b>Pregatit</b><p>Sistemul de taxe poate fi legat direct in aceasta categorie.</p></div>
            <div class="metric-card"><span>Acces Membru</span><b>Activ</b><p>Membrii simpli vad doar categoria de taxe.</p></div>
            <div class="metric-card"><span>Optimizare</span><b>Server-side</b><p>Actiunile sunt validate in server/main.lua.</p></div>
        </div>
    `;
}

function renderSettings() {
    setTitle('Settings', 'Editare gang selectat.');
    const gang = detailsGang();
    const logs = (state.details && Array.isArray(state.details.logs)) ? state.details.logs : [];
    if (!gang) {
        view.innerHTML = `<div class="empty-card">Selecteaza un gang pentru editare.</div>`;
        return;
    }

    view.innerHTML = `
        <section class="action-card">
            <h3>Edit gang</h3>
            <div class="form-grid">
                <input id="editName" value="${esc(gang.name || '')}" placeholder="Nume gang">
                <input id="editShortcut" value="${esc(gang.shortcut || '')}" placeholder="Shortcut">
                <select id="editType"><option ${gang.gang_type === 'Neo' ? 'selected' : ''}>Neo</option><option ${gang.gang_type === 'Oficiala' ? 'selected' : ''}>Oficiala</option></select>
                <input id="editColor" type="text" value="${esc(gang.color || '#04c7f7')}" placeholder="#04C7F7">
                <input id="editLeader" type="number" value="${Number(gang.leader_uid || 0)}" placeholder="UID Lider">
                <input id="garageX" type="number" step="0.001" value="${gang.garage_x ?? ''}" placeholder="Garage X">
                <input id="garageY" type="number" step="0.001" value="${gang.garage_y ?? ''}" placeholder="Garage Y">
                <input id="garageZ" type="number" step="0.001" value="${gang.garage_z ?? ''}" placeholder="Garage Z">
                <input id="storageX" type="number" step="0.001" value="${gang.storage_x ?? ''}" placeholder="Storage X">
                <input id="storageY" type="number" step="0.001" value="${gang.storage_y ?? ''}" placeholder="Storage Y">
                <input id="storageZ" type="number" step="0.001" value="${gang.storage_z ?? ''}" placeholder="Storage Z">
            </div>
            <div class="buttons-row">
                <button class="primary-btn" onclick="saveGang()">Save</button>
                <button class="danger-btn" onclick="deleteGang()">Disable Gang</button>
            </div>
        </section>
        <section class="table-card logs-card">
            <div class="table-head"><b>Logs</b><span>ultimele 30</span></div>
            ${logs.map(l => `<div class="log-row"><b>${esc(l.action)}</b><span>actor ${Number(l.actor_uid || 0)} → target ${Number(l.target_uid || 0)}</span></div>`).join('') || '<div class="empty-row">Fara loguri.</div>'}
        </section>
    `;
}

function openGangModal() {
    modalTitle.textContent = 'Create Gang';
    modalBody.innerHTML = `
        <div class="form-grid modal-form">
            <select id="newType"><option>Neo</option><option>Oficiala</option></select>
            <input id="newName" placeholder="Nume gang">
            <input id="newShortcut" placeholder="Shortcut">
            <input id="newColor" value="#04C7F7" placeholder="#04C7F7">
            <input id="newLeader" type="number" placeholder="UID Lider">
            <input id="newGarageX" type="number" step="0.001" placeholder="Garage X optional">
            <input id="newGarageY" type="number" step="0.001" placeholder="Garage Y optional">
            <input id="newGarageZ" type="number" step="0.001" placeholder="Garage Z optional">
            <input id="newStorageX" type="number" step="0.001" placeholder="Storage X optional">
            <input id="newStorageY" type="number" step="0.001" placeholder="Storage Y optional">
            <input id="newStorageZ" type="number" step="0.001" placeholder="Storage Z optional">
        </div>
        <button class="primary-btn full" onclick="createGang()">Create</button>
    `;
    modal.classList.remove('hidden');
    setTimeout(() => document.getElementById('newName')?.focus(), 50);
}

function closeModal() { modal.classList.add('hidden'); modalBody.innerHTML = ''; }
function val(id) { return document.getElementById(id)?.value || ''; }
function numVal(id) { const v = val(id); return v === '' ? null : Number(v); }

function createGang() {
    nui('createGang', {
        gang_type: val('newType'), name: val('newName'), shortcut: val('newShortcut'), color: val('newColor'), leader_uid: Number(val('newLeader') || 0),
        garage_x: numVal('newGarageX'), garage_y: numVal('newGarageY'), garage_z: numVal('newGarageZ'),
        storage_x: numVal('newStorageX'), storage_y: numVal('newStorageY'), storage_z: numVal('newStorageZ')
    });
    closeModal();
}

function saveGang() {
    const gang = detailsGang();
    if (!gang) return;
    nui('updateGang', {
        gangId: Number(gang.id), gang_type: val('editType'), name: val('editName'), shortcut: val('editShortcut'), color: val('editColor'), leader_uid: Number(val('editLeader') || 0),
        garage_x: numVal('garageX'), garage_y: numVal('garageY'), garage_z: numVal('garageZ'),
        storage_x: numVal('storageX'), storage_y: numVal('storageY'), storage_z: numVal('storageZ')
    });
}

function deleteGang() {
    const gang = detailsGang();
    if (!gang) return;
    nui('deleteGang', { gangId: Number(gang.id) });
}

function addMember() {
    const gang = detailsGang();
    if (!gang) return;
    nui('addMember', { gangId: Number(gang.id), uid: Number(val('addUid') || 0), role: val('addRole') || 'Membru' });
}

function kickMember(uid) {
    const gang = detailsGang();
    if (!gang) return;
    nui('kickMember', { gangId: Number(gang.id), uid: Number(uid) });
}

function changeRole(uid, role) {
    const gang = detailsGang();
    if (!gang) return;
    nui('changeRole', { gangId: Number(gang.id), uid: Number(uid), role });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') open(data.data || {});
    if (data.action === 'close') closeLocal();
    if (data.action === 'update') mergeUpdate(data.data || {});
    if (data.action === 'toast') showToast(data.typ, data.message);
    if (data.action === 'focus') focusEnabled = data.focus === true;
});

document.addEventListener('keydown', (e) => {
    const tag = (document.activeElement && document.activeElement.tagName || '').toLowerCase();
    const typing = tag === 'input' || tag === 'textarea' || tag === 'select';
    if (e.key === 'Escape') {
        if (!modal.classList.contains('hidden')) closeModal();
        else closePanel();
    }
    if ((e.code === 'Backquote' || e.key === '`') && !typing) nui('toggleFocus');
});

setTimeout(() => nui('ready'), 100);
