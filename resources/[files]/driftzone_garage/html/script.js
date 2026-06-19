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

function coordLine(x, y, z, h = null) {
    const parts = [num(x, 6), num(y, 6), num(z, 6)];
    if (h !== null && h !== undefined) parts.push(num(h, 2));
    return parts.join(', ');
}

function parseCoordLine(value, needsHeading = false) {
    const parts = String(value || '')
        .replace(/;/g, ',')
        .split(/[,\s]+/)
        .map(v => v.trim())
        .filter(Boolean)
        .map(Number);

    if (parts.length < 3 || parts.some(v => !Number.isFinite(v))) {
        return null;
    }

    return {
        x: parts[0],
        y: parts[1],
        z: parts[2],
        h: Number.isFinite(parts[3]) ? parts[3] : (needsHeading ? 0 : undefined)
    };
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

    showGaragePanel();
    bottomBar.classList.add('hidden');
    searchInput.value = '';
    updateTabs();
    renderVehicles();
}

function updateGarage(data) {
    const payload = normalizeOpenData(data);
    if (payload.garage) currentGarage = payload.garage;

    pendingVehicleActions.clear();
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
    if (v._spawned) {
        actionButton.textContent = 'Spawned';
        actionButton.className = 'ghost disabled';
        actionButton.disabled = true;
    } else {
        actionButton.textContent = 'Spawn';
        actionButton.className = 'primary';
        actionButton.disabled = false;
    }

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
        return;
    }

    nui('spawn', { id: v._id, garageId: Number(currentGarage?.id || 0) });
}

function normalizeGarage(g = {}) {
    return {
        id: Number(g.id || 0),
        name: String(g.name || ''),
        coords: g.coords || { x: 0, y: 0, z: 0 },
        radius: Number(g.radius || 4),
        park_radius: Number(g.park_radius || 12),
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
            <span>${Number(g.parking_spots?.length || 0)} locuri • open=${num(g.radius, 1)} • park=${num(g.park_radius, 1)}</span>
        </button>
    `).join('');
}

function newGarage() {
    selectedGarage = null;
    editorSpots = [];

    document.getElementById('gId').value = '';
    document.getElementById('gName').value = '';
    document.getElementById('gRadius').value = '4';
    document.getElementById('gParkRadius').value = '12';
    document.getElementById('gVisible').value = '1';
    document.getElementById('gCoords').value = '';
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
    document.getElementById('gParkRadius').value = String(selectedGarage.park_radius || 12);
    document.getElementById('gVisible').value = selectedGarage.visible_radius === false ? '0' : '1';
    document.getElementById('gCoords').value = coordLine(c.x, c.y, c.z);

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
        <div class="spot-row single">
            <span>#${i + 1}</span>
            <input class="spot-line" value="${coordLine(s.x, s.y, s.z, s.h)}" onchange="spotLineChange(${i}, this.value)" placeholder="x, y, z, heading">
            <button class="danger mini" onclick="removeSpot(${i})">×</button>
        </div>
    `).join('');
}

function spotLineChange(i, value) {
    if (!editorSpots[i]) return;

    const parsed = parseCoordLine(value, true);
    if (!parsed) {
        renderSpots();
        return;
    }

    editorSpots[i] = {
        x: parsed.x,
        y: parsed.y,
        z: parsed.z,
        h: parsed.h || 0
    };
}

function removeSpot(i) {
    editorSpots.splice(i, 1);
    renderSpots();
}

async function useCurrentPositionForGarage() {
    const res = await nui('getPlayerPosition');
    if (!res || !res.ok) return;

    document.getElementById('gCoords').value = coordLine(res.x, res.y, res.z);
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
    const parsedCoords = parseCoordLine(document.getElementById('gCoords').value, false);

    return {
        id: Number(document.getElementById('gId').value || 0),
        name: document.getElementById('gName').value.trim(),
        radius: Number(document.getElementById('gRadius').value || 4),
        park_radius: Number(document.getElementById('gParkRadius').value || 12),
        visible_radius: document.getElementById('gVisible').value === '1',
        coords: parsedCoords ? {
            x: parsedCoords.x,
            y: parsedCoords.y,
            z: parsedCoords.z
        } : { x: 0, y: 0, z: 0 },
        parking_spots: editorSpots
    };
}

function saveGarage() {
    const payload = collectGaragePayload();

    if (!payload.name) {
        document.getElementById('adminStatus').textContent = 'Pune nume la garaj.';
        return;
    }

    if (!parseCoordLine(document.getElementById('gCoords').value, false)) {
        document.getElementById('adminStatus').textContent = 'Coordonatele garajului trebuie sa fie: x, y, z.';
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
    if (data.action === 'spawnedSuccess') {
        pendingVehicleActions.clear();
        actionLockedUntil = Date.now() + 500;
    }

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
