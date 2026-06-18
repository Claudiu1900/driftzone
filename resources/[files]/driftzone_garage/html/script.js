'use strict';

const root = document.getElementById('garageRoot');
const garagePanel = document.getElementById('garagePanel');
const adminPanel = document.getElementById('adminPanel');

const vehiclesGrid = document.getElementById('vehiclesGrid');
const searchInput = document.getElementById('searchInput');
const vehicleCount = document.getElementById('vehicleCount');
const bottomBar = document.getElementById('bottomBar');
const selectedName = document.getElementById('selectedName');
const selectedMeta = document.getElementById('selectedMeta');
const actionButton = document.getElementById('actionButton');
const tabsRow = document.getElementById('tabsRow');
const ownedTab = document.getElementById('ownedTab');
const vipTab = document.getElementById('vipTab');
const garageTitle = document.getElementById('garageTitle');
const garageIdLabel = document.getElementById('garageIdLabel');

let vehicles = [];
let vehiclesById = new Map();
let hasVip = false;
let activeTab = 'owned';
let selectedVehicleId = null;
let currentGarage = null;
let actionLockedUntil = 0;
let pendingVehicleActions = new Set();
let renderTimer = null;

let garages = [];
let selectedGarage = null;
let editorSpots = [];

function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    })
    .then(r => r.json().catch(() => ({})))
    .catch(() => ({}));
}

