'use strict';

const raceMenu = document.getElementById('raceMenu');
const raceList = document.getElementById('raceList');
const vehicleList = document.getElementById('vehicleList');
const searchInput = document.getElementById('searchInput');
const startBtn = document.getElementById('startBtn');
const selectedTitle = document.getElementById('selectedTitle');
const selectedSub = document.getElementById('selectedSub');
const inviteMenu = document.getElementById('inviteMenu');
const friendId = document.getElementById('friendId');
const duoGarage = document.getElementById('duoGarage');
const partnerName = document.getElementById('partnerName');
const duoVehicleList = document.getElementById('duoVehicleList');
const duoReadyBtn = document.getElementById('duoReadyBtn');
const readyState = document.getElementById('readyState');
const raceHud = document.getElementById('raceHud');
const hudTime = document.getElementById('hudTime');
const countdown = document.getElementById('countdown');
const countdownText = document.getElementById('countdownText');
const rewardScreen = document.getElementById('rewardScreen');
const rewardTotal = document.getElementById('rewardTotal');
const rewardP1Name = document.getElementById('rewardP1Name');
const rewardP2Name = document.getElementById('rewardP2Name');
const rewardP1Cash = document.getElementById('rewardP1Cash');
const rewardP2Cash = document.getElementById('rewardP2Cash');
const rewardP1Xp = document.getElementById('rewardP1Xp');
const rewardP2Xp = document.getElementById('rewardP2Xp');

