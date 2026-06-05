'use strict';

const root = document.getElementById('root');
const selectedName = document.getElementById('selectedName');
const selectedCategory = document.getElementById('selectedCategory');
const selectedPrice = document.getElementById('selectedPrice');
const buyBtn = document.getElementById('buyBtn');
const vehiclesEl = document.getElementById('vehicles');
const listTitle = document.getElementById('listTitle');
const vehicleCount = document.getElementById('vehicleCount');

let vehicles = [];
let categories = {};
let selectedCategoryId = 'all';
let selectedVehicle = null;
let fallbackImage = 'https://i.imgur.com/8QfQZQp.png';

let dragging = false;
let lastMouseX = 0;
let dragDistance = 0;
let suppressClick = false;
let lastPreviewModel = '';
let rotateQueued = 0;
let rotatePending = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
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
    try {
        return '$' + number.toLocaleString('ro-RO');
    } catch (e) {
        return '$' + number;
    }
}

function categoryName(id) {
    return categories[String(id)] || categories[Number(id)] || 'UNKNOWN';
}

function getFilteredVehicles() {
    let list = [];

    if (selectedCategoryId === 'all') {
        list = vehicles.filter((vehicle) => Number(vehicle.category) !== 6);
    } else if (selectedCategoryId === 'vip') {
        list = vehicles.filter((vehicle) => Number(vehicle.vip || 0) === 1);
    } else {
        list = vehicles.filter((vehicle) => Number(vehicle.category) === Number(selectedCategoryId));
    }

    return list.slice().sort((a, b) => Number(a.price || 0) - Number(b.price || 0));
}

function renderCategories() {
    document.querySelectorAll('.cat').forEach((btn) => {
        btn.classList.toggle('active', String(btn.dataset.cat) === String(selectedCategoryId));
    });
}

function setActiveCard() {
    document.querySelectorAll('.vehicle-card').forEach((card) => {
        card.classList.toggle(
            'active',
            selectedVehicle && String(card.dataset.model) === String(selectedVehicle.model)
        );
    });
}

function renderVehicles() {
    const list = getFilteredVehicles();

    listTitle.textContent = selectedCategoryId === 'all'
        ? 'TOATE CATEGORIILE'
        : categoryName(selectedCategoryId);

    vehicleCount.textContent = `${list.length} vehicles`;

    vehiclesEl.innerHTML = list.map((vehicle) => {
        const priceHtml = vehicle.selling
            ? `<div class="vehicle-price">${money(vehicle.price)}</div>`
            : `<div class="not-selling">NOT FOR SALE</div>`;

        const img = vehicle.image && String(vehicle.image).length > 5
            ? String(vehicle.image)
            : fallbackImage;

        const vipClass = Number(vehicle.vip || 0) === 1 ? 'vip-card' : '';
        const vipBadge = Number(vehicle.vip || 0) === 1 ? '<div class="vip-badge">VIP</div>' : '';

        return `
            <div class="vehicle-card ${vipClass}" data-model="${escapeHtml(vehicle.model)}" onclick="selectVehicle('${jsString(vehicle.model)}')">
                ${vipBadge}
                <img src="${escapeHtml(img)}" loading="lazy" onerror="this.src='${escapeHtml(fallbackImage)}'">
                <div class="vehicle-info">
                    <div class="vehicle-name">${escapeHtml(vehicle.name)}</div>
                    ${priceHtml}
                </div>
            </div>
        `;
    }).join('');

    if (!selectedVehicle && list.length > 0) {
        setSelectedVehicle(list[0].model, false);
    } else {
        setActiveCard();
    }
}

function renderSelected() {
    if (!selectedVehicle) {
        selectedName.textContent = 'No vehicle';
        selectedCategory.textContent = '-';
        selectedPrice.textContent = '-';
        buyBtn.classList.add('locked');
        buyBtn.textContent = 'NOT AVAILABLE';
        return;
    }

    selectedName.textContent = selectedVehicle.name || selectedVehicle.model;
    selectedCategory.textContent = categoryName(selectedVehicle.category);

    if (selectedVehicle.selling) {
        selectedPrice.textContent = money(selectedVehicle.price);
        buyBtn.classList.remove('locked');
        buyBtn.textContent = 'BUY VEHICLE';
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

    if (selectedVehicle && preview) {
        requestPreview(selectedVehicle.model);
    }
}

function open(payload) {
    const data = payload || {};

    vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    categories = data.categories || {};
    fallbackImage = data.fallbackImage || fallbackImage;
    selectedCategoryId = 'all';
    selectedVehicle = null;
    lastPreviewModel = '';

    if (data.selectedModel) {
        selectedVehicle = vehicles.find((vehicle) => vehicle.model === data.selectedModel) || null;

        if (selectedVehicle && Number(selectedVehicle.category) === 6) {
            selectedCategoryId = 6;
        }
    }

    root.classList.remove('hidden');

    renderCategories();
    renderVehicles();

    if (selectedVehicle) {
        renderSelected();
        setActiveCard();
        requestPreview(selectedVehicle.model);
    } else {
        const list = getFilteredVehicles();
        if (list.length > 0) {
            setSelectedVehicle(list[0].model, true);
        } else {
            renderSelected();
        }
    }
}

function close() {
    root.classList.add('hidden');
    vehicles = [];
    selectedVehicle = null;
    selectedCategoryId = 'all';
    lastPreviewModel = '';
    vehiclesEl.innerHTML = '';
}

function selectCategory(id) {
    selectedCategoryId = id;
    selectedVehicle = null;
    lastPreviewModel = '';

    renderCategories();
    renderVehicles();
    renderSelected();

    const list = getFilteredVehicles();
    if (list.length > 0) {
        setSelectedVehicle(list[0].model, true);
    }
}

function selectVehicle(model) {
    if (suppressClick) return;
    setSelectedVehicle(model, true);
}

function buySelected() {
    if (!selectedVehicle) return;
    if (!selectedVehicle.selling) return;

    nui('buy', { model: selectedVehicle.model });
}

function testDriveSelected() {
    if (!selectedVehicle) return;
    nui('testDrive', { model: selectedVehicle.model });
}

function isUiPanel(target) {
    return !!target.closest('.left-info, .right-categories, .bottom-list, button');
}

function flushRotate() {
    if (!rotatePending) return;

    const delta = rotateQueued;
    rotateQueued = 0;
    rotatePending = false;

    if (delta !== 0) {
        nui('rotatePreview', { delta });
    }
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

    if (dragDistance > 8) {
        suppressClick = true;
    }
});

document.addEventListener('mouseup', () => {
    if (!dragging) return;

    dragging = false;
    flushRotate();

    setTimeout(() => {
        suppressClick = false;
    }, 80);
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        nui('close');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        open(data.data || {});
    }

    if (data.action === 'close') {
        close();
    }
});

window.driftShowroom = {
    open,
    close,
    selectCategory,
    selectVehicle,
    buySelected,
    testDriveSelected
};

setTimeout(() => {
    nui('ready');
}, 100);
