'use strict';

const app = document.getElementById('app');
const typeView = document.getElementById('typeView');
const plateView = document.getElementById('plateView');
const vehicleView = document.getElementById('vehicleView');
const plateInput = document.getElementById('plateInput');
const platePreview = document.getElementById('platePreview');
const plateLabel = document.getElementById('plateLabel');
const rules = document.getElementById('rules');
const plateError = document.getElementById('plateError');
const buyError = document.getElementById('buyError');
const vehiclesEl = document.getElementById('vehicles');
const vehicleCount = document.getElementById('vehicleCount');
const cashBalance = document.getElementById('cashBalance');
const coinsBalance = document.getElementById('coinsBalance');
const normalPrice = document.getElementById('normalPrice');
const premiumPrice = document.getElementById('premiumPrice');
const buyBtn = document.getElementById('buyBtn');

let state = {
    type: '',
    plate: '',
    vehicleId: 0,
    vehicles: [],
    balances: { cash: 0, dzcoins: 0 },
    prices: { normal: 100000, premium: 2000 },
    limits: { normalPrefix: 'DZ', normalMinExtra: 3, normalMaxLength: 8, premiumMinLength: 1, premiumMaxLength: 8 }
};

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function money(n) {
    return '$' + Number(n || 0).toLocaleString('en-US');
}

function esc(value) {
    return String(value ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}

function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }

function setError(el, text) {
    if (!text) { el.textContent = ''; el.classList.add('hidden'); return; }
    el.textContent = text;
    el.classList.remove('hidden');
}

function closeUi() {
    app.classList.add('hidden');
    setError(plateError, '');
    setError(buyError, '');
    nui('close');
}

function goStep(step) {
    hide(typeView); hide(plateView); hide(vehicleView);
    document.querySelectorAll('.step').forEach(s => s.classList.toggle('active', Number(s.dataset.step) <= step));
    if (step === 1) show(typeView);
    if (step === 2) show(plateView);
    if (step === 3) { renderVehicles(); show(vehicleView); }
}

function chooseType(type) {
    state.type = type;
    state.vehicleId = 0;
    setError(plateError, '');
    setError(buyError, '');

    if (type === 'normal') {
        plateLabel.textContent = 'Numar normal';
        plateInput.placeholder = 'DZABC1';
        plateInput.maxLength = state.limits.normalMaxLength || 8;
        rules.textContent = `Trebuie sa inceapa cu ${state.limits.normalPrefix || 'DZ'} si dupa prefix sa aiba minim ${state.limits.normalMinExtra || 3} litere/cifre.`;
        plateInput.value = state.limits.normalPrefix || 'DZ';
    } else {
        plateLabel.textContent = 'Numar premium';
        plateInput.placeholder = 'CLAUDIU';
        plateInput.maxLength = state.limits.premiumMaxLength || 8;
        rules.textContent = `Premium: orice combinatie disponibila, minim ${state.limits.premiumMinLength || 1}, maxim ${state.limits.premiumMaxLength || 8} caractere.`;
        plateInput.value = '';
    }

    updatePreview();
    goStep(2);
    setTimeout(() => plateInput.focus(), 60);
}

function cleanPlate(value) {
    return String(value || '').toUpperCase().replace(/\s+/g, '').replace(/[^A-Z0-9]/g, '');
}

function validatePlateLocal() {
    const plate = cleanPlate(plateInput.value);
    const limits = state.limits || {};

    if (!plate) return 'Introdu un numar de inmatriculare.';

    if (state.type === 'normal') {
        const prefix = String(limits.normalPrefix || 'DZ').toUpperCase();
        const minExtra = Number(limits.normalMinExtra || 3);
        const maxLength = Number(limits.normalMaxLength || 8);
        if (!plate.startsWith(prefix)) return `Numarul normal trebuie sa inceapa cu ${prefix}.`;
        if (plate.length < prefix.length + minExtra) return `Dupa ${prefix} trebuie minim ${minExtra} litere/cifre.`;
        if (plate.length > maxLength) return `Numarul poate avea maxim ${maxLength} caractere.`;
    } else {
        const minLength = Number(limits.premiumMinLength || 1);
        const maxLength = Number(limits.premiumMaxLength || 8);
        if (plate.length < minLength) return `Numarul premium trebuie sa aiba minim ${minLength} caracter.`;
        if (plate.length > maxLength) return `Numarul poate avea maxim ${maxLength} caractere.`;
    }

    return '';
}

