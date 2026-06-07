'use strict';

const app = document.getElementById('app');
const home = document.getElementById('home');
const createView = document.getElementById('create');
const joinView = document.getElementById('join');
const lobbyView = document.getElementById('lobby');
const createBody = document.getElementById('createBody');
const createTitle = document.getElementById('createTitle');
const createStepNumber = document.getElementById('createStepNumber');
const createSteps = document.getElementById('createSteps');
const createNext = document.getElementById('createNext');
const roomsList = document.getElementById('roomsList');
const joinForm = document.getElementById('joinForm');
const joinBtn = document.getElementById('joinBtn');
const joinTitle = document.getElementById('joinTitle');
const joinDesc = document.getElementById('joinDesc');
const members = document.getElementById('members');
const lobbyTitle = document.getElementById('lobbyTitle');
const lobbyPlayers = document.getElementById('lobbyPlayers');
const lobbyMeta = document.getElementById('lobbyMeta');
const lobbyFee = document.getElementById('lobbyFee');
const readyBtn = document.getElementById('readyBtn');
const raceHud = document.getElementById('raceHud');
const hudDir = document.getElementById('hudDir');
const hudCp = document.getElementById('hudCp');
const countdown = document.getElementById('countdown');
const countText = document.getElementById('countText');
const finishScreen = document.getElementById('finishScreen');
const finishState = document.getElementById('finishState');
const finishWinner = document.getElementById('finishWinner');
const finishMoney = document.getElementById('finishMoney');

