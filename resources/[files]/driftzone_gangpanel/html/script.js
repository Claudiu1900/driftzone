'use strict';

const root = document.getElementById('root');
const nav = document.getElementById('nav');
const view = document.getElementById('view');
const selfInfo = document.getElementById('selfInfo');
const quickProfile = document.getElementById('quickProfile');
const pageTitle = document.getElementById('pageTitle');
const pageSubtitle = document.getElementById('pageSubtitle');
const createGangBtn = document.getElementById('createGangBtn');
const modal = document.getElementById('modal');
const modalTitle = document.getElementById('modalTitle');
const modalBody = document.getElementById('modalBody');

let state = {};
let activePage = 'dashboard';
let selectedGangId = null;
let focusEnabled = true;
let detailsRequested = 0;

const navItemsBase = [
    ['dashboard', 'Dashboard', 'dashboard.svg'],
    ['gangs', 'Gangs', 'gangs.svg'],
    ['members', 'Members', 'members.svg'],
    ['taxes', 'Taxes', 'wallet.svg'],
    ['logs', 'Logs', 'logs.svg'],
    ['settings', 'Settings', 'settings.svg']
];

function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then(r => r.json().catch(() => ({}))).catch(() => ({}));
}

function esc(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function num(n) { return Number(n || 0).toLocaleString('ro-RO'); }
function color(g) { return esc((g && g.color) || '#04c7f7'); }
function isSyndicate() { return state.self && state.self.syndicate === true; }
function myRole() { return (state.self && state.self.role) || 'Membru'; }
function myGangId() { return Number(state.self && state.self.gangId || 0); }
function canManageMembers() { return isSyndicate() || myRole() === 'Lider' || myRole() === 'Co-Lider'; }
function canChangeRole() { return isSyndicate() || myRole() === 'Lider'; }
function gangTypes() { return (state.config && Array.isArray(state.config.gangTypes)) ? state.config.gangTypes : ['Mafie Neoficiala', 'Mafie Oficiala']; }

function setTitle(title, subtitle) {
    pageTitle.textContent = title;
    pageSubtitle.textContent = subtitle || '';
}

function open(data) {
    state = data || {};
    selectedGangId = (state.details && state.details.gang && state.details.gang.id) || (state.gangs && state.gangs[0] && state.gangs[0].id) || null;
    activePage = 'dashboard';
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
    } else {
        state = { ...state, ...data };
        if (!selectedGangId && state.gangs && state.gangs[0]) selectedGangId = state.gangs[0].id;
    }
    render();
}

function selectedGang() {
    const gangs = Array.isArray(state.gangs) ? state.gangs : [];
    const fromList = gangs.find(g => Number(g.id) === Number(selectedGangId)) || gangs[0] || null;
    return (state.details && state.details.gang && Number(state.details.gang.id) === Number(selectedGangId)) ? state.details.gang : fromList;
}

function selectedMembers() {
    return (state.details && Array.isArray(state.details.members)) ? state.details.members : [];
}

function selectedLogs() {
    return (state.details && Array.isArray(state.details.logs)) ? state.details.logs : [];
}

function requestDetails(id) {
    id = Number(id || selectedGangId || 0);
    if (!id) return;
    const now = Date.now();
    if (detailsRequested === id && now - window.__lastDetailsRequest < 500) return;
    detailsRequested = id;
    window.__lastDetailsRequest = now;
    nui('getGangDetails', { gangId: id });
}

function selectGang(id, page) {
    selectedGangId = Number(id);
    if (page) activePage = page;
    requestDetails(selectedGangId);
    render();
}

function goPage(page) {
    activePage = page;
    if ((page === 'members' || page === 'settings' || page === 'logs') && selectedGangId) requestDetails(selectedGangId);
    render();
}

