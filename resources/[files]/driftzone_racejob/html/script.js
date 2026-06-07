'use strict';

const raceMenu = document.getElementById('raceMenu');
const raceList = document.getElementById('raceList');
const vehicleList = document.getElementById('vehicleList');
const searchInput = document.getElementById('searchInput');
const startBtn = document.getElementById('startBtn');
const selectedTitle = document.getElementById('selectedTitle');
const selectedSub = document.getElementById('selectedSub');
const raceCount = document.getElementById('raceCount');
const raceHud = document.getElementById('raceHud');
const hudRaceName = document.getElementById('hudRaceName');
const hudTime = document.getElementById('hudTime');
const countdown = document.getElementById('countdown');
const countdownText = document.getElementById('countdownText');

let races = [];
let vehicles = [];
let selectedRace = null;
let selectedVehicle = null;
let serverTimeOffset = 0;

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

function money(value) { return '$' + Number(value || 0).toLocaleString('en-US'); }
function nowUnix() { return Math.floor(Date.now() / 1000) + serverTimeOffset; }
function timeFmt(seconds) {
    seconds = Math.max(0, Math.floor(Number(seconds || 0)));
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${String(s).padStart(2, '0')}`;
}
function setMainColor(color) { if (color) document.documentElement.style.setProperty('--main', color); }

function saveCooldown(raceId, untilTime) {
    if (!raceId) return;
    localStorage.setItem(`driftzone_racejob_cd_${raceId}`, String(Number(untilTime || 0)));
}
function getLocalCooldownUntil(raceId) {
    return Number(localStorage.getItem(`driftzone_racejob_cd_${raceId}`) || 0) || 0;
}
function clearLocalCooldowns() {
    ['short', 'medium', 'long'].forEach((id) => localStorage.removeItem(`driftzone_racejob_cd_${id}`));
}
function syncCooldowns(data = {}) {
    Object.entries(data).forEach(([id, info]) => {
        const untilTime = typeof info === 'object' ? Number(info.untilTime || 0) : Number(info || 0);
        if (untilTime > 0) saveCooldown(id, untilTime);
    });
}
function cooldownLeft(race) {
    const localUntil = getLocalCooldownUntil(race.id);
    const serverUntil = Number(race.cooldownUntil || 0);
    const untilTime = Math.max(localUntil, serverUntil);
    const left = untilTime - nowUnix();
    return left > 0 ? left : 0;
}

function openMenu(data) {
    races = Array.isArray(data.races) ? data.races : [];
    vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    selectedRace = null;
    selectedVehicle = null;
    setMainColor(data.mainColor);
    if (Number(data.serverTime || 0) > 0) serverTimeOffset = Number(data.serverTime) - Math.floor(Date.now() / 1000);
    if (data.cooldowns) syncCooldowns(data.cooldowns);
    raceCount.textContent = String(races.length);
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
        const left = cooldownLeft(race);
        const locked = left > 0;
        const selected = selectedRace && selectedRace.id === race.id;
        return `
            <button class="race-card ${selected ? 'selected' : ''} ${locked ? 'locked' : ''}" onclick="selectRace('${escapeHtml(race.id)}')">
                <div class="race-top">
                    <b>${escapeHtml(race.label)}</b>
                    <span>${locked ? `CD ${timeFmt(left)}` : 'READY'}</span>
                </div>
                <p>${escapeHtml(race.description)}</p>
                <div class="race-meta">
                    <em>${money(race.rewardMin)} - ${money(race.rewardMax)}</em>
                    <em>${timeFmt(race.timeLimit)}</em>
                </div>
            </button>
        `;
    }).join('');
}

function renderVehicles() {
    const query = String(searchInput.value || '').trim().toLowerCase();
    const list = query ? vehicles.filter(v => `${v.name} ${v.model} ${v.plate}`.toLowerCase().includes(query)) : vehicles;
    if (!list.length) {
        vehicleList.innerHTML = '<div class="empty">Nu ai masini disponibile.</div>';
        return;
    }
    vehicleList.innerHTML = list.map((vehicle) => {
        const selected = selectedVehicle && Number(selectedVehicle.id) === Number(vehicle.id);
        return `
            <button class="vehicle-card ${selected ? 'selected' : ''}" onclick="selectVehicle(${Number(vehicle.id)})">
                <div class="vehicle-icon">DZ</div>
                <div>
                    <b>${escapeHtml(vehicle.name || vehicle.model)}</b>
                    <span>${escapeHtml(vehicle.model)} · ${escapeHtml(vehicle.plate || 'DRIFT')}</span>
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
    if (!selectedRace && !selectedVehicle) {
        selectedTitle.textContent = 'Nimic selectat';
        selectedSub.textContent = 'Alege o cursa si o masina pentru start.';
        startBtn.disabled = true;
        return;
    }
    const raceText = selectedRace ? selectedRace.label : 'Fara cursa';
    const vehText = selectedVehicle ? (selectedVehicle.name || selectedVehicle.model) : 'Fara masina';
    selectedTitle.textContent = `${raceText} · ${vehText}`;
    if (selectedRace && cooldownLeft(selectedRace) > 0) {
        selectedSub.textContent = `Cooldown ramas: ${timeFmt(cooldownLeft(selectedRace))}`;
        startBtn.disabled = true;
        return;
    }
    selectedSub.textContent = selectedRace && selectedVehicle ? 'Pregatit pentru start.' : 'Selecteaza cursa si masina.';
    startBtn.disabled = !(selectedRace && selectedVehicle);
}

