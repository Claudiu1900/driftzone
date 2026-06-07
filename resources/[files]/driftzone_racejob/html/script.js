'use strict';

const root = document.getElementById('root');
const raceModesEl = document.getElementById('raceModes');
const vehiclesGrid = document.getElementById('vehiclesGrid');
const searchInput = document.getElementById('searchInput');
const selectedTitle = document.getElementById('selectedTitle');
const selectedMeta = document.getElementById('selectedMeta');
const startButton = document.getElementById('startButton');

let races = [];
let vehicles = [];
let selectedRace = 'short';
let selectedVehicleId = null;
let mainColor = '#04c7f7';

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

function currentRace() {
    return races.find((race) => race.id === selectedRace) || races[0] || null;
}

function currentVehicle() {
    return vehicles.find((veh) => Number(veh.id) === Number(selectedVehicleId)) || null;
}

function renderModes() {
    raceModesEl.innerHTML = races.map((race) => {
        const active = race.id === selectedRace ? 'active' : '';
        const disabled = race.enabled === false ? 'disabled' : '';

        return `
            <button class="mode ${active} ${disabled}" onclick="selectRace('${escapeHtml(race.id)}')" ${race.enabled === false ? 'disabled' : ''}>
                <span>${escapeHtml(race.title)}</span>
                <small>${escapeHtml(race.description)}</small>
            </button>
        `;
    }).join('');
}

function renderVehicles() {
    const query = (searchInput.value || '').trim().toLowerCase();
    const list = query
        ? vehicles.filter((veh) => `${veh.name} ${veh.model} ${veh.plate}`.toLowerCase().includes(query))
        : vehicles;

    if (!list.length) {
        vehiclesGrid.innerHTML = `
            <div class="empty">
                <b>Nu ai masini disponibile</b>
                <span>Ai nevoie de o masina in ownedvehicles ca sa pornesti Race Job.</span>
            </div>
        `;
        return;
    }

    vehiclesGrid.innerHTML = list.map((veh) => {
        const id = Number(veh.id || 0);
        const active = id === Number(selectedVehicleId) ? 'selected' : '';
        const img = String(veh.image || '').trim();

        return `
            <button class="vehicle ${active}" onclick="selectVehicle(${id})">
                <div class="vehicle-img">
                    ${img ? `<img src="${escapeHtml(img)}" onerror="this.remove()">` : `<span>${escapeHtml(String(veh.model || 'CAR').slice(0, 3).toUpperCase())}</span>`}
                </div>
                <div class="vehicle-info">
                    <b>${escapeHtml(veh.name || veh.model || 'Vehicle')}</b>
                    <span>${escapeHtml(veh.model || 'model')} • ${escapeHtml(veh.plate || 'DRIFT')}</span>
                </div>
            </button>
        `;
    }).join('');
}

function updateSelected() {
    const race = currentRace();
    const veh = currentVehicle();

    if (!race || !veh) {
        selectedTitle.textContent = 'Nicio masina selectata';
        selectedMeta.textContent = 'Selecteaza Short Race si o masina pentru a incepe.';
        startButton.disabled = true;
        return;
    }

    selectedTitle.textContent = `${race.title} cu ${veh.name || veh.model}`;
    selectedMeta.textContent = `${veh.model || 'model'} • ${veh.plate || 'DRIFT'} • Reward $2.000 - $5.000`;
    startButton.disabled = false;
}

function selectRace(id) {
    const race = races.find((item) => item.id === id);

    if (!race || race.enabled === false) return;

    selectedRace = id;
    renderModes();
    updateSelected();
}

function selectVehicle(id) {
    selectedVehicleId = Number(id || 0);
    renderVehicles();
    updateSelected();
}

function startRace() {
    const race = currentRace();
    const veh = currentVehicle();

    if (!race || !veh || race.enabled === false) return;

    startButton.disabled = true;

    nui('start', {
        race: race.id,
        vehicleId: Number(veh.id)
    });

    setTimeout(() => {
        startButton.disabled = false;
    }, 1500);
}

function open(data) {
    mainColor = data.mainColor || mainColor;
    document.documentElement.style.setProperty('--main', mainColor);

    races = Array.isArray(data.races) ? data.races : [];
    vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    selectedRace = 'short';
    selectedVehicleId = null;

    if (searchInput) searchInput.value = '';

    renderModes();
    renderVehicles();
    updateSelected();

    root.classList.remove('hidden');
}

function closeMenu() {
    root.classList.add('hidden');
    nui('close');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') open(data);
    if (data.action === 'close') root.classList.add('hidden');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeMenu();
});

window.selectRace = selectRace;
window.selectVehicle = selectVehicle;
window.startRace = startRace;
window.closeMenu = closeMenu;
window.renderVehicles = renderVehicles;

setTimeout(() => nui('ready'), 80);
