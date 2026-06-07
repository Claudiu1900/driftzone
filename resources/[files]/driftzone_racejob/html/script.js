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
const inviteError = document.getElementById('inviteError');
const inviteBtn = document.getElementById('inviteBtn');
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
const rewardTotalXp = document.getElementById('rewardTotalXp');
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
let cooldownTimer = null;

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
function timeFmtHMS(seconds) {
    seconds = Math.max(0, Math.floor(Number(seconds || 0)));
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}
function setMainColor(color) { if (color) document.documentElement.style.setProperty('--main', color); }

function vehicleIdOf(vehicle) {
    return String((vehicle && (vehicle.id ?? vehicle.vehicleId ?? vehicle.dbId)) ?? '');
}

function findVehicleById(list, id) {
    const key = String(id ?? '');
    return (Array.isArray(list) ? list : []).find(v => vehicleIdOf(v) === key) || null;
}

function renderVehicleList(target, list, duo = false) {
    target.innerHTML = list.length ? list.map(v => vehicleCard(v, duo)).join('') : '<div class="empty">Nu ai masini disponibile.</div>';
}

function openMenu(data) {
    races = Array.isArray(data.races) ? data.races.map(r => ({ ...r })) : [];
    vehicles = Array.isArray(data.vehicles) ? data.vehicles.map(v => ({ ...v })) : [];
    selectedRace = null;
    selectedVehicle = null;
    if (searchInput) searchInput.value = '';
    setMainColor(data.mainColor);
    renderRaces();
    renderVehicles();
    updateBottom();
    raceMenu.classList.remove('hidden');
    startCooldownTimer();
}
function closeMenu() {
    raceMenu.classList.add('hidden');
    stopCooldownTimer();
    nui('close');
}
function startCooldownTimer() {
    stopCooldownTimer();
    cooldownTimer = setInterval(() => {
        if (raceMenu.classList.contains('hidden')) { stopCooldownTimer(); return; }
        let changed = false;
        races.forEach((race) => {
            const left = Number(race.cooldownLeft || 0);
            if (left > 0) {
                race.cooldownLeft = Math.max(0, left - 1);
                changed = true;
            }
        });
        if (changed) { renderRaces(); updateBottom(); }
    }, 1000);
}
function stopCooldownTimer() {
    if (cooldownTimer) clearInterval(cooldownTimer);
    cooldownTimer = null;
}
function renderRaces() {
    raceList.innerHTML = races.map((race) => {
        const selected = selectedRace && selectedRace.id === race.id;
        const locked = Number(race.cooldownLeft || 0) > 0;
        const special = race.special === true;
        const title = escapeHtml(race.label || race.id);
        const cd = special ? timeFmtHMS(race.cooldownLeft) : timeFmt(race.cooldownLeft);
        const stateText = locked ? cd : 'READY';
        const desc = special
            ? `${race.subLabel || 'Duo Race'} • ${race.description || ''}`
            : (race.description || 'Race job DriftZone');

        return `<button class="race-card ${selected ? 'selected' : ''} ${locked ? 'locked' : ''} ${special ? 'special' : ''}" onclick="selectRace('${escapeHtml(race.id)}')">
            <div class="race-glow"></div>
            <div class="race-top">
                <div class="race-name">
                    <span>${special ? 'SPECIAL' : 'RACE'}</span>
                    <b>${title}</b>
                </div>
                <em>${stateText}</em>
            </div>
            <p>${escapeHtml(desc)}</p>
            <div class="race-meta">
                <span>${money(race.rewardMin)} - ${money(race.rewardMax)}</span>
                <span>${timeFmt(race.timeLimit)}</span>
            </div>
        </button>`;
    }).join('');
}
function renderVehicles() {
    const q = String(searchInput.value || '').trim().toLowerCase();
    const list = vehicles.filter((v) => !q || `${v.name || ''} ${v.model || ''} ${v.plate || ''}`.toLowerCase().includes(q));
    renderVehicleList(vehicleList, list, false);
}
function vehicleCard(veh, duo = false) {
    const id = vehicleIdOf(veh);
    const selected = duo
        ? (duoSelectedVehicle && vehicleIdOf(duoSelectedVehicle) === id)
        : (selectedVehicle && vehicleIdOf(selectedVehicle) === id);
    const title = escapeHtml(veh.name || veh.model || 'Vehicle');
    const model = escapeHtml(veh.model || 'model');
    const plate = escapeHtml(veh.plate || 'DRIFT');
    const safeId = escapeHtml(id);

    return `<button type="button" class="vehicle-card ${selected ? 'selected' : ''}" data-vehicle-id="${safeId}" onclick="${duo ? 'selectDuoVehicle' : 'selectVehicle'}('${safeId}')">
        <div class="vehicle-mark"><svg viewBox="0 0 24 24"><path d="M5 13l1.7-4.5A3 3 0 0 1 9.5 6.6h5a3 3 0 0 1 2.8 1.9L19 13M4.5 13h15v5.2H17v-1.7H7v1.7H4.5V13Zm3.2 0h8.6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
        <div class="vehicle-info">
            <b>${title}</b>
            <span>${model}</span>
        </div>
        <small>${plate}</small>
    </button>`;
}
function selectRace(id) {
    selectedRace = races.find(r => String(r.id) === String(id)) || null;
    renderRaces();
    updateBottom();
}
function selectVehicle(id) {
    selectedVehicle = findVehicleById(vehicles, id);
    renderVehicles();
    updateBottom();
}
function updateBottom() {
    const raceReady = selectedRace && Number(selectedRace.cooldownLeft || 0) <= 0;
    const isSpecial = selectedRace && selectedRace.special === true;
    const ok = selectedRace && raceReady && (isSpecial || selectedVehicle);
    if (selectedRace && isSpecial) {
        selectedTitle.textContent = 'SPECIAL - Duo Delivery';
        selectedSub.textContent = raceReady ? 'Invita un prieten si porniti livrarea impreuna.' : `Cooldown ramas: ${timeFmtHMS(selectedRace.cooldownLeft)}`;
    } else if (selectedRace && selectedVehicle) {
        selectedTitle.textContent = `${selectedRace.label} cu ${selectedVehicle.name || selectedVehicle.model}`;
        selectedSub.textContent = raceReady ? `${money(selectedRace.rewardMin)} - ${money(selectedRace.rewardMax)} • timp ${timeFmt(selectedRace.timeLimit)}` : `Cooldown ramas: ${timeFmt(selectedRace.cooldownLeft)}`;
    } else if (selectedRace) {
        selectedTitle.textContent = selectedRace.label;
        selectedSub.textContent = raceReady ? 'Selecteaza o masina pentru livrare.' : `Cooldown ramas: ${selectedRace.special ? timeFmtHMS(selectedRace.cooldownLeft) : timeFmt(selectedRace.cooldownLeft)}`;
    } else {
        selectedTitle.textContent = 'Nimic selectat';
        selectedSub.textContent = 'Alege o livrare si o masina pentru start.';
    }
    startBtn.disabled = !ok;
}
function startRace() {
    if (!selectedRace) return;
    startBtn.disabled = true;
    nui('start', { raceId: selectedRace.id, vehicleId: selectedVehicle ? vehicleIdOf(selectedVehicle) : null });
}
function setInviteError(message) {
    if (!inviteError) return;
    inviteError.textContent = String(message || '');
    inviteError.classList.toggle('hidden', !message);
}
function closeInvite() {
    inviteMenu.classList.add('hidden');
    setInviteError('');
    if (inviteBtn) inviteBtn.disabled = false;
    nui('close');
}
function sendInvite() {
    const targetUid = Number(String(friendId.value || '').trim());
    if (!Number.isFinite(targetUid) || targetUid <= 0) { setInviteError('Pune un UID valid.'); return; }
    setInviteError('');
    if (inviteBtn) inviteBtn.disabled = true;
    nui('duoInvite', { targetUid });
}
function openDuoGarage(data) {
    duoSessionId = Number(data.sessionId || 0);
    duoVehicles = Array.isArray(data.vehicles) ? data.vehicles : [];
    duoSelectedVehicle = null;
    partnerName.textContent = String(data.partner || 'Player');
    readyState.textContent = 'WAITING';
    duoReadyBtn.disabled = true;
    renderVehicleList(duoVehicleList, duoVehicles, true);
    duoGarage.classList.remove('hidden');
}
function selectDuoVehicle(id) {
    duoSelectedVehicle = findVehicleById(duoVehicles, id);
    duoReadyBtn.disabled = !duoSelectedVehicle;
    renderVehicleList(duoVehicleList, duoVehicles, true);
}
function duoReady() {
    if (!duoSelectedVehicle) return;
    duoReadyBtn.disabled = true;
    readyState.textContent = 'READY';
    nui('duoReady', { sessionId: duoSessionId, vehicleId: vehicleIdOf(duoSelectedVehicle) });
}
function closeDuoGarage() { duoGarage.classList.add('hidden'); nui('close'); }
function animateNumber(el, from, to, prefix, suffix, duration) {
    from = Number(from || 0); to = Number(to || 0);
    const start = performance.now();
    function tick(now) {
        const p = Math.min(1, (now - start) / duration);
        const eased = 1 - Math.pow(1 - p, 3);
        const v = Math.floor(from + (to - from) * eased);
        el.textContent = `${prefix}${v.toLocaleString('en-US')}${suffix}`;
        if (p < 1) requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
}
function showReward(payload) {
    const d = payload || {};
    const totalCash = Number(d.totalCash || 0);
    const totalXp = Number(d.totalXp || 0);
    const p1Cash = Number(d.p1?.cash || 0);
    const p2Cash = Number(d.p2?.cash || 0);
    const p1Xp = Number(d.p1?.xp || 0);
    const p2Xp = Number(d.p2?.xp || 0);

    rewardP1Name.textContent = d.p1?.name || 'Player 1';
    rewardP2Name.textContent = d.p2?.name || 'Player 2';
    rewardTotal.textContent = money(totalCash);
    rewardTotalXp.textContent = `${totalXp.toLocaleString('en-US')} XP`;
    rewardP1Cash.textContent = '$0'; rewardP2Cash.textContent = '$0';
    rewardP1Xp.textContent = '0 XP'; rewardP2Xp.textContent = '0 XP';
    rewardScreen.classList.remove('hidden');

    setTimeout(() => {
        animateNumber(rewardTotal, totalCash, 0, '$', '', 2600);
        animateNumber(rewardP1Cash, 0, p1Cash, '$', '', 2600);
        animateNumber(rewardP2Cash, 0, p2Cash, '$', '', 2600);
    }, 700);
    setTimeout(() => {
        animateNumber(rewardTotalXp, totalXp, 0, '', ' XP', 2300);
        animateNumber(rewardP1Xp, 0, p1Xp, '', ' XP', 2300);
        animateNumber(rewardP2Xp, 0, p2Xp, '', ' XP', 2300);
    }, 3600);
}

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        if (!raceMenu.classList.contains('hidden')) closeMenu();
        if (!inviteMenu.classList.contains('hidden')) closeInvite();
        if (!duoGarage.classList.contains('hidden')) closeDuoGarage();
    }
});
window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'closeMenu') { raceMenu.classList.add('hidden'); stopCooldownTimer(); }
    if (data.action === 'openInvite') { raceMenu.classList.add('hidden'); stopCooldownTimer(); friendId.value = ''; setInviteError(''); if (inviteBtn) inviteBtn.disabled = false; inviteMenu.classList.remove('hidden'); setTimeout(() => friendId.focus(), 80); }
    if (data.action === 'duoInviteResult') {
        if (inviteBtn) inviteBtn.disabled = false;
        if (data.ok === true) { inviteMenu.classList.add('hidden'); setInviteError(''); nui('close'); }
        else { setInviteError(data.message || 'Nu s-a putut trimite invitatia.'); inviteMenu.classList.remove('hidden'); setTimeout(() => friendId.focus(), 50); }
    }
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