let races = [];
let vehicles = [];
let selectedRace = null;
let selectedVehicle = null;
let duoSessionId = 0;
let duoSelectedVehicle = null;
let duoVehicles = [];

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}
function escapeHtml(value) {
    return String(value || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}
function money(value) { return '$' + Number(value || 0).toLocaleString('en-US'); }
function timeFmt(seconds) {
    seconds = Math.max(0, Math.floor(Number(seconds || 0)));
    return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}
function setMainColor(color) { if (color) document.documentElement.style.setProperty('--main', color); }

function openMenu(data) {
    races = Array.isArray(data.races) ? data.races : [];
    vehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    selectedRace = null; selectedVehicle = null;
    setMainColor(data.mainColor);
    renderRaces(); renderVehicles(); updateBottom();
    raceMenu.classList.remove('hidden');
}
function closeMenu() { raceMenu.classList.add('hidden'); nui('close'); }
function renderRaces() {
    raceList.innerHTML = races.map((race) => {
        const selected = selectedRace && selectedRace.id === race.id;
        const locked = Number(race.cooldownLeft || 0) > 0;
        const special = race.special === true;
        return `<button class="race-card ${selected ? 'selected' : ''} ${locked ? 'locked' : ''} ${special ? 'special' : ''}" onclick="selectRace('${escapeHtml(race.id)}')">
            <div class="race-top"><b>${special ? 'SPECIAL' : escapeHtml(race.label)}</b><span>${locked ? timeFmt(race.cooldownLeft) : 'READY'}</span></div>
            ${special ? `<div class="duo-label">${escapeHtml(race.subLabel || 'Duo Race')}</div>` : ''}
            <p>${escapeHtml(race.description)}</p>
            <div class="race-meta"><span>${money(race.rewardMin)} - ${money(race.rewardMax)}</span><span>${timeFmt(race.timeLimit)}</span></div>
        </button>`;
    }).join('');
}
function renderVehicles() {
    const q = String(searchInput.value || '').trim().toLowerCase();
    const list = vehicles.filter((v) => !q || `${v.name || ''} ${v.model || ''} ${v.plate || ''}`.toLowerCase().includes(q));
    vehicleList.innerHTML = list.length ? list.map(vehicleCard).join('') : '<div class="empty">Nu ai masini disponibile.</div>';
}
function vehicleCard(veh, duo = false) {
    const selected = duo ? (duoSelectedVehicle && Number(duoSelectedVehicle.id) === Number(veh.id)) : (selectedVehicle && Number(selectedVehicle.id) === Number(veh.id));
    return `<button class="vehicle-card ${selected ? 'selected' : ''}" onclick="${duo ? 'selectDuoVehicle' : 'selectVehicle'}(${Number(veh.id || 0)})">
        <div class="vehicle-icon">DZ</div><div><b>${escapeHtml(veh.name || veh.model || 'Vehicle')}</b><span>${escapeHtml(veh.model || 'model')} • ${escapeHtml(veh.plate || 'DRIFT')}</span></div>
    </button>`;
}
function selectRace(id) { selectedRace = races.find(r => String(r.id) === String(id)); renderRaces(); updateBottom(); }
function selectVehicle(id) { selectedVehicle = vehicles.find(v => Number(v.id) === Number(id)); renderVehicles(); updateBottom(); }
function updateBottom() {
    const raceReady = selectedRace && Number(selectedRace.cooldownLeft || 0) <= 0;
    const isSpecial = selectedRace && selectedRace.special === true;
    const ok = selectedRace && raceReady && (isSpecial || selectedVehicle);
    if (selectedRace && isSpecial) {
        selectedTitle.textContent = 'SPECIAL • Duo Race';
        selectedSub.textContent = raceReady ? 'Invita un prieten si porniti cursa impreuna.' : `Cooldown ramas: ${timeFmt(selectedRace.cooldownLeft)}`;
    } else if (selectedRace && selectedVehicle) {
        selectedTitle.textContent = `${selectedRace.label} cu ${selectedVehicle.name || selectedVehicle.model}`;
        selectedSub.textContent = raceReady ? `${money(selectedRace.rewardMin)} - ${money(selectedRace.rewardMax)} • timp ${timeFmt(selectedRace.timeLimit)}` : `Cooldown ramas: ${timeFmt(selectedRace.cooldownLeft)}`;
    } else if (selectedRace) {
        selectedTitle.textContent = selectedRace.label;
        selectedSub.textContent = raceReady ? 'Selecteaza masina pentru cursa.' : `Cooldown ramas: ${timeFmt(selectedRace.cooldownLeft)}`;
    } else { selectedTitle.textContent = 'Nimic selectat'; selectedSub.textContent = 'Alege o cursa si o masina pentru start.'; }
    startBtn.disabled = !ok;
}
function startRace() { if (!selectedRace) return; startBtn.disabled = true; nui('start', { raceId: selectedRace.id, vehicleId: selectedVehicle && selectedVehicle.id }); }
function closeInvite() { inviteMenu.classList.add('hidden'); }
function sendInvite() { nui('duoInvite', { targetId: Number(friendId.value || 0) }); inviteMenu.classList.add('hidden'); }
function openDuoGarage(data) {
    duoSessionId = Number(data.sessionId || 0); duoVehicles = Array.isArray(data.vehicles) ? data.vehicles : []; duoSelectedVehicle = null;
    partnerName.textContent = String(data.partner || 'Player');
    readyState.textContent = 'WAITING'; duoReadyBtn.disabled = true;
    duoVehicleList.innerHTML = duoVehicles.length ? duoVehicles.map(v => vehicleCard(v, true)).join('') : '<div class="empty">Nu ai masini disponibile.</div>';
    duoGarage.classList.remove('hidden');
}
function selectDuoVehicle(id) { duoSelectedVehicle = duoVehicles.find(v => Number(v.id) === Number(id)); duoReadyBtn.disabled = !duoSelectedVehicle; duoVehicleList.innerHTML = duoVehicles.map(v => vehicleCard(v, true)).join(''); }
function duoReady() { if (!duoSelectedVehicle) return; duoReadyBtn.disabled = true; readyState.textContent = 'READY'; nui('duoReady', { sessionId: duoSessionId, vehicleId: duoSelectedVehicle.id }); }
function closeDuoGarage() { duoGarage.classList.add('hidden'); nui('close'); }
function animateValue(el, target, prefix, suffix, duration) {
    target = Number(target || 0); const start = performance.now();
    function tick(now) { const p = Math.min(1, (now - start) / duration); const v = Math.floor(target * (1 - Math.pow(1 - p, 3))); el.textContent = `${prefix}${v.toLocaleString('en-US')}${suffix}`; if (p < 1) requestAnimationFrame(tick); }
    requestAnimationFrame(tick);
}
function showReward(payload) {
    const d = payload || {}; rewardTotal.textContent = money(d.totalCash || 0);
    rewardP1Name.textContent = d.p1?.name || 'Player 1'; rewardP2Name.textContent = d.p2?.name || 'Player 2';
    rewardP1Cash.textContent = '$0'; rewardP2Cash.textContent = '$0'; rewardP1Xp.textContent = '0 XP'; rewardP2Xp.textContent = '0 XP';
    rewardScreen.classList.remove('hidden');
    setTimeout(() => { animateValue(rewardP1Cash, d.p1?.cash || 0, '$', '', 2400); animateValue(rewardP2Cash, d.p2?.cash || 0, '$', '', 2400); }, 900);
    setTimeout(() => { animateValue(rewardP1Xp, d.p1?.xp || 0, '', ' XP', 2100); animateValue(rewardP2Xp, d.p2?.xp || 0, '', ' XP', 2100); }, 3600);
}

document.addEventListener('keydown', (event) => { if (event.key === 'Escape') { if (!raceMenu.classList.contains('hidden')) closeMenu(); if (!inviteMenu.classList.contains('hidden')) closeInvite(); if (!duoGarage.classList.contains('hidden')) closeDuoGarage(); } });
window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'closeMenu') raceMenu.classList.add('hidden');
    if (data.action === 'openInvite') { raceMenu.classList.add('hidden'); friendId.value = ''; inviteMenu.classList.remove('hidden'); setTimeout(() => friendId.focus(), 80); }
    if (data.action === 'openDuoGarage') openDuoGarage(data);
    if (data.action === 'closeDuoGarage') duoGarage.classList.add('hidden');
    if (data.action === 'duoStatus') readyState.textContent = (data.p1Ready && data.p2Ready) ? 'STARTING' : 'WAITING';
    if (data.action === 'raceHud') { data.visible ? raceHud.classList.remove('hidden') : raceHud.classList.add('hidden'); if (data.time) hudTime.textContent = data.time; }
    if (data.action === 'timer') { hudTime.textContent = String(data.time || '0:00'); raceHud.classList.toggle('danger', data.danger === true); }
    if (data.action === 'countdown') { if (data.visible) { countdownText.textContent = String(data.text || '3'); countdownText.classList.remove('pop'); void countdownText.offsetWidth; countdownText.classList.add('pop'); countdown.classList.remove('hidden'); } else countdown.classList.add('hidden'); }
    if (data.action === 'duoReward') showReward(data.data || {});
    if (data.action === 'duoRewardHide') rewardScreen.classList.add('hidden');
});
window.closeMenu = closeMenu; window.selectRace = selectRace; window.selectVehicle = selectVehicle; window.renderVehicles = renderVehicles; window.startRace = startRace; window.closeInvite = closeInvite; window.sendInvite = sendInvite; window.selectDuoVehicle = selectDuoVehicle; window.duoReady = duoReady; window.closeDuoGarage = closeDuoGarage;
setTimeout(() => nui('ready'), 80);