const steps = ['Select Race', 'Max Players', 'Privacy', 'Entry Fee', 'Vehicle'];
let races = [];
let rooms = [];
let vehiclesByRace = {};
let mode = 'home';
let createStep = 0;
let createData = { raceId: null, maxPlayers: 2, private: false, password: '', pin: '', entryFee: 50000, vehicleId: null };
let selectedJoinRoom = null;
let joinVehicleId = null;
let myReady = false;
let roomRefreshTimer = null;
let suppressLobbyUpdates = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}
function money(v) { return '$' + Number(v || 0).toLocaleString('en-US'); }
function esc(v) { return String(v ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#039;'); }
function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }
function setView(v) {
    mode = v;
    [home, createView, joinView, lobbyView].forEach(hide);
    if (v === 'home') show(home);
    if (v === 'create') show(createView);
    if (v === 'join') show(joinView);
    if (v === 'lobby') show(lobbyView);
}
function goHome(){ suppressLobbyUpdates = false; setView('home'); }
function goCreate(){ createStep = 0; createData = { raceId: null, maxPlayers: 2, private: false, password: '', pin: '', entryFee: 50000, vehicleId: null }; setView('create'); renderCreate(); }
function goJoin(){ setView('join'); selectedJoinRoom = null; joinVehicleId = null; refreshRooms(); startRoomRefresh(); renderJoin(); }
function closeUi(){ if(mode === 'lobby') suppressLobbyUpdates = true; app.classList.add('hidden'); stopRoomRefresh(); nui('close'); }
function startRoomRefresh(){ stopRoomRefresh(); roomRefreshTimer = setInterval(() => { if(mode === 'join') nui('refreshRooms'); }, 3500); }
function stopRoomRefresh(){ if(roomRefreshTimer) clearInterval(roomRefreshTimer); roomRefreshTimer = null; }

function currentRace(){ return races.find(r => String(r.id) === String(createData.raceId)); }
function selectedRoomRace(){ return selectedJoinRoom ? races.find(r => String(r.id) === String(selectedJoinRoom.raceId)) : null; }
function ensureVehicles(raceId){ if(!vehiclesByRace[raceId]) nui('getVehicles', { raceId }); }

function renderSteps(){
    createSteps.innerHTML = steps.map((s,i)=>`<button class="step ${i===createStep?'active':''} ${i<createStep?'done':''}" onclick="jumpStep(${i})"><span>${String(i+1).padStart(2,'0')}</span>${esc(s)}</button>`).join('');
}
function jumpStep(i){ if(i <= createStep) { createStep = i; renderCreate(); } }
function updateSummary(){
    const r = currentRace();
    document.getElementById('sumRace').textContent = r ? r.label : 'Neselectat';
    document.getElementById('sumInfo').textContent = r ? r.description : 'Configureaza cursa pas cu pas.';
    document.getElementById('sumMax').textContent = createData.maxPlayers || '-';
    document.getElementById('sumFee').textContent = money(createData.entryFee || 0);
    document.getElementById('sumType').textContent = r ? String(r.type).toUpperCase() : '-';
    document.getElementById('sumPrivacy').textContent = createData.private ? 'PRIVATE' : 'PUBLIC';
}
function renderCreate(){
    renderSteps(); updateSummary();
    createTitle.textContent = steps[createStep];
    createStepNumber.textContent = String(createStep + 1).padStart(2,'0');
    createNext.textContent = createStep === steps.length - 1 ? 'Create Race' : 'Next';
    if(createStep === 0) renderRaceStep();
    if(createStep === 1) renderMaxStep();
    if(createStep === 2) renderPrivacyStep();
    if(createStep === 3) renderFeeStep();
    if(createStep === 4) renderVehicleStep();
}
function renderRaceStep(){
    createBody.innerHTML = `<div class="cards-list">${races.map(r=>`<button class="select-card ${createData.raceId===r.id?'selected':''}" onclick="selectCreateRace('${esc(r.id)}')"><span>${esc(String(r.type).toUpperCase())}</span><b>${esc(r.label)}</b><p>${esc(r.description)}</p><div><small>Max ${r.maxPlayers} players</small><small>${r.checkpoints} CP</small></div></button>`).join('')}</div>`;
}
function selectCreateRace(id){
    createData.raceId = id;
    createData.vehicleId = null;
    const r = currentRace();
    createData.maxPlayers = Math.max(2, Number(r?.minPlayers || 2));
    ensureVehicles(id);
    renderCreate();
}
function renderMaxStep(){
    const r = currentRace();
    const max = Number(r?.maxPlayers || 4);
    let buttons = '';
    for(let i=2;i<=max;i++) buttons += `<button class="pill ${createData.maxPlayers===i?'selected':''}" onclick="createData.maxPlayers=${i};renderCreate();">${i}</button>`;
    createBody.innerHTML = `<div class="center-box"><h2>Cati jucatori maxim?</h2><p>Race-ul porneste cu minim 2 jucatori si maxim ${max}.</p><div class="pill-row">${buttons}</div></div>`;
}
function renderPrivacyStep(){
    createBody.innerHTML = `<div class="center-box"><h2>Public sau privat?</h2><p>Privat necesita parola sau PIN de 4 cifre.</p><div class="split"><button class="select-card ${!createData.private?'selected':''}" onclick="createData.private=false;renderCreate();"><span>OPEN</span><b>Public</b><p>Oricine poate intra.</p></button><button class="select-card ${createData.private?'selected':''}" onclick="createData.private=true;renderCreate();"><span>LOCK</span><b>Privat</b><p>Necesita parola/PIN.</p></button></div>${createData.private?`<div class="private-box"><input id="passInput" placeholder="Parola privata" value="${esc(createData.password)}" oninput="createData.password=this.value"><div class="pin-row">${[0,1,2,3].map(i=>`<input class="pin" maxlength="1" inputmode="numeric" value="${esc((createData.pin||'')[i]||'')}" oninput="pinInput(${i},this)">`).join('')}</div></div>`:''}</div>`;
}
function pinInput(i, el){
    const chars = (createData.pin || '').padEnd(4, ' ').split('');
    chars[i] = String(el.value || '').replace(/\D/g,'').slice(0,1);
    createData.pin = chars.join('').replace(/\s/g,'');
    if(el.value && el.nextElementSibling) el.nextElementSibling.focus();
}
function renderFeeStep(){
    createBody.innerHTML = `<div class="center-box"><h2>Suma de intrare</h2><p>Fiecare jucator plateste suma. Winner primeste potul total minus 10%.</p><input class="fee-input" type="number" value="${Number(createData.entryFee||0)}" oninput="createData.entryFee=Number(this.value||0);updateSummary();" placeholder="Ex: 50000"><div class="quick-row">${[10000,25000,50000,100000].map(v=>`<button onclick="createData.entryFee=${v};renderCreate();">${money(v)}</button>`).join('')}</div></div>`;
}
function renderVehicleStep(){
    const r = currentRace(); if(!r){ createBody.innerHTML='<div class="empty">Alege prima data o cursa.</div>'; return; }
    ensureVehicles(r.id);
    const list = vehiclesByRace[r.id] || [];
    createBody.innerHTML = `<div class="vehicle-grid">${list.length?list.map(v=>vehicleCard(v, createData.vehicleId, 'selectCreateVehicle')).join(''):'<div class="empty">Nu ai masini compatibile pentru acest tip de race.</div>'}</div>`;
}
function vehicleCard(v, selectedId, fn){
    return `<button class="vehicle ${Number(selectedId)===Number(v.id)?'selected':''}" onclick="${fn}(${Number(v.id)})"><b>${esc(v.name||v.model)}</b><span>${esc(v.model||'model')}</span><small>${esc(v.plate||'DRIFT')}</small></button>`;
}
function selectCreateVehicle(id){ createData.vehicleId = id; renderCreate(); }
function prevCreate(){ if(createStep>0){createStep--; renderCreate();} else goHome(); }
function nextCreate(){
    if(createStep===0 && !createData.raceId) return alertBox('Alege o cursa.');
    if(createStep===2 && createData.private && !createData.password && String(createData.pin||'').length!==4) return alertBox('Pune parola sau PIN de 4 cifre.');
    if(createStep===3 && (!createData.entryFee || createData.entryFee < 1)) return alertBox('Pune o suma valida.');
    if(createStep===4){ if(!createData.vehicleId) return alertBox('Alege o masina.'); nui('createRoom', createData); return; }
    createStep++; renderCreate();
}
function alertBox(msg){ createBody.insertAdjacentHTML('afterbegin', `<div class="notice">${esc(msg)}</div>`); setTimeout(()=>document.querySelector('.notice')?.remove(),2200); }

function refreshRooms(){ nui('refreshRooms'); }
function renderJoin(){
    roomsList.innerHTML = rooms.length ? rooms.map(room=>`<button class="select-card ${selectedJoinRoom&&selectedJoinRoom.id===room.id?'selected':''}" onclick="selectRoom(${room.id})"><span>${room.private?'PRIVATE':'PUBLIC'} • ${esc(String(room.raceType).toUpperCase())}</span><b>#${room.id} ${esc(room.raceLabel)}</b><p>Host: ${esc(room.ownerName)} • ${room.players}/${room.maxPlayers} players</p><div><small>${money(room.entryFee)} entry</small><small>${room.checkpoints} CP</small></div></button>`).join('') : '<div class="empty">Nu exista race-uri active momentan.</div>';
}
function selectRoom(id){
    selectedJoinRoom = rooms.find(r=>Number(r.id)===Number(id));
    joinVehicleId = null;
    if(!selectedJoinRoom) return;
    ensureVehicles(selectedJoinRoom.raceId);
    joinTitle.textContent = `#${selectedJoinRoom.id} ${selectedJoinRoom.raceLabel}`;
    joinDesc.textContent = `${selectedJoinRoom.players}/${selectedJoinRoom.maxPlayers} players • ${money(selectedJoinRoom.entryFee)} entry`;
    renderJoinForm(); renderJoin();
}
function renderJoinForm(){
    if(!selectedJoinRoom){ hide(joinForm); joinBtn.disabled=true; return; }
    show(joinForm);
    const list = vehiclesByRace[selectedJoinRoom.raceId] || [];
    joinForm.innerHTML = `${selectedJoinRoom.private?`<input id="joinPass" placeholder="Parola"><div class="pin-row join-pin">${[0,1,2,3].map(i=>`<input class="pin" maxlength="1" inputmode="numeric">`).join('')}</div>`:''}<div class="mini-title">Alege masina</div><div class="join-vehicles">${list.length?list.map(v=>vehicleCard(v, joinVehicleId, 'selectJoinVehicle')).join(''):'<div class="empty">Nu ai masini compatibile.</div>'}</div>`;
    joinBtn.disabled = !joinVehicleId;
}
function selectJoinVehicle(id){ joinVehicleId=id; renderJoinForm(); }
function joinSelectedRoom(){
    if(!selectedJoinRoom || !joinVehicleId) return;
    const pass = document.getElementById('joinPass')?.value || '';
    const pin = [...document.querySelectorAll('.join-pin .pin')].map(i=>i.value||'').join('');
    nui('joinRoom', { roomId: selectedJoinRoom.id, vehicleId: joinVehicleId, password: pass, pin });
}

function renderRoom(room){
    currentRoom = room; setView('lobby');
    lobbyTitle.textContent = `#${room.id} ${room.raceLabel}`;
    lobbyPlayers.textContent = `${room.members.length}/${room.maxPlayers}`;
    lobbyFee.textContent = money(room.entryFee);
    lobbyMeta.textContent = `${room.private?'Private':'Public'} • start automat cand toti sunt ready / lobby plin / timer expira`;
    myReady = room.meReady === true;
    readyBtn.textContent = myReady ? 'READY ✓' : 'READY';
    readyBtn.classList.toggle('ready', myReady);
    members.innerHTML = room.members.map(m=>`<div class="member ${m.ready?'ready':''}"><div><b>${esc(m.name)}</b><span>UID ${m.uid}${m.owner?' • Host':''}</span></div><em>${m.ready?'READY':'WAITING'}</em></div>`).join('');
}
function toggleReady(){ myReady = !myReady; nui('readyRoom', { ready: myReady }); }
function leaveRoom(){ nui('leaveRoom'); }

function dirIcon(d){ if(d==='left')return '↰'; if(d==='right')return '↱'; if(d==='finish')return '🏁'; return '↑'; }

window.addEventListener('message', (event)=>{
    const data = event.data || {};
    if(data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
    if(data.action==='open'){
        races = Array.isArray(data.races)?data.races:[];
        rooms = Array.isArray(data.rooms)?data.rooms:[];
        vehiclesByRace = {};
        suppressLobbyUpdates = false; show(app); setView('home'); renderJoin();
    }
    if(data.action==='close'){ hide(app); }
    if(data.action==='vehicles'){
        vehiclesByRace[data.raceId] = Array.isArray(data.vehicles)?data.vehicles:[];
        if(mode==='create') renderCreate();
        if(mode==='join') renderJoinForm();
    }
    if(data.action==='rooms'){ rooms = Array.isArray(data.rooms)?data.rooms:[]; if(mode==='join') renderJoin(); }
    if(data.action==='room'){
        stopRoomRefresh();
        currentRoom = data.room || null;
        if(suppressLobbyUpdates && mode === 'lobby') {
            return;
        }
        suppressLobbyUpdates = false;
        show(app);
        renderRoom(data.room);
    }
    if(data.action==='leftRoom'){ currentRoom=null; suppressLobbyUpdates=false; goHome(); }
    if(data.action==='raceHud'){
        raceHud.classList.toggle('hidden', data.visible!==true);
        hudDir.textContent = dirIcon(data.direction);
        hudCp.textContent = `${data.index||1}/${data.total||1}`;
    }
    if(data.action==='countdown'){
        countdown.classList.toggle('hidden', data.visible!==true);
        countText.textContent = data.text || '';
    }
    if(data.action==='finishScreen'){
        const r = data.result || {};
        finishState.textContent = r.won ? 'VICTORY' : 'RACE FINISHED';
        finishWinner.textContent = r.winnerName || 'Winner';
        finishMoney.textContent = r.won ? `+${money(r.prize)}` : `Winner prize: ${money(r.prize)}`;
        show(finishScreen);
        setTimeout(()=>hide(finishScreen), 2300);
    }
});

document.addEventListener('keydown', (e)=>{
    if(e.key === 'Escape') {
        if(!app.classList.contains('hidden')) closeUi();
    }
});

setTimeout(()=>nui('ready'), 80);