function renderNav() {
    const items = navItemsBase.filter(([key]) => {
        if (key === 'settings' || key === 'logs') return isSyndicate();
        if (key === 'members') return isSyndicate() || myGangId() > 0;
        return true;
    });

    nav.innerHTML = items.map(([key, label, icon]) => `
        <button class="nav-item ${activePage === key ? 'active' : ''}" onclick="goPage('${key}')">
            <img src="assets/icons/${icon}" draggable="false">
            <span>${label}</span>
        </button>
    `).join('');
}

function renderProfile() {
    const self = state.self || {};
    selfInfo.textContent = `${self.username || 'Player'} • ${self.role || self.access || ''}`;
    quickProfile.innerHTML = `
        <div class="profile-ring">${esc(String(self.username || 'D').charAt(0).toUpperCase())}</div>
        <div>
            <b>${esc(self.username || 'Player')}</b>
            <span>${isSyndicate() ? 'Syndicate access' : (myGangId() > 0 ? esc(myRole()) : 'No gang')}</span>
        </div>
    `;
}

function render() {
    renderProfile();
    renderNav();
    createGangBtn.classList.toggle('hidden', !isSyndicate() || activePage !== 'gangs');

    if (activePage === 'dashboard') renderDashboard();
    else if (activePage === 'gangs') renderGangs();
    else if (activePage === 'members') renderMembers();
    else if (activePage === 'taxes') renderTaxes();
    else if (activePage === 'logs') renderLogs();
    else if (activePage === 'settings') renderSettings();
}

function getTotals() {
    const gangs = Array.isArray(state.gangs) ? state.gangs : [];
    return gangs.reduce((acc, g) => {
        acc.gangs++;
        acc.total += Number(g.totalMembers || 0);
        acc.online += Number(g.onlineMembers || 0);
        acc.leaders += Number(g.leaders || 0);
        return acc;
    }, { gangs: 0, total: 0, online: 0, leaders: 0 });
}

function renderDashboard() {
    const totals = getTotals();
    const gang = selectedGang();
    setTitle('Dashboard', isSyndicate() ? 'Control general pentru mafiile active.' : 'Statusul mafiei tale.');

    view.innerHTML = `
        <div class="hero-card">
            <div>
                <span class="eyebrow">DRIFTZONE CONTROL</span>
                <h3>${isSyndicate() ? 'Syndicate Management' : esc(gang && gang.name || 'Gang Panel')}</h3>
                <p>Administrare rapida pentru mafiile de pe server, membri, grade, status online si taxe.</p>
            </div>
            <button class="primary-btn" onclick="goPage('gangs')">Open Gangs</button>
        </div>
        <div class="metric-grid">
            <div class="metric"><span>Mafii</span><b>${num(totals.gangs)}</b><p>active</p></div>
            <div class="metric"><span>Membri</span><b>${num(totals.total)}</b><p>total</p></div>
            <div class="metric"><span>Online</span><b>${num(totals.online)}</b><p>in server</p></div>
            <div class="metric"><span>Lideri</span><b>${num(totals.leaders)}</b><p>setati</p></div>
        </div>
        <div class="split-grid">
            <section class="glass-card">
                <div class="card-head"><b>Mafie selectata</b><span>${gang ? esc(gang.shortcut || '') : '-'}</span></div>
                ${gang ? renderGangMini(gang) : '<div class="empty-row">Nu ai mafie selectata.</div>'}
            </section>
            <section class="glass-card">
                <div class="card-head"><b>Actiuni rapide</b><span>Panel</span></div>
                <div class="quick-actions">
                    <button onclick="goPage('members')">Members</button>
                    <button onclick="goPage('taxes')">Taxes</button>
                    ${isSyndicate() ? '<button onclick="openCreateGang()">Create Mafia</button><button onclick="goPage(\'settings\')">Edit Mafia</button>' : ''}
                </div>
            </section>
        </div>
    `;
}

