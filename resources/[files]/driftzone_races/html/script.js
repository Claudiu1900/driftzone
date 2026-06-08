'use strict';

const app = document.getElementById('app');
const homeView = document.getElementById('homeView');
const createView = document.getElementById('createView');
const joinView = document.getElementById('joinView');
const partyView = document.getElementById('partyView');
const pageTitle = document.getElementById('pageTitle');
const pageSubtitle = document.getElementById('pageSubtitle');
const stepList = document.getElementById('stepList');
const stepIndex = document.getElementById('stepIndex');
const stepTitle = document.getElementById('stepTitle');
const stepHelp = document.getElementById('stepHelp');
const stepBody = document.getElementById('stepBody');
const nextBtn = document.getElementById('nextBtn');
const roomsList = document.getElementById('roomsList');
const joinTitle = document.getElementById('joinTitle');
const joinDesc = document.getElementById('joinDesc');
const joinForm = document.getElementById('joinForm');
const joinBtn = document.getElementById('joinBtn');
const partyTitle = document.getElementById('partyTitle');
const partyMeta = document.getElementById('partyMeta');
const partyPlayers = document.getElementById('partyPlayers');
const partyFee = document.getElementById('partyFee');
const membersList = document.getElementById('membersList');
const readyBtn = document.getElementById('readyBtn');
const toast = document.getElementById('toast');
const raceHud = document.getElementById('raceHud');
const hudDir = document.getElementById('hudDir');
const hudCp = document.getElementById('hudCp');
const countdown = document.getElementById('countdown');
const countText = document.getElementById('countText');
const finishScreen = document.getElementById('finishScreen');
const finishState = document.getElementById('finishState');
const finishWinner = document.getElementById('finishWinner');
const finishMoney = document.getElementById('finishMoney');

const steps = [
    { title: 'Select Race', help: 'Alege tipul de cursa.' },
    { title: 'Max Players', help: 'Alege cati playeri pot intra.' },
    { title: 'Privacy', help: 'Public sau privat cu parola/PIN.' },
    { title: 'Entry Fee', help: 'Suma platita de fiecare player.' },
    { title: 'Vehicle', help: 'Alege masina compatibila.' }
];

