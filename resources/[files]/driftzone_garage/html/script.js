'use strict';

const garageRoot = document.getElementById('garageRoot');
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

let vehicles = [];
let vehiclesById = new Map();
let hasVip = false;
let activeTab = 'owned';
let selectedVehicleId = null;
let lastRenderedKey = '';
let renderQueued = false;
let searchTimer = null;
let lastSelectedCard = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function normalizeOpenData(data) {
    if (Array.isArray(data)) {
        return { vehicles: data, hasVip: false };
    }

    data = data || {};

    return {
        vehicles: Array.isArray(data.vehicles) ? data.vehicles : [],
        hasVip: data.hasVip === true
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

        if (id > 0) {
            vehiclesById.set(id, veh);
        }
    }
}

function getVehicleById(id) {
    return vehiclesById.get(Number(id || 0)) || null;
}

function setVisible(state) {
    garageRoot.classList.toggle('hidden', state !== true);
}

function open(data) {
    const payload = normalizeOpenData(data);

    prepareVehicles(payload.vehicles);
    hasVip = payload.hasVip;
    activeTab = 'owned';
    selectedVehicleId = null;
    lastSelectedCard = null;
    lastRenderedKey = '';

    setVisible(true);
    bottomBar.classList.add('hidden');

    if (searchInput) searchInput.value = '';

    updateTabs();
    renderVehicles(true);

    setTimeout(() => {
        if (document.activeElement) document.activeElement.blur();
    }, 50);
}

function close(send = true) {
    setVisible(false);
    bottomBar.classList.add('hidden');
    selectedVehicleId = null;
    lastSelectedCard = null;
    lastRenderedKey = '';

    if (send) {
        nui('close');
    }
}

function closeGarage() {
    close(true);
}

function updateVehicles(data) {
    const payload = normalizeOpenData(data);

    prepareVehicles(payload.vehicles);
    hasVip = payload.hasVip;

    if (!hasVip) activeTab = 'owned';

    updateTabs();

    const selected = getVehicleById(selectedVehicleId);

    if (!selected || (activeTab === 'vip' && !selected._vip) || (activeTab === 'owned' && selected._vip)) {
        selectedVehicleId = null;
        lastSelectedCard = null;
        bottomBar.classList.add('hidden');
    } else {
        updateBottomBar(selected);
    }

    lastRenderedKey = '';
    renderVehicles(true);
}

function updateTabs() {
    if (!hasVip) {
        tabsRow.classList.add('hidden');
        vehiclesGrid.classList.add('no-tabs');
        activeTab = 'owned';
        return;
    }

    tabsRow.classList.remove('hidden');
    vehiclesGrid.classList.remove('no-tabs');
    ownedTab.classList.toggle('active', activeTab === 'owned');
    vipTab.classList.toggle('active', activeTab === 'vip');
}

function selectTab(tab) {
    if (tab === 'vip' && !hasVip) return;

    activeTab = tab === 'vip' ? 'vip' : 'owned';
    selectedVehicleId = null;
    lastSelectedCard = null;
    bottomBar.classList.add('hidden');

    updateTabs();
    lastRenderedKey = '';
    renderVehicles(true);
}

function getFilteredVehicles() {
    const search = String(searchInput.value || '').trim().toLowerCase();
    const wantVip = activeTab === 'vip';
    const output = [];

    for (const veh of vehicles) {
        if (wantVip) {
            if (!veh._vip) continue;
        } else if (veh._vip) {
            continue;
        }

        if (search && !veh._search.includes(search)) {
            continue;
        }

        output.push(veh);
    }

    return output;
}

