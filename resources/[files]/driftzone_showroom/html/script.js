'use strict';

const root = document.getElementById('root');
const selectedName = document.getElementById('selectedName');
const selectedCategory = document.getElementById('selectedCategory');
const selectedPrice = document.getElementById('selectedPrice');
const walletCash = document.getElementById('walletCash');
const walletCoins = document.getElementById('walletCoins');
const buyBtn = document.getElementById('buyBtn');
const vehiclesEl = document.getElementById('vehicles');
const listTitle = document.getElementById('listTitle');
const vehicleCount = document.getElementById('vehicleCount');
const subcategoriesEl = document.getElementById('subcategories');

let vehicles = [];
let categories = {};
let groups = {};
let activeMode = 'DRIFT';
let activeSub = 'all';
let selectedVehicle = null;
let fallbackImage = 'https://i.imgur.com/8QfQZQp.png';
let cash = 0;
let dzcoins = 0;

let dragging = false;
let lastMouseX = 0;
let dragDistance = 0;
let suppressClick = false;
let lastPreviewModel = '';
let rotateQueued = 0;
let rotatePending = false;

const defaultGroups = {
    DRIFT: [
        { id: 'all', label: 'ALL' },
        { id: 'starter', label: 'Starter' },
        { id: 'drifter', label: 'Drifter' },
        { id: 'jdm_legends', label: 'JDM Legends' }
    ],
    HS: [
        { id: 'all', label: 'ALL' },
        { id: 'starter', label: 'Starter' },
        { id: 'racer', label: 'Racer' },
        { id: 'legend', label: 'Legend' }
    ],
    PREMIUM: [
        { id: 'all', label: 'ALL' },
        { id: 'drift', label: 'Drift' },
        { id: 'hs', label: 'HS' }
    ],
    CUSTOM: [
        { id: 'all', label: 'ALL' }
    ]
};

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