let view = 'home';
let races = [];
let rooms = [];
let vehiclesByRace = {};
let createStep = 0;
let createData = cleanCreateData();
let selectedRoom = null;
let joinVehicleId = null;
let currentRoom = null;
let myReady = false;
let roomsTimer = null;
let partyHiddenByEsc = false;
let busyCreate = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function cleanCreateData() {
    return { raceId: null, maxPlayers: 2, private: false, password: '', pin: '', entryFee: 50000, vehicleId: null };
}
function esc(v) { return String(v ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#039;'); }
function money(v) { return '$' + Number(v || 0).toLocaleString('en-US'); }
function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }
function setMainColor(color) { if (color) document.documentElement.style.setProperty('--main', color); }
function getRace(id) { return races.find(r => String(r.id) === String(id)) || null; }
function currentRace() { return getRace(createData.raceId); }
function selectedRoomRace() { return selectedRoom ? getRace(selectedRoom.raceId) : null; }
function ensureVehicles(raceId) { if (raceId && !vehiclesByRace[raceId]) nui('getVehicles', { raceId }); }

function notifyUi(message, type = 'success') {
    toast.textContent = message;
    toast.className = `toast ${type}`;
    setTimeout(() => toast.classList.add('hidden'), 2600);
}

function setView(next) {
    view = next;
    [homeView, createView, joinView, partyView].forEach(hide);
    if (next === 'home') { show(homeView); pageTitle.textContent = 'Street Races'; pageSubtitle.textContent = 'Creeaza sau intra intr-un race public/privat cu buy-in.'; }
    if (next === 'create') { show(createView); pageTitle.textContent = 'Create Race'; pageSubtitle.textContent = 'Configureaza lobby-ul pas cu pas.'; }
    if (next === 'join') { show(joinView); pageTitle.textContent = 'Join Race'; pageSubtitle.textContent = 'Alege un lobby activ si masina compatibila.'; }
    if (next === 'party') { show(partyView); pageTitle.textContent = 'Race Party'; pageSubtitle.textContent = 'Asteapta playerii si pregateste startul.'; }
}

function openApp(payload) {
    races = Array.isArray(payload.races) ? payload.races : [];
    rooms = Array.isArray(payload.rooms) ? payload.rooms : [];
    vehiclesByRace = {};
    currentRoom = null;
    partyHiddenByEsc = false;
    busyCreate = false;
    setMainColor(payload.mainColor);
    show(app);
    setView('home');
    renderJoinRooms();
}

function closeUi() {
    if (view === 'party' && currentRoom) partyHiddenByEsc = true;
    hide(app);
    stopRoomRefresh();
    nui('close');
}

function goHome() { partyHiddenByEsc = false; stopRoomRefresh(); setView('home'); }
function goCreate() { busyCreate = false; createStep = 0; createData = cleanCreateData(); setView('create'); renderCreate(); }
function goJoin() { selectedRoom = null; joinVehicleId = null; setView('join'); refreshRooms(); startRoomRefresh(); renderJoinRooms(); renderJoinForm(); }

function renderSteps() {
    stepList.innerHTML = steps.map((s, i) => `
        <button class="step ${i === createStep ? 'active' : ''} ${i < createStep ? 'done' : ''}" onclick="jumpStep(${i})">
            <span>${String(i + 1).padStart(2, '0')}</span>
            <b>${esc(s.title)}</b>
        </button>
    `).join('');
}
function jumpStep(i) { if (i <= createStep && !busyCreate) { createStep = i; renderCreate(); } }

function updateSummary() {
    const r = currentRace();
    document.getElementById('sumRace').textContent = r ? r.label : 'Neselectat';
    document.getElementById('sumDesc').textContent = r ? r.description : 'Configureaza cursa pas cu pas.';
    document.getElementById('sumMax').textContent = createData.maxPlayers || '-';
    document.getElementById('sumFee').textContent = money(createData.entryFee || 0);
    document.getElementById('sumType').textContent = r ? String(r.type || '-').toUpperCase() : '-';
    document.getElementById('sumPrivacy').textContent = createData.private ? 'PRIVATE' : 'PUBLIC';
}

function renderCreate() {
    renderSteps(); updateSummary();
    const step = steps[createStep];
    stepIndex.textContent = String(createStep + 1).padStart(2, '0');
    stepTitle.textContent = step.title;
    stepHelp.textContent = step.help;
    nextBtn.textContent = createStep === steps.length - 1 ? (busyCreate ? 'Creating...' : 'Create Party') : 'Next';
    nextBtn.disabled = busyCreate;

    if (createStep === 0) renderRaceStep();
    if (createStep === 1) renderMaxStep();
    if (createStep === 2) renderPrivacyStep();
    if (createStep === 3) renderFeeStep();
    if (createStep === 4) renderVehicleStep();
}
function renderRaceStep() {
    stepBody.innerHTML = `<div class="card-grid race-grid">${races.map(r => `
        <button class="setup-card ${createData.raceId === r.id ? 'selected' : ''}" onclick="selectCreateRace('${esc(r.id)}')">
            <span>${esc(String(r.type || 'race').toUpperCase())}</span>
            <b>${esc(r.label)}</b>
            <p>${esc(r.description)}</p>
            <div class="meta"><small>Max ${r.maxPlayers}</small><small>${r.checkpoints} CP</small><small>XP W ${Number(r.winnerXp || 0)} / L ${Number(r.loserXp || 0)}</small></div>
        </button>
    `).join('')}</div>`;
}
function selectCreateRace(id) {
    createData.raceId = id;
    createData.vehicleId = null;
    const r = currentRace();
    createData.maxPlayers = Math.max(Number(r?.minPlayers || 2), 2);
    ensureVehicles(id);
    renderCreate();
}
function renderMaxStep() {
    const r = currentRace();
    const max = Number(r?.maxPlayers || 4);
    let buttons = '';
    for (let i = 2; i <= max; i++) buttons += `<button class="number-pill ${createData.maxPlayers === i ? 'selected' : ''}" onclick="createData.maxPlayers=${i};renderCreate();">${i}</button>`;
    stepBody.innerHTML = `<div class="center-box"><h2>Cati jucatori maxim?</h2><p>Lobby-ul porneste cu minim 2 playeri.</p><div class="pill-row">${buttons}</div></div>`;
}
function renderPrivacyStep() {
    stepBody.innerHTML = `<div class="center-box"><h2>Privacy</h2><p>Alege public sau privat. Pentru privat poti pune parola sau PIN.</p>
        <div class="split-cards">
            <button class="setup-card ${!createData.private ? 'selected' : ''}" onclick="createData.private=false;renderCreate();"><span>OPEN</span><b>Public</b><p>Visible pentru toti playerii.</p></button>
            <button class="setup-card ${createData.private ? 'selected' : ''}" onclick="createData.private=true;renderCreate();"><span>LOCKED</span><b>Privat</b><p>Necesita parola sau PIN.</p></button>
        </div>
        ${createData.private ? `<div class="private-form"><input placeholder="Parola privata" value="${esc(createData.password)}" oninput="createData.password=this.value"><div class="pin-row">${[0,1,2,3].map(i => `<input maxlength="1" inputmode="numeric" value="${esc((createData.pin || '')[i] || '')}" oninput="pinInput(${i}, this)">`).join('')}</div></div>` : ''}
    </div>`;
}
function pinInput(i, el) {
    const chars = (createData.pin || '').padEnd(4, ' ').split('');
    chars[i] = String(el.value || '').replace(/\D/g, '').slice(0, 1);
    createData.pin = chars.join('').replace(/\s/g, '');
    if (el.value && el.nextElementSibling) el.nextElementSibling.focus();
}
function renderFeeStep() {
    stepBody.innerHTML = `<div class="center-box"><h2>Suma de intrare</h2><p>Fiecare player plateste suma. Castigatorul ia potul minus taxa.</p><input class="fee-input" type="number" value="${Number(createData.entryFee || 0)}" oninput="createData.entryFee=Number(this.value||0);updateSummary();"><div class="quick-row">${[10000,25000,50000,100000].map(v => `<button onclick="createData.entryFee=${v};renderCreate();">${money(v)}</button>`).join('')}</div></div>`;
}
function renderVehicleStep() {
    const r = currentRace();
    if (!r) { stepBody.innerHTML = '<div class="empty">Alege prima data o cursa.</div>'; return; }
    ensureVehicles(r.id);
    const list = vehiclesByRace[r.id] || [];
    stepBody.innerHTML = `<div class="vehicle-grid">${list.length ? list.map(v => vehicleCard(v, createData.vehicleId, 'selectCreateVehicle')).join('') : '<div class="empty">Nu ai masini compatibile pentru acest race.</div>'}</div>`;
}
function vehicleCard(v, selectedId, fn) {
    return `<button class="vehicle-card ${Number(selectedId) === Number(v.id) ? 'selected' : ''}" onclick="${fn}(${Number(v.id)})"><b>${esc(v.name || v.model)}</b><span>${esc(v.model || 'model')}</span><small>${esc(v.plate || 'DRIFT')}</small></button>`;
}
function selectCreateVehicle(id) { createData.vehicleId = id; renderCreate(); }
function prevCreate() { if (busyCreate) return; if (createStep > 0) { createStep--; renderCreate(); } else goHome(); }
function nextCreate() {
    if (busyCreate) return;
    if (createStep === 0 && !createData.raceId) return notifyUi('Alege o cursa.', 'error');
    if (createStep === 2 && createData.private && !createData.password && String(createData.pin || '').length !== 4) return notifyUi('Pune parola sau PIN de 4 cifre.', 'error');
    if (createStep === 3 && (!createData.entryFee || createData.entryFee < 1)) return notifyUi('Pune o suma valida.', 'error');
    if (createStep === 4) {
        if (!createData.vehicleId) return notifyUi('Alege o masina.', 'error');
        busyCreate = true;
        nextBtn.disabled = true;
        nextBtn.textContent = 'Creating...';
        notifyUi('Se creeaza party-ul...', 'success');
        nui('createRoom', createData);
        setTimeout(() => { busyCreate = false; if (view === 'create') renderCreate(); }, 4500);
        return;
    }
    createStep++;
    renderCreate();
}

function refreshRooms() { nui('refreshRooms'); }
function startRoomRefresh() { stopRoomRefresh(); roomsTimer = setInterval(() => { if (view === 'join') refreshRooms(); }, 3500); }
function stopRoomRefresh() { if (roomsTimer) clearInterval(roomsTimer); roomsTimer = null; }
function renderJoinRooms() {
    if (!rooms.length) {
        roomsList.innerHTML = '<div class="empty">Nu exista race-uri active momentan.</div>';
        return;
    }
    roomsList.innerHTML = rooms.map(room => `<button class="room-card ${selectedRoom && selectedRoom.id === room.id ? 'selected' : ''}" onclick="selectRoom(${Number(room.id)})"><span>${room.private ? 'PRIVATE' : 'PUBLIC'} • ${esc(String(room.raceType || '').toUpperCase())}</span><b>#${room.id} ${esc(room.raceLabel)}</b><p>Host: ${esc(room.ownerName)} • ${room.players}/${room.maxPlayers} players</p><div class="meta"><small>${money(room.entryFee)} entry</small><small>${room.checkpoints} CP</small></div></button>`).join('');
}
function selectRoom(id) {
    selectedRoom = rooms.find(r => Number(r.id) === Number(id)) || null;
    joinVehicleId = null;
    if (!selectedRoom) return;
    ensureVehicles(selectedRoom.raceId);
    joinTitle.textContent = `#${selectedRoom.id} ${selectedRoom.raceLabel}`;
    joinDesc.textContent = `${selectedRoom.players}/${selectedRoom.maxPlayers} players • ${money(selectedRoom.entryFee)} entry`;
    renderJoinRooms();
    renderJoinForm();
}
function renderJoinForm() {
    if (!selectedRoom) { hide(joinForm); joinBtn.disabled = true; return; }
    show(joinForm);
    const list = vehiclesByRace[selectedRoom.raceId] || [];
    joinForm.innerHTML = `${selectedRoom.private ? `<input id="joinPass" class="join-input" placeholder="Parola"><div class="pin-row join-pin">${[0,1,2,3].map(() => '<input maxlength="1" inputmode="numeric">').join('')}</div>` : ''}<div class="mini-title">Masina compatibila</div><div class="join-vehicles">${list.length ? list.map(v => vehicleCard(v, joinVehicleId, 'selectJoinVehicle')).join('') : '<div class="empty">Nu ai masini compatibile.</div>'}</div>`;
    joinBtn.disabled = !joinVehicleId;
}
function selectJoinVehicle(id) { joinVehicleId = id; renderJoinForm(); }
function joinSelectedRoom() {
    if (!selectedRoom || !joinVehicleId) return;
    const pass = document.getElementById('joinPass')?.value || '';
    const pin = [...document.querySelectorAll('.join-pin input')].map(i => i.value || '').join('');
    notifyUi('Se verifica party-ul...', 'success');
    nui('joinRoom', { roomId: selectedRoom.id, vehicleId: joinVehicleId, password: pass, pin });
}

function renderRoom(room, message = '') {
    if (!room) return;
    currentRoom = room;
    partyHiddenByEsc = false;
    busyCreate = false;
    show(app);
    setView('party');
    partyTitle.textContent = `#${room.id} ${room.raceLabel}`;
    partyPlayers.textContent = `${room.members.length}/${room.maxPlayers}`;
    partyFee.textContent = money(room.entryFee);
    partyMeta.textContent = `${room.private ? 'Private' : 'Public'} • start cand toti sunt READY / lobby plin / timer expira`;
    myReady = room.meReady === true;
    readyBtn.textContent = myReady ? 'READY ✓' : 'READY';
    readyBtn.classList.toggle('ready', myReady);
    membersList.innerHTML = room.members.map(m => `<div class="member ${m.ready ? 'ready' : ''}"><div><b>${esc(m.name)}</b><span>UID ${m.uid}${m.owner ? ' • Host' : ''}</span></div><em>${m.ready ? 'READY' : 'WAITING'}</em></div>`).join('');
    if (message) notifyUi(message, 'success');
}
function updateRoom(room) {
    currentRoom = room;
    if (partyHiddenByEsc && view === 'party') return;
    renderRoom(room, '');
}
function toggleReady() { myReady = !myReady; nui('readyRoom', { ready: myReady }); }
function leaveRoom() { nui('leaveRoom'); }
function dirIcon(direction) { if (direction === 'left') return '↰'; if (direction === 'right') return '↱'; if (direction === 'finish') return '🏁'; return '↑'; }

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.mainColor) setMainColor(data.mainColor);

    if (data.action === 'open') openApp(data);
    if (data.action === 'close') hide(app);
    if (data.action === 'vehicles') {
        vehiclesByRace[data.raceId] = Array.isArray(data.vehicles) ? data.vehicles : [];
        if (view === 'create') renderCreate();
        if (view === 'join') renderJoinForm();
    }
    if (data.action === 'rooms') {
        rooms = Array.isArray(data.rooms) ? data.rooms : [];
        if (view === 'join') renderJoinRooms();
    }
    if (data.action === 'room') {
        stopRoomRefresh();
        if (data.forceOpen === true) renderRoom(data.room, data.message || '');
        else updateRoom(data.room);
    }
    if (data.action === 'forceRoom') {
        stopRoomRefresh();
        renderRoom(data.room, data.message || 'Party-ul a fost creat cu succes.');
    }
    if (data.action === 'leftRoom') {
        currentRoom = null;
        partyHiddenByEsc = false;
        notifyUi('Ai iesit din party.', 'success');
        goHome();
    }
    if (data.action === 'raceHud') {
        raceHud.classList.toggle('hidden', data.visible !== true);
        hudDir.textContent = dirIcon(data.direction);
        hudCp.textContent = `${data.index || 1}/${data.total || 1}`;
    }
    if (data.action === 'countdown') {
        countdown.classList.toggle('hidden', data.visible !== true);
        countText.textContent = data.text || '';
    }
    if (data.action === 'finishScreen') {
        const result = data.result || {};
        finishState.textContent = result.won ? 'VICTORY' : 'RACE FINISHED';
        finishWinner.textContent = result.winnerName || 'Winner';
        finishMoney.textContent = result.won ? `+${money(result.prize)} • +${Number(result.xp || 0).toLocaleString('en-US')} XP` : `Winner prize: ${money(result.prize)} • +${Number(result.xp || 0).toLocaleString('en-US')} XP`;
        show(finishScreen);
        setTimeout(() => hide(finishScreen), 2400);
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !app.classList.contains('hidden')) closeUi();
});

setTimeout(() => nui('ready'), 80);