function renderGangMini(g) {
    return `
        <article class="mini-gang" style="--gang:${color(g)}">
            <div class="gang-badge">${esc(g.shortcut || 'G')}</div>
            <div>
                <h4>${esc(g.name || 'Gang')}</h4>
                <p>${esc(g.type || g.gang_type || 'Mafie Neoficiala')} • ID ${Number(g.id || 0)}</p>
                <div class="mini-stats"><span>${Number(g.totalMembers || 0)} membri</span><span>${Number(g.onlineMembers || 0)} online</span></div>
            </div>
        </article>
    `;
}

function renderGangs() {
    setTitle('Gangs', isSyndicate() ? 'Creare si administrare mafii.' : 'Mafia ta si statisticile principale.');
    const gangs = Array.isArray(state.gangs) ? state.gangs : [];
    if (gangs.length <= 0) {
        view.innerHTML = `<div class="empty-card">Nu exista mafii disponibile.</div>`;
        return;
    }

    view.innerHTML = `<div class="gang-grid">${gangs.map(g => `
        <article class="gang-card ${Number(selectedGangId) === Number(g.id) ? 'selected' : ''}" onclick="selectGang(${Number(g.id)}, 'members')" style="--gang:${color(g)}">
            <div class="gang-card-top">
                <div class="gang-badge">${esc(g.shortcut || 'G')}</div>
                <div>
                    <h3>${esc(g.name)}</h3>
                    <p>${esc(g.type || 'Mafie Neoficiala')} • ID ${Number(g.id)}</p>
                </div>
            </div>
            <div class="stats-row">
                <div><b>${Number(g.totalMembers || 0)}</b><span>Total</span></div>
                <div><b>${Number(g.onlineMembers || 0)}</b><span>Online</span></div>
                <div><b>${Number(g.coleaders || 0)}</b><span>Co-Lideri</span></div>
            </div>
            <div class="location-row"><span>Garage</span><b>${coordLabel(g.garage)}</b></div>
            <div class="gang-line"></div>
        </article>
    `).join('')}</div>`;
}

function coordLabel(v) {
    if (!v || v.x === null || typeof v.x === 'undefined') return 'unset';
    return `${Number(v.x).toFixed(1)}, ${Number(v.y).toFixed(1)}, ${Number(v.z).toFixed(1)}`;
}

function renderMembers() {
    const gang = selectedGang();
    if (!gang) {
        setTitle('Members', 'Selecteaza o mafie.');
        view.innerHTML = `<div class="empty-card">Nu exista mafie selectata.</div>`;
        return;
    }
    setTitle('Members', `${gang.name || ''} • membri si grade`);
    const members = selectedMembers();
    const addBox = canManageMembers() ? `
        <section class="glass-card compact">
            <div class="card-head"><b>Adauga membru</b><span>UID + grad</span></div>
            <div class="inline-form">
                <input id="addUid" type="number" placeholder="UID jucator">
                <select id="addRole">
                    <option>Membru</option>
                    ${(myRole() === 'Lider' || isSyndicate()) ? '<option>Co-Lider</option>' : ''}
                    ${isSyndicate() ? '<option>Lider</option>' : ''}
                </select>
                <button class="primary-btn" onclick="addMember()">Adauga</button>
            </div>
        </section>` : '';

    view.innerHTML = `
        ${addBox}
        <section class="glass-card">
            <div class="card-head"><b>Lista membri</b><span>${members.length} membri</span></div>
            <div class="member-list">${members.map(m => renderMemberRow(m)).join('') || '<div class="empty-row">Nu sunt membri.</div>'}</div>
        </section>
    `;
}