function esc(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function num(value, digits = 2) {
    const n = Number(value || 0);
    return Number.isFinite(n) ? n.toFixed(digits) : '0.00';
}

function showRoot() { root.classList.remove('hidden'); }
function hideRoot() { root.classList.add('hidden'); }
function showGaragePanel() { showRoot(); garagePanel.classList.remove('hidden'); adminPanel.classList.add('hidden'); }
function showAdminPanel() { showRoot(); adminPanel.classList.remove('hidden'); garagePanel.classList.add('hidden'); }

function closeGarage() {
    root.classList.add('hidden');
    garagePanel.classList.add('hidden');
    adminPanel.classList.add('hidden');
    bottomBar.classList.add('hidden');
    selectedVehicleId = null;
    selectedGarage = null;
    nui('close');
}

function normalizeOpenData(data) {
    data = data || {};
    return {
        vehicles: Array.isArray(data.vehicles) ? data.vehicles : [],
        hasVip: data.hasVip === true,
        garage: data.garage || null
    };
}

function prepareVehicles(list) {
    vehicles = Array.isArray(list) ? list : [];
    vehiclesById = new Map();

    for (const veh of vehicles) {
        const id = Number(veh.id || 0);
        veh._id = id;
        veh._vip = veh.vip === true;
        veh._spawned = veh.spawned === true;
        veh._name = String(veh.name || 'Vehicle');
        veh._model = String(veh.model || 'model');
        veh._plate = String(veh.plate || 'DRIFT');
        veh._image = String(veh.image || '').trim();
        veh._search = `${veh._name} ${veh._model} ${veh._plate}`.toLowerCase();
        if (id > 0) vehiclesById.set(id, veh);
    }
}

function openGarage(data) {
    const payload = normalizeOpenData(data);
    currentGarage = payload.garage || {};
    prepareVehicles(payload.vehicles);
    hasVip = payload.hasVip;

    activeTab = 'owned';
    selectedVehicleId = null;
    pendingVehicleActions.clear();

    garageTitle.textContent = currentGarage.name || 'Garage';
    garageIdLabel.textContent = `#${Number(currentGarage.id || 0)}`;

    showGaragePanel();
    bottomBar.classList.add('hidden');
    searchInput.value = '';
    updateTabs();
    renderVehicles();
}

function updateGarage(data) {
    const payload = normalizeOpenData(data);
    if (payload.garage) currentGarage = payload.garage;

    prepareVehicles(payload.vehicles);
    hasVip = payload.hasVip;
    updateTabs();

    if (!vehiclesById.has(Number(selectedVehicleId || 0))) {
        selectedVehicleId = null;
        bottomBar.classList.add('hidden');
    }

    renderVehicles();
}

function updateTabs() {
    if (!hasVip) {
        tabsRow.classList.add('hidden');
        activeTab = 'owned';
        return;
    }

    tabsRow.classList.remove('hidden');
    ownedTab.classList.toggle('active', activeTab === 'owned');
    vipTab.classList.toggle('active', activeTab === 'vip');
}

function selectTab(tab) {
    if (tab === 'vip' && !hasVip) return;

    activeTab = tab === 'vip' ? 'vip' : 'owned';
    selectedVehicleId = null;
    bottomBar.classList.add('hidden');
    updateTabs();
    renderVehicles();
}

function filteredVehicles() {
    const q = String(searchInput.value || '').trim().toLowerCase();
    const wantVip = activeTab === 'vip';

    return vehicles.filter(v => {
        if (wantVip && !v._vip) return false;
        if (!wantVip && v._vip) return false;
        if (q && !v._search.includes(q)) return false;
        return true;
    });
}

function queueRender() {
    clearTimeout(renderTimer);
    renderTimer = setTimeout(renderVehicles, 80);
}

function vehicleHtml(v) {
    const selected = Number(selectedVehicleId || 0) === v._id;
    const image = v._image
        ? `<img src="${esc(v._image)}" loading="lazy" decoding="async">`
        : `<div class="fallback-car"><img src="assets/car.svg"></div>`;

    const status = v._spawned ? '<span class="pill spawned">SPAWNED</span>' : '<span class="pill stored">STORED</span>';
    const vip = v._vip ? '<span class="pill vip">VIP</span>' : '';

    return `
        <article class="vehicle-card ${selected ? 'selected' : ''}" onclick="selectVehicle(${v._id})">
            <div class="vehicle-image">${image}</div>
            <div class="vehicle-body">
                <div class="vehicle-title">
                    <b>${esc(v._name)}</b>
                    <span>${esc(v._model)}</span>
                </div>
                <div class="vehicle-meta">
                    <span>${esc(v._plate)}</span>
                    <div>${status}${vip}</div>
                </div>
            </div>
        </article>
    `;
}

function renderVehicles() {
    const list = filteredVehicles();
    vehicleCount.textContent = String(list.length);

    if (!list.length) {
        vehiclesGrid.innerHTML = `<div class="empty">Nu ai vehicule in categoria asta.</div>`;
        return;
    }

    vehiclesGrid.innerHTML = list.map(vehicleHtml).join('');
}

function selectVehicle(id) {
    const v = vehiclesById.get(Number(id || 0));
    if (!v) return;

    selectedVehicleId = v._id;
    selectedName.textContent = v._name;
    selectedMeta.textContent = `${v._model} • ${v._plate}`;
    actionButton.textContent = v._spawned ? 'Despawn' : 'Spawn';
    actionButton.className = v._spawned ? 'danger' : 'primary';
    bottomBar.classList.remove('hidden');
    renderVehicles();
}

function runSelectedAction() {
    const v = vehiclesById.get(Number(selectedVehicleId || 0));
    if (!v) return;

    const now = Date.now();
    if (now < actionLockedUntil) return;
    actionLockedUntil = now + 900;

    pendingVehicleActions.add(v._id);

    if (v._spawned) {
        nui('despawn', { id: v._id, garageId: Number(currentGarage?.id || 0) });
    } else {
        nui('spawn', { id: v._id, garageId: Number(currentGarage?.id || 0) });
    }
}

function normalizeGarage(g = {}) {
    return {
        id: Number(g.id || 0),
        name: String(g.name || ''),
        coords: g.coords || { x: 0, y: 0, z: 0 },
        radius: Number(g.radius || 4),
        visible_radius: g.visible_radius !== false,
        parking_spots: Array.isArray(g.parking_spots) ? g.parking_spots : []
    };
}

function openAdmin(data = {}) {
    garages = Array.isArray(data.garages) ? data.garages.map(normalizeGarage) : [];
    showAdminPanel();
    renderGarageList();

    if (data.mode === 'add' || garages.length === 0) {
        newGarage();
    } else {
        loadGarage(garages[0].id);
    }
}

function renderGarageList() {
    const box = document.getElementById('adminGarageList');

    if (!garages.length) {
        box.innerHTML = `<div class="empty small">Nu exista garaje.</div>`;
        return;
    }

    box.innerHTML = garages.map(g => `
        <button class="garage-row ${selectedGarage && selectedGarage.id === g.id ? 'active' : ''}" onclick="loadGarage(${g.id})">
            <b>#${g.id} ${esc(g.name)}</b>
            <span>${Number(g.parking_spots?.length || 0)} locuri • r=${num(g.radius, 1)}</span>
        </button>
    `).join('');
}

function newGarage() {
    selectedGarage = null;
    editorSpots = [];

    document.getElementById('gId').value = '';
    document.getElementById('gName').value = '';
    document.getElementById('gRadius').value = '4';
    document.getElementById('gVisible').value = '1';
    document.getElementById('gX').value = '';
    document.getElementById('gY').value = '';
    document.getElementById('gZ').value = '';
    document.getElementById('adminStatus').textContent = 'Garage nou. Pune coordonatele si minim un loc de parcare.';
    renderSpots();
    renderGarageList();
}

function loadGarage(id) {
    selectedGarage = garages.find(g => Number(g.id) === Number(id)) || null;
    if (!selectedGarage) return;

    editorSpots = (selectedGarage.parking_spots || []).map(s => ({
        x: Number(s.x || 0),
        y: Number(s.y || 0),
        z: Number(s.z || 0),
        h: Number(s.h || s.w || 0)
    }));

    const c = selectedGarage.coords || {};
    document.getElementById('gId').value = String(selectedGarage.id || '');
    document.getElementById('gName').value = selectedGarage.name || '';
    document.getElementById('gRadius').value = String(selectedGarage.radius || 4);
    document.getElementById('gVisible').value = selectedGarage.visible_radius === false ? '0' : '1';
    document.getElementById('gX').value = num(c.x, 6);
    document.getElementById('gY').value = num(c.y, 6);
    document.getElementById('gZ').value = num(c.z, 6);

    document.getElementById('adminStatus').textContent = `Editezi garajul #${selectedGarage.id}.`;
    renderSpots();
    renderGarageList();
}

function renderSpots() {
    const box = document.getElementById('spotsList');

    if (!editorSpots.length) {
        box.innerHTML = `<div class="empty small">Nu exista locuri. Apasa + Loc din pozitia mea.</div>`;
        return;
    }

    box.innerHTML = editorSpots.map((s, i) => `
        <div class="spot-row">
            <span>#${i + 1}</span>
            <input type="number" step="0.000001" value="${num(s.x, 6)}" onchange="spotChange(${i}, 'x', this.value)">
            <input type="number" step="0.000001" value="${num(s.y, 6)}" onchange="spotChange(${i}, 'y', this.value)">
            <input type="number" step="0.000001" value="${num(s.z, 6)}" onchange="spotChange(${i}, 'z', this.value)">
            <input type="number" step="0.01" value="${num(s.h, 2)}" onchange="spotChange(${i}, 'h', this.value)">
            <button class="danger mini" onclick="removeSpot(${i})">×</button>
        </div>
    `).join('');
}

function spotChange(i, key, value) {
    if (!editorSpots[i]) return;
    editorSpots[i][key] = Number(value || 0);
}

function removeSpot(i) {
    editorSpots.splice(i, 1);
    renderSpots();
}

async function useCurrentPositionForGarage() {
    const res = await nui('getPlayerPosition');
    if (!res || !res.ok) return;

    document.getElementById('gX').value = num(res.x, 6);
    document.getElementById('gY').value = num(res.y, 6);
    document.getElementById('gZ').value = num(res.z, 6);
}

async function addSpotFromPosition() {
    const res = await nui('getPlayerPosition');
    if (!res || !res.ok) return;

    editorSpots.push({
        x: Number(res.x || 0),
        y: Number(res.y || 0),
        z: Number(res.z || 0),
        h: Number(res.h || 0)
    });

    renderSpots();
}

function collectGaragePayload() {
    return {
        id: Number(document.getElementById('gId').value || 0),
        name: document.getElementById('gName').value.trim(),
        radius: Number(document.getElementById('gRadius').value || 4),
        visible_radius: document.getElementById('gVisible').value === '1',
        coords: {
            x: Number(document.getElementById('gX').value || 0),
            y: Number(document.getElementById('gY').value || 0),
            z: Number(document.getElementById('gZ').value || 0)
        },
        parking_spots: editorSpots
    };
}

function saveGarage() {
    const payload = collectGaragePayload();

    if (!payload.name) {
        document.getElementById('adminStatus').textContent = 'Pune nume la garaj.';
        return;
    }

    if (!payload.parking_spots.length) {
        document.getElementById('adminStatus').textContent = 'Adauga minim un loc de parcare.';
        return;
    }

    document.getElementById('adminStatus').textContent = 'Se salveaza...';
    nui('adminSaveGarage', payload);
}

function deleteGarage() {
    const id = Number(document.getElementById('gId').value || 0);
    if (!id) return;
    document.getElementById('adminStatus').textContent = 'Se dezactiveaza...';
    nui('adminDeleteGarage', { id });
}

function reloadGarages() {
    document.getElementById('adminStatus').textContent = 'Se reincarca din DB...';
    nui('adminReloadGarages');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') openGarage(data);
    if (data.action === 'update') updateGarage(data);
    if (data.action === 'close') closeGarage();
    if (data.action === 'admin') openAdmin(data);
    if (data.action === 'garagesData') {
        garages = Array.isArray(data.garages) ? data.garages.map(normalizeGarage) : [];
        if (!adminPanel.classList.contains('hidden')) {
            renderGarageList();
        }
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeGarage();
});

nui('ready');
