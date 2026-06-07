'use strict';

const raceMenu = document.getElementById('raceMenu');
const raceList = document.getElementById('raceList');
const vehicleList = document.getElementById('vehicleList');
const searchInput = document.getElementById('searchInput');
const startBtn = document.getElementById('startBtn');
const selectedTitle = document.getElementById('selectedTitle');
const selectedSub = document.getElementById('selectedSub');
const raceHud = document.getElementById('raceHud');
const hudRaceName = document.getElementById('hudRaceName');
const hudTime = document.getElementById('hudTime');
const countdown = document.getElementById('countdown');
const countdownText = document.getElementById('countdownText');

let races = [];
let vehicles = [];
let selectedRace = null;
let selectedVehicle = null;

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

function money(value) {
    return '$' + Number(value || 0).toLocaleString('en-US');
}

function timeFmt(seconds) {
    seconds = Math.max(0, Number(seconds || 0));
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${String(s).padStart(2, '0')}`;
}

function setMainColor(color) {
    if (color) document.documentElement.style.setProperty('--main', color);
}

function openMenu(data) {
    races = Array.isArray(data.races) ? data.races : [];
    vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    selectedRace = null;
    selectedVehicle = null;

    setMainColor(data.mainColor);
    renderRaces();
    renderVehicles();
    updateBottom();
    raceMenu.classList.remove('hidden');
}

function closeMenu() {
    raceMenu.classList.add('hidden');
    nui('close');
}

function renderRaces() {
    if (!races.length) {
        raceList.innerHTML = '<div class="empty">Nu exista curse configurate.</div>';
        return;
    }

    raceList.innerHTML = races.map((race) => {
        const selected = selectedRace && selectedRace.id === race.id;
        const locked = Number(race.cooldownLeft || 0) > 0;
        return `
            <button class="race-card ${selected ? 'selected' : ''} ${locked ? 'locked' : ''}" onclick="selectRace('${escapeHtml(race.id)}')">
                <div class="race-top">
                    <b>${escapeHtml(race.label)}</b>
                    <span>${locked ? timeFmt(race.cooldownLeft) : 'READY'}</span>
                </div>
                <p>${escapeHtml(race.description)}</p>
                <div class="race-meta">
                    <span>${money(race.rewardMin)} - ${money(race.rewardMax)}</span>
                    <span>${timeFmt(race.timeLimit)}</span>
                </div>
            </button>
        `;
    }).join('');
}

function renderVehicles() {
    const q = String(searchInput.value || '').trim().toLowerCase();
    const list = vehicles.filter((v) => {
        const text = `${v.name || ''} ${v.model || ''} ${v.plate || ''}`.toLowerCase();
        return !q || text.includes(q);
    });

    if (!list.length) {
        vehicleList.innerHTML = '<div class="empty">Nu ai masini disponibile.</div>';
        return;
    }

    vehicleList.innerHTML = list.map((veh) => {
        const selected = selectedVehicle && Number(selectedVehicle.id) === Number(veh.id);
        return `
            <button class="vehicle-card ${selected ? 'selected' : ''}" onclick="selectVehicle(${Number(veh.id || 0)})">
                <div class="vehicle-icon">DZ</div>
                <div>
                    <b>${escapeHtml(veh.name || veh.model || 'Vehicle')}</b>
                    <span>${escapeHtml(veh.model || 'model')} • ${escapeHtml(veh.plate || 'DRIFT')}</span>
                </div>
            </button>
        `;
    }).join('');
}

function selectRace(id) {
    const race = races.find(r => String(r.id) === String(id));
    if (!race) return;
    selectedRace = race;
    renderRaces();
    updateBottom();
}

function selectVehicle(id) {
    const vehicle = vehicles.find(v => Number(v.id) === Number(id));
    if (!vehicle) return;
    selectedVehicle = vehicle;
    renderVehicles();
    updateBottom();
}

function updateBottom() {
    const raceReady = selectedRace && Number(selectedRace.cooldownLeft || 0) <= 0;
    const ok = raceReady && selectedVehicle;

    if (selectedRace && selectedVehicle) {
        selectedTitle.textContent = `${selectedRace.label} cu ${selectedVehicle.name || selectedVehicle.model}`;
        selectedSub.textContent = raceReady
            ? `${money(selectedRace.rewardMin)} - ${money(selectedRace.rewardMax)} • timp ${timeFmt(selectedRace.timeLimit)}`
            : `Cooldown ramas: ${timeFmt(selectedRace.cooldownLeft)}`;
    } else if (selectedRace) {
        selectedTitle.textContent = selectedRace.label;
        selectedSub.textContent = raceReady ? 'Selecteaza masina pentru cursa.' : `Cooldown ramas: ${timeFmt(selectedRace.cooldownLeft)}`;
    } else if (selectedVehicle) {
        selectedTitle.textContent = selectedVehicle.name || selectedVehicle.model;
        selectedSub.textContent = 'Selecteaza cursa pentru start.';
    } else {
        selectedTitle.textContent = 'Nimic selectat';
        selectedSub.textContent = 'Alege o cursa si o masina pentru start.';
    }

    startBtn.disabled = !ok;
}

function startRace() {
    if (!selectedRace || !selectedVehicle) return;
    if (Number(selectedRace.cooldownLeft || 0) > 0) return;
    startBtn.disabled = true;
    nui('start', { raceId: selectedRace.id, vehicleId: selectedVehicle.id });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'closeMenu') raceMenu.classList.add('hidden');

    if (data.action === 'raceHud') {
        if (data.visible === true) {
            raceHud.classList.remove('hidden');
            hudRaceName.textContent = String(data.race || 'Race');
            hudTime.textContent = String(data.time || '0:00');
            raceHud.classList.remove('danger');
        } else {
            raceHud.classList.add('hidden');
        }
    }

    if (data.action === 'timer') {
        hudTime.textContent = String(data.time || '0:00');
        raceHud.classList.toggle('danger', data.danger === true);
    }

    if (data.action === 'countdown') {
        if (data.visible === true) {
            countdownText.textContent = String(data.text || '3');
            countdownText.classList.remove('pop');
            void countdownText.offsetWidth;
            countdownText.classList.add('pop');
            countdown.classList.remove('hidden');
        } else {
            countdown.classList.add('hidden');
        }
    }
});

window.closeMenu = closeMenu;
window.selectRace = selectRace;
window.selectVehicle = selectVehicle;
window.renderVehicles = renderVehicles;
window.startRace = startRace;

setTimeout(() => nui('ready'), 80);