function renderMemberRow(m) {
    const online = m.online === true;
    const role = esc(m.role || 'Membru');
    const uidText = isSyndicate() ? `<span class="uid">UID ${Number(m.uid || 0)} ${m.source ? ' • ID ' + Number(m.source) : ''}</span>` : '';
    const canKick = canManageMembers() && !(m.role === 'Lider' && !isSyndicate()) && Number(m.uid) !== Number(state.self && state.self.uid);
    const canRole = canChangeRole() && Number(m.uid) !== Number(state.self && state.self.uid);

    return `
        <div class="member-row">
            <div class="member-main">
                <div class="avatar ${online ? 'online' : ''}">${esc(String(m.username || '?').charAt(0).toUpperCase())}</div>
                <div><b>${esc(m.username || 'Membru')}</b>${uidText}<span class="uid">${online ? 'Conectat acum' : 'Offline'}</span></div>
            </div>
            <div class="role-pill">${role}</div>
            <div class="status ${online ? 'on' : 'off'}">${online ? 'Online' : 'Offline'}</div>
            <div class="row-actions">
                ${canRole ? `<select onchange="changeRole(${Number(m.uid)}, this.value)"><option>${role}</option><option>Membru</option><option>Co-Lider</option>${isSyndicate() ? '<option>Lider</option>' : ''}</select>` : ''}
                ${canKick ? `<button class="danger-soft" onclick="kickMember(${Number(m.uid)})">Kick</button>` : ''}
            </div>
        </div>`;
}

function renderTaxes() {
    setTitle('Taxes', 'Zona pregatita pentru taxe si contributii.');
    view.innerHTML = `
        <div class="metric-grid three">
            <div class="metric"><span>Acces membru</span><b>Activ</b><p>Membrii simpli vad categoria taxe.</p></div>
            <div class="metric"><span>Status</span><b>Ready</b><p>SQL gang_taxes este inclus.</p></div>
            <div class="metric"><span>Validare</span><b>Server</b><p>Actiunile sunt pregatite pentru extindere.</p></div>
        </div>
        <section class="glass-card"><div class="empty-row">Urmatorul pas: sistem complet de taxe, suma datorata, platit/neplatit si istoric.</div></section>`;
}

function renderLogs() {
    if (!isSyndicate()) return renderDashboard();
    const gang = selectedGang();
    const logs = selectedLogs();
    setTitle('Logs', gang ? `${gang.name} • ultimele actiuni` : 'Logs');
    view.innerHTML = `
        <section class="glass-card">
            <div class="card-head"><b>Loguri</b><span>${logs.length} actiuni</span></div>
            <div class="logs-list">${logs.map(l => `
                <div class="log-row"><div><b>${esc(l.action)}</b><span>Actor UID ${Number(l.actor_uid || 0)} • Target UID ${Number(l.target_uid || 0)}</span></div><em>${esc(l.created_at || '')}</em></div>
            `).join('') || '<div class="empty-row">Nu exista loguri.</div>'}</div>
        </section>`;
}

function renderSettings() {
    if (!isSyndicate()) return renderDashboard();
    const gang = selectedGang();
    if (!gang) {
        setTitle('Settings', 'Selecteaza o mafie.');
        view.innerHTML = `<div class="empty-card">Selecteaza o mafie pentru editare.</div>`;
        return;
    }
    setTitle('Settings', `${gang.name || ''} • editare completa`);
    view.innerHTML = `
        <section class="glass-card">
            <div class="card-head"><b>Edit Mafia</b><span>ID ${Number(gang.id || 0)}</span></div>
            ${gangForm('edit', gang)}
            <div class="buttons-row">
                <button class="primary-btn" onclick="saveGangEdit(${Number(gang.id)})">Save Changes</button>
                <button class="danger-soft" onclick="deleteGang(${Number(gang.id)})">Disable Mafia</button>
            </div>
        </section>`;
}