function jsString(value) {
    return String(value || '').replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

function money(value) {
    const number = Number(value || 0);
    try { return '$' + number.toLocaleString('ro-RO'); } catch (e) { return '$' + number; }
}

function coins(value) {
    const number = Number(value || 0);
    try { return number.toLocaleString('ro-RO') + ' DZC'; } catch (e) { return number + ' DZC'; }
}

function normalizeMode(value) {
    const mode = String(value || 'DRIFT').toUpperCase().replace(/\s+/g, '');
    return ['DRIFT', 'HS', 'PREMIUM', 'CUSTOM'].includes(mode) ? mode : 'DRIFT';
}

function normalizeSub(value) {
    return String(value || 'all').toLowerCase().replace(/\s+/g, '_').replace(/-/g, '_');
}

function priceText(vehicle) {
    if (Number(vehicle?.dzcoins_price || 0) > 0) return coins(vehicle.dzcoins_price);
    return money(vehicle?.price || 0);
}

function vehicleSection(vehicle) {
    return normalizeMode(vehicle.section || 'DRIFT');
}

function vehicleSub(vehicle) {
    return normalizeSub(vehicle.subcategory || 'starter');
}

function categoryName(vehicle) {
    if (!vehicle) return 'UNKNOWN';
    const mode = vehicleSection(vehicle);
    const sub = vehicleSub(vehicle);
    const defs = (groups[mode] || defaultGroups[mode] || []);
    const found = defs.find((entry) => entry.id === sub);
    return `${mode} • ${found ? found.label : sub.replace(/_/g, ' ')}`;
}

function getFilteredVehicles() {
    const mode = normalizeMode(activeMode);
    const sub = normalizeSub(activeSub);
    let list = vehicles.filter((vehicle) => vehicleSection(vehicle) === mode);
    if (sub !== 'all') {
        list = list.filter((vehicle) => vehicleSub(vehicle) === sub);
    }
    return list.slice().sort((a, b) => {
        const ap = Number(a.dzcoins_price || 0) > 0 ? Number(a.dzcoins_price) : Number(a.price || 0);
        const bp = Number(b.dzcoins_price || 0) > 0 ? Number(b.dzcoins_price) : Number(b.price || 0);
        return ap - bp;
    });
}

function renderModes() {
    document.querySelectorAll('.mode-btn').forEach((btn) => {
        btn.classList.toggle('active', String(btn.dataset.mode) === String(activeMode));
    });
}

function renderSubcategories() {
    const defs = groups[activeMode] || defaultGroups[activeMode] || defaultGroups.DRIFT;
    subcategoriesEl.innerHTML = defs.map((entry) => `
        <button class="cat ${entry.id === activeSub ? 'active' : ''}" data-sub="${escapeHtml(entry.id)}" onclick="selectSubcategory('${jsString(entry.id)}')">
            ${escapeHtml(entry.label)}
        </button>
    `).join('');
}

function setActiveCard() {
    document.querySelectorAll('.vehicle-card').forEach((card) => {
        card.classList.toggle('active', selectedVehicle && String(card.dataset.model) === String(selectedVehicle.model));
    });
}

function renderVehicles() {
    const list = getFilteredVehicles();
    const defs = groups[activeMode] || defaultGroups[activeMode] || [];
    const subLabel = (defs.find((entry) => entry.id === activeSub) || { label: 'ALL' }).label;
    listTitle.textContent = `${activeMode} • ${subLabel}`.toUpperCase();
    vehicleCount.textContent = `${list.length} vehicles`;

    vehiclesEl.innerHTML = list.map((vehicle) => {
        const priceHtml = vehicle.selling ? `<div class="vehicle-price">${priceText(vehicle)}</div>` : `<div class="not-selling">NOT FOR SALE</div>`;
        const img = vehicle.image && String(vehicle.image).length > 5 ? String(vehicle.image) : fallbackImage;
        const vipBadge = Number(vehicle.vip || 0) === 1 ? '<div class="vip-badge">VIP</div>' : '';
        const coinBadge = Number(vehicle.dzcoins_price || 0) > 0 ? '<div class="coin-badge">DZC</div>' : '';
        return `
            <div class="vehicle-card" data-model="${escapeHtml(vehicle.model)}" onclick="selectVehicle('${jsString(vehicle.model)}')">
                ${vipBadge}${coinBadge}
                <img src="${escapeHtml(img)}" loading="lazy" onerror="this.src='${escapeHtml(fallbackImage)}'">
                <div class="vehicle-info">
                    <div class="vehicle-name">${escapeHtml(vehicle.name)}</div>
                    ${priceHtml}
                </div>
            </div>
        `;
    }).join('');

    if (!selectedVehicle && list.length > 0) setSelectedVehicle(list[0].model, false);
    else setActiveCard();
}

function renderSelected() {
    walletCash.textContent = `Cash: ${money(cash)}`;
    walletCoins.textContent = `DZC: ${Number(dzcoins || 0).toLocaleString('ro-RO')}`;

    if (!selectedVehicle) {
        selectedName.textContent = 'No vehicle';
        selectedCategory.textContent = '-';
        selectedPrice.textContent = '-';
        buyBtn.classList.add('locked');
        buyBtn.textContent = 'NOT AVAILABLE';
        return;
    }

    selectedName.textContent = selectedVehicle.name || selectedVehicle.model;
    selectedCategory.textContent = categoryName(selectedVehicle);

    if (selectedVehicle.selling) {
        selectedPrice.textContent = priceText(selectedVehicle);
        buyBtn.classList.remove('locked');
        buyBtn.textContent = Number(selectedVehicle.dzcoins_price || 0) > 0 ? 'BUY WITH DZC' : 'BUY VEHICLE';
    } else {
        selectedPrice.textContent = 'NOT FOR SALE';
        buyBtn.classList.add('locked');
        buyBtn.textContent = 'NOT AVAILABLE';
    }
}

function requestPreview(model) {
    model = String(model || '').toLowerCase().replace(/\s+/g, '');
    if (!model || model === lastPreviewModel) return;
    lastPreviewModel = model;
    nui('preview', { model });
}

function setSelectedVehicle(model, preview = true) {
    model = String(model || '').toLowerCase().replace(/\s+/g, '');
    selectedVehicle = vehicles.find((vehicle) => String(vehicle.model) === model) || null;
    renderSelected();
    setActiveCard();
    if (selectedVehicle && preview) requestPreview(selectedVehicle.model);
}

function open(payload) {
    const data = payload || {};
    vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    categories = data.categories || {};
    groups = data.groups || defaultGroups;
    fallbackImage = data.fallbackImage || fallbackImage;
    cash = Number(data.cash || 0);
    dzcoins = Number(data.dzcoins || 0);
    activeMode = 'DRIFT';
    activeSub = 'all';
    selectedVehicle = null;
    lastPreviewModel = '';

    if (data.selectedModel) {
        const wanted = vehicles.find((vehicle) => vehicle.model === data.selectedModel) || null;
        if (wanted) {
            activeMode = vehicleSection(wanted);
            activeSub = 'all';
            selectedVehicle = wanted;
        }
    }

    root.classList.remove('hidden');
    renderModes();
    renderSubcategories();
    renderVehicles();

    if (selectedVehicle) {
        renderSelected();
        setActiveCard();
        requestPreview(selectedVehicle.model);
    } else {
        const list = getFilteredVehicles();
        if (list.length > 0) setSelectedVehicle(list[0].model, true);
        else renderSelected();
    }
}

function close() {
    root.classList.add('hidden');
    vehicles = [];
    selectedVehicle = null;
    activeMode = 'DRIFT';
    activeSub = 'all';
    lastPreviewModel = '';
    vehiclesEl.innerHTML = '';
}

function selectMode(mode) {
    activeMode = normalizeMode(mode);
    activeSub = 'all';
    selectedVehicle = null;
    lastPreviewModel = '';
    renderModes();
    renderSubcategories();
    renderVehicles();
    renderSelected();
    const list = getFilteredVehicles();
    if (list.length > 0) setSelectedVehicle(list[0].model, true);
}

function selectSubcategory(id) {
    activeSub = normalizeSub(id);
    selectedVehicle = null;
    lastPreviewModel = '';
    renderSubcategories();
    renderVehicles();
    renderSelected();
    const list = getFilteredVehicles();
    if (list.length > 0) setSelectedVehicle(list[0].model, true);
}

function selectVehicle(model) {
    if (suppressClick) return;
    setSelectedVehicle(model, true);
}

function buySelected() {
    if (!selectedVehicle || !selectedVehicle.selling) return;
    nui('buy', { model: selectedVehicle.model });
}

function testDriveSelected() {
    if (!selectedVehicle) return;
    nui('testDrive', { model: selectedVehicle.model });
}

function isUiPanel(target) {
    return !!target.closest('.left-info, .right-categories, .bottom-list, .top-modes, button');
}

function flushRotate() {
    if (!rotatePending) return;
    const delta = rotateQueued;
    rotateQueued = 0;
    rotatePending = false;
    if (delta !== 0) nui('rotatePreview', { delta });
}

root.addEventListener('mousedown', (event) => {
    if (isUiPanel(event.target)) return;
    dragging = true;
    lastMouseX = event.clientX;
    dragDistance = 0;
    suppressClick = false;
});

document.addEventListener('mousemove', (event) => {
    if (!dragging) return;
    const delta = event.clientX - lastMouseX;
    lastMouseX = event.clientX;
    dragDistance += Math.abs(delta);
    if (delta !== 0) {
        rotateQueued += delta;
        if (!rotatePending) {
            rotatePending = true;
            requestAnimationFrame(flushRotate);
        }
    }
    if (dragDistance > 8) suppressClick = true;
});

document.addEventListener('mouseup', () => {
    if (!dragging) return;
    dragging = false;
    flushRotate();
    setTimeout(() => { suppressClick = false; }, 80);
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') nui('close');
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') open(data.data || {});
    if (data.action === 'close') close();
});

window.driftShowroom = { open, close, selectMode, selectSubcategory, selectVehicle, buySelected, testDriveSelected };

setTimeout(() => { nui('ready'); }, 100);