function startRace() {
    if (!selectedRace || !selectedVehicle) return;
    const left = cooldownLeft(selectedRace);
    if (left > 0) {
        updateBottom();
        renderRaces();
        return;
    }
    startBtn.disabled = true;
    nui('start', { raceId: selectedRace.id, vehicleId: Number(selectedVehicle.id) });
}

function setRaceHud(data) {
    if (data.visible === true) {
        hudRaceName.textContent = String(data.race || 'Race');
        hudTime.textContent = String(data.time || '0:00');
        raceHud.classList.remove('hidden');
    } else {
        raceHud.classList.add('hidden');
        raceHud.classList.remove('danger');
    }
}

function setTimer(data) {
    hudTime.textContent = String(data.time || '0:00');
    raceHud.classList.toggle('danger', data.danger === true);
}

function setCountdown(data) {
    if (data.visible === true) {
        countdownText.textContent = String(data.text || '3');
        countdown.classList.remove('hidden');
        countdownText.classList.remove('pop');
        void countdownText.offsetWidth;
        countdownText.classList.add('pop');
    } else {
        countdown.classList.add('hidden');
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'closeMenu') raceMenu.classList.add('hidden');
    if (data.action === 'raceHud') setRaceHud(data);
    if (data.action === 'timer') setTimer(data);
    if (data.action === 'countdown') setCountdown(data);
    if (data.action === 'cooldowns') {
        if (Number(data.serverTime || 0) > 0) serverTimeOffset = Number(data.serverTime) - Math.floor(Date.now() / 1000);
        syncCooldowns(data.cooldowns || {});
        renderRaces();
        updateBottom();
    }
    if (data.action === 'resetCooldowns') {
        clearLocalCooldowns();
        races.forEach((r) => { r.cooldownUntil = 0; r.cooldownLeft = 0; });
        renderRaces();
        updateBottom();
    }
});

setInterval(() => {
    if (!raceMenu.classList.contains('hidden')) {
        renderRaces();
        updateBottom();
    }
}, 1000);

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeMenu();
});

window.closeMenu = closeMenu;
window.renderVehicles = renderVehicles;
window.selectRace = selectRace;
window.selectVehicle = selectVehicle;
window.startRace = startRace;

setTimeout(() => nui('ready'), 80);