function gangForm(mode, gang = {}) {
    const prefix = mode === 'edit' ? 'edit' : 'new';
    const type = gang.gang_type || gang.type || gangTypes()[0];
    return `
        <div class="form-grid">
            <label>Tip<select id="${prefix}Type">${gangTypes().map(t => `<option ${t === type ? 'selected' : ''}>${esc(t)}</option>`).join('')}</select></label>
            <label>Nume<input id="${prefix}Name" value="${esc(gang.name || '')}" placeholder="Los Santos Mafia"></label>
            <label>Shortcut<input id="${prefix}Shortcut" value="${esc(gang.shortcut || '')}" placeholder="LSM"></label>
            <label>Culoare HEX<input id="${prefix}Color" value="${esc(gang.color || '#04c7f7')}" placeholder="#04c7f7"></label>
            <label>UID Lider<input id="${prefix}Leader" type="number" value="${Number(gang.leader_uid || 0) || ''}" placeholder="UID"></label>
            <label>Garage X<input id="${prefix}GarageX" value="${esc(gang.garage_x ?? gang.garage?.x ?? '')}" placeholder="optional"></label>
            <label>Garage Y<input id="${prefix}GarageY" value="${esc(gang.garage_y ?? gang.garage?.y ?? '')}" placeholder="optional"></label>
            <label>Garage Z<input id="${prefix}GarageZ" value="${esc(gang.garage_z ?? gang.garage?.z ?? '')}" placeholder="optional"></label>
            <label>Storage X<input id="${prefix}StorageX" value="${esc(gang.storage_x ?? gang.storage?.x ?? '')}" placeholder="optional"></label>
            <label>Storage Y<input id="${prefix}StorageY" value="${esc(gang.storage_y ?? gang.storage?.y ?? '')}" placeholder="optional"></label>
            <label>Storage Z<input id="${prefix}StorageZ" value="${esc(gang.storage_z ?? gang.storage?.z ?? '')}" placeholder="optional"></label>
        </div>
        <div class="buttons-row">
            <button class="ghost-btn" onclick="fillCoords('${prefix}', 'garage')">Use my coords for garage</button>
            <button class="ghost-btn" onclick="fillCoords('${prefix}', 'storage')">Use my coords for storage</button>
        </div>`;
}

function readGangForm(prefix) {
    const value = id => document.getElementById(prefix + id)?.value || '';
    return {
        gang_type: value('Type'),
        name: value('Name'),
        shortcut: value('Shortcut'),
        color: value('Color'),
        leader_uid: Number(value('Leader') || 0),
        garage_x: value('GarageX'), garage_y: value('GarageY'), garage_z: value('GarageZ'),
        storage_x: value('StorageX'), storage_y: value('StorageY'), storage_z: value('StorageZ')
    };
}

function fillCoords(prefix, target) {
    nui('getCoords').then(res => {
        if (!res || res.ok !== true) return;
        const name = target === 'storage' ? 'Storage' : 'Garage';
        ['X','Y','Z'].forEach(k => {
            const el = document.getElementById(prefix + name + k);
            if (el) el.value = Number(res[k.toLowerCase()] || 0).toFixed(3);
        });
    });
}

function openCreateGang() {
    modalTitle.textContent = 'Create Mafia';
    modalBody.innerHTML = `${gangForm('new')}<button class="primary-btn full" onclick="createGang()">Create Mafia</button>`;
    modal.classList.remove('hidden');
}

function closeModal() { modal.classList.add('hidden'); modalBody.innerHTML = ''; }
function createGang() { nui('createGang', readGangForm('new')); closeModal(); }
function saveGangEdit(gangId) { nui('updateGang', { ...readGangForm('edit'), gangId }); }
function deleteGang(gangId) { if (confirm('Dezactivezi mafia selectata?')) nui('deleteGang', { gangId }); }
function addMember() {
    const uid = Number(document.getElementById('addUid')?.value || 0);
    const role = document.getElementById('addRole')?.value || 'Membru';
    nui('addMember', { gangId: selectedGangId || myGangId(), uid, role });
}
function kickMember(uid) { if (confirm('Scoti membrul din mafie?')) nui('kickMember', { gangId: selectedGangId || myGangId(), uid }); }
function changeRole(uid, role) { nui('changeRole', { gangId: selectedGangId || myGangId(), uid, role }); }

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') open(data.data || {});
    if (data.action === 'close') closeLocal();
    if (data.action === 'update') mergeUpdate(data.data || {});
    if (data.action === 'focus') focusEnabled = data.focus === true;
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closePanel();
    if (event.code === 'Backquote' || event.key === '`') nui('toggleFocus');
});

setTimeout(() => nui('ready'), 80);