function updatePreview() {
    const plate = cleanPlate(plateInput.value);
    plateInput.value = plate;
    platePreview.textContent = plate || '--------';
}

plateInput.addEventListener('input', () => {
    updatePreview();
    setError(plateError, '');
});

function validatePlateStep() {
    const error = validatePlateLocal();
    if (error) { setError(plateError, error); return; }
    state.plate = cleanPlate(plateInput.value);
    goStep(3);
}

function renderVehicles() {
    const list = Array.isArray(state.vehicles) ? state.vehicles : [];
    vehicleCount.textContent = `${list.length} vehicles`;
    cashBalance.textContent = `Cash: ${money(state.balances.cash || 0)}`;
    coinsBalance.textContent = `DZC: ${Number(state.balances.dzcoins || 0).toLocaleString('en-US')}`;

    if (!list.length) {
        vehiclesEl.innerHTML = '<div class="empty">Nu ai masini personale disponibile.</div>';
        return;
    }

    vehiclesEl.innerHTML = list.map(v => {
        const id = Number(v.id || 0);
        const active = Number(state.vehicleId) === id ? 'active' : '';
        const name = v.name || v.model || 'Vehicle';
        const plate = v.plate || 'NO PLATE';
        return `<button class="vehicle ${active}" onclick="selectVehicle(${id})">
            <div><b>${esc(name)}</b><span>${esc(v.model || '')}</span></div>
            <em>${esc(plate)}</em>
        </button>`;
    }).join('');
}

function selectVehicle(id) {
    state.vehicleId = Number(id || 0);
    setError(buyError, '');
    renderVehicles();
}

function buyPlate() {
    if (!state.vehicleId) { setError(buyError, 'Selecteaza o masina.'); return; }
    const error = validatePlateLocal();
    if (error) { goStep(2); setError(plateError, error); return; }

    buyBtn.disabled = true;
    buyBtn.textContent = 'Processing...';
    nui('buyPlate', {
        licenseType: state.type,
        plate: cleanPlate(plateInput.value),
        vehicleId: state.vehicleId
    });
}

function applyPayload(payload) {
    const data = payload || {};
    state.vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    state.balances = data.balances || { cash: 0, dzcoins: 0 };
    state.prices = data.prices || state.prices;
    state.limits = data.limits || state.limits;
    normalPrice.textContent = money(state.prices.normal || 100000);
    premiumPrice.textContent = `${Number(state.prices.premium || 2000).toLocaleString('en-US')} DZC`;
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};

    if (msg.action === 'open') {
        document.documentElement.style.setProperty('--main', msg.mainColor || '#04c7f7');
        applyPayload(msg.data || {});
        app.classList.remove('hidden');
        state.type = '';
        state.plate = '';
        state.vehicleId = 0;
        buyBtn.disabled = false;
        buyBtn.textContent = 'Buy Plate';
        goStep(1);
    }

    if (msg.action === 'refresh') {
        applyPayload(msg.data || {});
        renderVehicles();
    }

    if (msg.action === 'result') {
        buyBtn.disabled = false;
        buyBtn.textContent = 'Buy Plate';
        if (msg.ok) {
            applyPayload(msg.data || {});
            setError(buyError, '');
            const text = msg.message || 'Numar schimbat cu succes.';
            buyError.textContent = text;
            buyError.classList.remove('hidden');
            buyError.classList.add('success');
            setTimeout(() => closeUi(), 1200);
        } else {
            buyError.classList.remove('success');
            setError(buyError, msg.message || 'Eroare.');
        }
    }

    if (msg.action === 'close') {
        app.classList.add('hidden');
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' || event.key === '`') {
        closeUi();
    }
});

setTimeout(() => nui('ready'), 100);