function createVehicleHtml(veh) {
    const selected = Number(selectedVehicleId || 0) === veh._id;
    const imageHtml = veh._image
        ? `<img loading="lazy" decoding="async" src="${escapeHtml(veh._image)}" onerror="this.style.display='none'; this.parentElement.innerHTML='<div class=&quot;no-image&quot;>🚗</div>';">`
        : `<div class="no-image">🚗</div>`;

    return `
        <div class="vehicle-card ${veh._vip ? 'vip' : ''} ${selected ? 'selected' : ''}" data-id="${veh._id}">
            <div class="vehicle-image">${imageHtml}</div>
            <div class="vehicle-info">
                <div class="vehicle-name">${escapeHtml(veh._name)}</div>
                <div class="vehicle-meta">${escapeHtml(veh._model)} • Plate: ${escapeHtml(veh._plate)}</div>
                <div class="status ${veh._spawned ? '' : 'off'}">${veh._spawned ? '● Spawned' : '● Despawned'}</div>
            </div>
        </div>
    `;
}

function renderVehicles(force = false) {
    const search = String(searchInput.value || '').trim().toLowerCase();
    const renderKey = `${activeTab}|${search}|${vehicles.length}|${vehicles.map(v => `${v._id}:${v._spawned ? 1 : 0}:${v._vip ? 1 : 0}`).join(',')}`;

    if (!force && renderKey === lastRenderedKey) {
        return;
    }

    lastRenderedKey = renderKey;

    const list = getFilteredVehicles();
    vehicleCount.textContent = String(list.length);

    if (!list.length) {
        vehiclesGrid.innerHTML = `<div class="empty">${activeTab === 'vip' ? 'Nu ai niciun vehicul VIP in garaj.' : 'Nu ai niciun vehicul in garaj.'}</div>`;
        lastSelectedCard = null;
        return;
    }

    vehiclesGrid.innerHTML = list.map(createVehicleHtml).join('');
    lastSelectedCard = selectedVehicleId ? vehiclesGrid.querySelector(`.vehicle-card[data-id="${selectedVehicleId}"]`) : null;
}

function queueRender() {
    if (searchTimer) clearTimeout(searchTimer);

    searchTimer = setTimeout(() => {
        if (renderQueued) return;

        renderQueued = true;

        requestAnimationFrame(() => {
            renderQueued = false;
            lastRenderedKey = '';
            renderVehicles(true);
        });
    }, 80);
}

function updateBottomBar(veh) {
    if (!veh) {
        bottomBar.classList.add('hidden');
        return;
    }

    selectedName.textContent = veh._name;
    selectedMeta.textContent = `${veh._model} • Plate: ${veh._plate}${veh._vip ? ' • VIP' : ''}`;

    actionButton.textContent = veh._spawned ? 'Despawn' : 'Spawn';
    actionButton.classList.toggle('spawn', !veh._spawned);
    actionButton.classList.toggle('despawn', veh._spawned);

    bottomBar.classList.remove('hidden');
}

function selectVehicle(id) {
    selectedVehicleId = Number(id);
    const veh = getVehicleById(selectedVehicleId);

    if (lastSelectedCard) {
        lastSelectedCard.classList.remove('selected');
    }

    lastSelectedCard = vehiclesGrid.querySelector(`.vehicle-card[data-id="${selectedVehicleId}"]`);

    if (lastSelectedCard) {
        lastSelectedCard.classList.add('selected');
    }

    updateBottomBar(veh);
}

function runSelectedAction() {
    const veh = getVehicleById(selectedVehicleId);
    if (!veh) return;

    if (veh._spawned) {
        nui('despawn', { id: veh._id });
    } else {
        nui('spawn', { id: veh._id });
    }
}

vehiclesGrid.addEventListener('click', (event) => {
    const card = event.target.closest('.vehicle-card');
    if (!card) return;

    selectVehicle(Number(card.dataset.id || 0));
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') close(true);
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') open(data);
    if (data.action === 'update') updateVehicles(data);
    if (data.action === 'close') close(false);
    if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
});

window.driftGarage = {
    open,
    close,
    updateVehicles,
    queueRender
};

setTimeout(() => nui('ready'), 50);
