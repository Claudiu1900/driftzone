'use strict';

const panel = document.getElementById('coordsPanel');
const coordsInput = document.getElementById('coordsInput');
const xInput = document.getElementById('xInput');
const yInput = document.getElementById('yInput');
const zInput = document.getElementById('zInput');
const headingInput = document.getElementById('headingInput');
const dimensionInput = document.getElementById('dimensionInput');
const statusEl = document.getElementById('status');
const addCarPanel = document.getElementById('addCarPanel');
const carModelInput = document.getElementById('carModelInput');
const carNameInput = document.getElementById('carNameInput');
const carPriceInput = document.getElementById('carPriceInput');
const carCategoryInput = document.getElementById('carCategoryInput');
const carVipInput = document.getElementById('carVipInput');
const carApearInput = document.getElementById('carApearInput');
const carSellingInput = document.getElementById('carSellingInput');
const carTradebleInput = document.getElementById('carTradebleInput');
const carTypeInput = document.getElementById('carTypeInput');
const carImageInput = document.getElementById('carImageInput');
const carImagePreview = document.getElementById('carImagePreview');
const imagePreviewBox = document.getElementById('imagePreviewBox');
const addCarStatus = document.getElementById('addCarStatus');

let currentCoords = '';

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

async function copyText(text) {
    try {
        await navigator.clipboard.writeText(text);
        statusEl.textContent = 'Coordonatele au fost copiate.';
        return true;
    } catch (e) {
        try {
            coordsInput.focus();
            coordsInput.select();
            document.execCommand('copy');
            statusEl.textContent = 'Coordonatele au fost copiate.';
            return true;
        } catch (err) {
            statusEl.textContent = 'Auto-copy blocat. Apasa COPY.';
            return false;
        }
    }
}

function showCoords(data) {
    const payload = data || {};

    currentCoords = String(payload.coords || '');

    coordsInput.value = currentCoords;
    xInput.value = Number(payload.x || 0).toFixed(6);
    yInput.value = Number(payload.y || 0).toFixed(6);
    zInput.value = Number(payload.z || 0).toFixed(6);
    headingInput.value = Number(payload.heading || 0).toFixed(2);
    dimensionInput.value = Number(payload.dimension || 0);

    panel.classList.remove('hidden');

    setTimeout(() => {
        copyText(currentCoords);
    }, 120);
}

function copyCoords() {
    copyText(currentCoords);
}

function closePanel() {
    panel.classList.add('hidden');
    nui('closeCoords');
}


function showAddCar(data = {}) {
    if (panel) panel.classList.add('hidden');
    addCarPanel.classList.remove('hidden');
    addCarStatus.textContent = 'Completeaza campurile obligatorii.';
    addCarStatus.classList.remove('error', 'success');

    carModelInput.value = '';
    carNameInput.value = '';
    carPriceInput.value = '';
    carCategoryInput.value = '1';
    carVipInput.value = '0';
    carApearInput.value = '1';
    carSellingInput.value = '1';
    carTradebleInput.value = '1';
    carTypeInput.value = 'drift';
    carImageInput.value = '';
    imagePreviewBox.classList.add('hidden');

    setTimeout(() => carModelInput.focus(), 80);
}

function closeAddCarPanel() {
    addCarPanel.classList.add('hidden');
    nui('closeAddCar');
}

function previewCarImage() {
    const url = String(carImageInput.value || '').trim();
    if (!url || !/^https?:\/\//i.test(url)) {
        imagePreviewBox.classList.add('hidden');
        carImagePreview.src = '';
        return;
    }

    carImagePreview.src = url;
    imagePreviewBox.classList.remove('hidden');
}

function submitAddCar() {
    const payload = {
        model: carModelInput.value.trim(),
        name: carNameInput.value.trim(),
        price: Number(carPriceInput.value || 0),
        category: Number(carCategoryInput.value || 1),
        vip: Number(carVipInput.value || 0),
        apear: Number(carApearInput.value || 1),
        selling: Number(carSellingInput.value || 1),
        tradeble: Number(carTradebleInput.value || 1),
        type: carTypeInput.value,
        image: carImageInput.value.trim()
    };

    if (!payload.model || !payload.name) {
        addCarStatus.textContent = 'Car Model ID si Car Name sunt obligatorii.';
        addCarStatus.classList.add('error');
        return;
    }

    addCarStatus.textContent = 'Se adauga masina...';
    addCarStatus.classList.remove('error', 'success');

    nui('submitAddCar', payload);
}

function addCarResult(data = {}) {
    addCarStatus.textContent = data.message || (data.ok ? 'Masina adaugata.' : 'Eroare.');
    addCarStatus.classList.toggle('success', data.ok === true);
    addCarStatus.classList.toggle('error', data.ok !== true);

    if (data.ok === true) {
        carModelInput.value = '';
        carNameInput.value = '';
        carPriceInput.value = '';
        carImageInput.value = '';
        imagePreviewBox.classList.add('hidden');
    }
}


window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'coords') {
        showCoords(data.data || {});
    }

    if (data.action === 'addCar') {
        showAddCar(data.data || {});
    }

    if (data.action === 'addCarResult') {
        addCarResult(data);
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        if (!addCarPanel.classList.contains('hidden')) {
            closeAddCarPanel();
        } else {
            closePanel();
        }
    }
});