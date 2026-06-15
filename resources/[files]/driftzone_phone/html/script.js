'use strict';

const root = document.getElementById('phoneRoot');
const screens = {
    home: document.getElementById('homeScreen'),
    dial: document.getElementById('dialScreen'),
    contacts: document.getElementById('contactsScreen'),
    calls: document.getElementById('callsScreen'),
    messages: document.getElementById('messagesScreen'),
    conversation: document.getElementById('conversationScreen'),
    call: document.getElementById('callScreen'),
    peek: document.getElementById('peekScreen')
};
const statusTime = document.getElementById('statusTime');
const audio = {
    ring: document.getElementById('ringSound'),
    ring2: document.getElementById('ring2Sound'),
    decline: document.getElementById('declineSound'),
    message: document.getElementById('messageSound')
};

let state = { contacts: [], callHistory: [], messages: [] };
let activeScreen = 'home';
let stack = ['home'];
let focus = false;
let selectedContact = null;
let currentConversation = null;
let callOptions = { muted: false, speaker: false };
let timer = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function esc(v) {
    return String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}
function cleanNumber(v) { return String(v || '').replace(/[^0-9]/g, ''); }
function icon(name) { return `assets/icons/${name}.svg`; }
function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }
function displayName(number) {
    number = cleanNumber(number);
    const c = (state.contacts || []).find(x => cleanNumber(x.number) === number);
    return c ? c.name : number;
}
function play(name) {
    const a = audio[name];
    if (!a) return;
    try { a.currentTime = 0; a.play().catch(() => {}); } catch(e) {}
}
function stop(name) {
    const a = audio[name];
    if (!a) return;
    try { a.pause(); a.currentTime = 0; } catch(e) {}
}
function stopRings() { stop('ring'); stop('ring2'); }
function updateTime() {
    const d = new Date();
    statusTime.textContent = `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}
setInterval(updateTime, 1000); updateTime();

function switchScreen(name, push = true) {
    Object.values(screens).forEach(hide);
    show(screens[name] || screens.home);
    activeScreen = name;
    if (push && stack[stack.length - 1] !== name) stack.push(name);
    renderAll();
}
function back() {
    if (activeScreen === 'home') return closePhone();
    stack.pop();
    const prev = stack[stack.length - 1] || 'home';
    switchScreen(prev, false);
}
function homeBarAction() { back(); }
function closePhone() {
    root.classList.add('closing');
    setTimeout(() => { root.classList.add('hidden'); root.classList.remove('closing', 'open', 'peek', 'message-peek'); }, 210);
    nui('close');
}
function openPhone(screen = 'home') {
    root.classList.remove('hidden', 'closing', 'peek', 'message-peek');
    root.classList.add('open', 'opening');
    setTimeout(() => root.classList.remove('opening'), 250);
    stack = ['home'];
    switchScreen(screen || 'home', false);
}
function openPeek(kind, payload = {}) {
    root.classList.remove('hidden', 'closing', 'open');
    root.classList.add(kind === 'message' ? 'message-peek' : 'peek', 'opening');
    setTimeout(() => root.classList.remove('opening'), 250);
    stack = ['peek'];
    renderPeek(kind, payload);
    switchScreen('peek', false);
}
function setFocusUi(v) {
    focus = v === true;
    root.classList.toggle('no-focus', !focus);
}

function renderHome() {
    screens.home.innerHTML = `
        <div class="wallpaper-glow"></div>
        <div class="big-date">${statusTime.textContent}</div>
        <div class="apps">
            <button class="app app-phone" onclick="switchScreen('dial')"><img src="${icon('phone')}"><span>Telefon</span></button>
            <button class="app app-messages" onclick="switchScreen('messages')"><img src="${icon('messages')}"><span>Mesaje</span></button>
            <button class="app app-contacts" onclick="switchScreen('contacts')"><img src="${icon('contacts')}"><span>Contacte</span></button>
            <button class="app app-calls" onclick="switchScreen('calls')"><img src="${icon('calls')}"><span>Apeluri</span></button>
        </div>
        ${state.inCall ? `<button class="live-card" onclick="switchScreen('call')"><b>${state.incoming ? 'Te suna' : state.outgoing ? 'Apelezi' : 'Apel'}</b><span>${esc(state.otherName || state.otherNumber)}</span></button>` : ''}
    `;
}

function renderDial() {
    screens.dial.innerHTML = `
        <div class="app-head"><button onclick="back()"><img src="${icon('back')}"></button><b>Telefon</b><button onclick="switchScreen('calls')"><img src="${icon('calls')}"></button></div>
        <input id="dialInput" class="dial-input" placeholder="Numar telefon" inputmode="numeric">
        <div class="keypad">${['1','2','3','4','5','6','7','8','9','CLR','0','DEL'].map(k => `<button onclick="dialKey('${k}')">${k}</button>`).join('')}</div>
        <button class="main-call" onclick="dialNow()"><img src="${icon('call')}"> Suna</button>
    `;
}
function dialKey(k) {
    const i = document.getElementById('dialInput');
    if (!i) return;
    if (k === 'CLR') i.value = '';
    else if (k === 'DEL') i.value = cleanNumber(i.value).slice(0,-1);
    else i.value = cleanNumber(i.value + k);
}
function dialNow(number) {
    const n = cleanNumber(number || (document.getElementById('dialInput') || {}).value || '');
    if (!n) { play('decline'); return; }
    stopRings();
    nui('dial', { number: n });
    switchScreen('call');
}

function renderContacts() {
    const contacts = state.contacts || [];
    screens.contacts.innerHTML = `
        <div class="app-head"><button onclick="back()"><img src="${icon('back')}"></button><b>Contacte</b><button onclick="openContactForm()"><img src="${icon('plus')}"></button></div>
        <div class="list">${contacts.length ? contacts.map(c => `
            <button class="list-row" onclick="openContact(${c.id})">
                <span class="avatar">${esc((c.name || '?')[0])}</span><div><b>${esc(c.name)}</b><small>${esc(c.number)}${c.blocked ? ' • blocat' : ''}</small></div>
            </button>`).join('') : `<div class="empty">Nu ai contacte.</div>`}</div>
    `;
}
function openContact(id) { selectedContact = (state.contacts || []).find(c => Number(c.id) === Number(id)); renderContactDetail(); switchScreen('contacts', false); }
function renderContactDetail() {
    const c = selectedContact; if (!c) return renderContacts();
    screens.contacts.innerHTML = `
        <div class="app-head"><button onclick="renderContacts()"><img src="${icon('back')}"></button><b>${esc(c.name)}</b><button onclick="openContactForm(${c.id})"><img src="${icon('edit')}"></button></div>
        <div class="profile"><span>${esc((c.name || '?')[0])}</span><h2>${esc(c.name)}</h2><p>${esc(c.number)}</p></div>
        <div class="action-grid">
            <button onclick="dialNow('${esc(c.number)}')"><img src="${icon('call')}"><b>Suna</b></button>
            <button onclick="openConversation('${esc(c.number)}')"><img src="${icon('messages')}"><b>Mesaj</b></button>
            <button onclick="openContactForm(${c.id})"><img src="${icon('edit')}"><b>Edit</b></button>
            <button onclick="toggleBlock(${c.id})"><img src="${icon('block')}"><b>${c.blocked ? 'Unblock' : 'Block'}</b></button>
            <button class="danger" onclick="deleteContact(${c.id})"><img src="${icon('trash')}"><b>Sterge</b></button>
        </div>
    `;
}
function openContactForm(id = 0) {
    const c = id ? (state.contacts || []).find(x => Number(x.id) === Number(id)) : null;
    screens.contacts.innerHTML = `
        <div class="app-head"><button onclick="renderContacts()"><img src="${icon('back')}"></button><b>${c ? 'Edit contact' : 'Contact nou'}</b><span></span></div>
        <div class="form-card">
            <label>Nume<input id="contactName" value="${esc(c ? c.name : '')}" placeholder="Nume"></label>
            <label>Numar<input id="contactNumber" value="${esc(c ? c.number : '')}" placeholder="Numar telefon" inputmode="numeric"></label>
            <button class="primary" onclick="saveContact(${c ? c.id : 0})">Salveaza</button>
        </div>
    `;
}
function saveContact(id) { nui('saveContact', { id, name: document.getElementById('contactName').value, number: document.getElementById('contactNumber').value }); }
function toggleBlock(id) { nui('toggleBlock', { id }); }
function deleteContact(id) { nui('deleteContact', { id }); selectedContact = null; }

function renderCalls() {
    const rows = state.callHistory || [];
    screens.calls.innerHTML = `
        <div class="app-head"><button onclick="back()"><img src="${icon('back')}"></button><b>Apeluri</b><span></span></div>
        <div class="list">${rows.length ? rows.map(r => `<button class="list-row" onclick="dialNow('${esc(r.number)}')"><span class="call-dot ${r.status}"></span><div><b>${esc(r.name || r.number)}</b><small>${esc(r.direction)} • ${esc(r.status)} ${r.duration ? '• '+r.duration+'s' : ''}</small></div></button>`).join('') : `<div class="empty">Nu ai istoric de apeluri.</div>`}</div>
    `;
}

function getConversations() {
    const map = {};
    (state.messages || []).forEach(m => { map[m.otherNumber] = m; });
    return Object.values(map).sort((a,b) => Number(b.id)-Number(a.id));
}
function renderMessages() {
    const convs = getConversations();
    screens.messages.innerHTML = `
        <div class="app-head"><button onclick="back()"><img src="${icon('back')}"></button><b>Mesaje</b><button onclick="newMessage()"><img src="${icon('plus')}"></button></div>
        <div class="list">${convs.length ? convs.map(c => `<button class="list-row" onclick="openConversation('${esc(c.otherNumber)}')"><span class="avatar">${esc((c.otherName || c.otherNumber || '?')[0])}</span><div><b>${esc(c.otherName || c.otherNumber)}</b><small>${esc(c.type === 'location' ? 'Locatie partajata' : c.text)}</small></div></button>`).join('') : `<div class="empty">Nu ai mesaje.</div>`}</div>
    `;
}
function newMessage() {
    screens.messages.innerHTML = `<div class="app-head"><button onclick="renderMessages()"><img src="${icon('back')}"></button><b>Mesaj nou</b><span></span></div><div class="form-card"><label>Numar<input id="newMsgNumber" placeholder="Numar telefon"></label><button class="primary" onclick="openConversation(cleanNumber(document.getElementById('newMsgNumber').value))">Deschide</button></div>`;
}
function openConversation(number) { currentConversation = cleanNumber(number); renderConversation(); switchScreen('conversation'); }
function renderConversation() {
    const n = currentConversation; const name = displayName(n);
    const msgs = (state.messages || []).filter(m => cleanNumber(m.otherNumber) === n);
    screens.conversation.innerHTML = `
        <div class="app-head"><button onclick="switchScreen('messages')"><img src="${icon('back')}"></button><b>${esc(name)}</b><button onclick="dialNow('${esc(n)}')"><img src="${icon('call')}"></button></div>
        <div id="msgList" class="msg-list">${msgs.map(m => `<div class="bubble ${m.mine ? 'mine' : ''}">${m.type === 'location' ? `<button class="location-bubble" onclick='setWaypoint(${JSON.stringify(m.location || {})})'><img src="${icon('pin')}"> Seteaza waypoint</button>` : esc(m.text)}</div>`).join('')}</div>
        <div class="composer"><button onclick="shareLocation()"><img src="${icon('pin')}"></button><input id="msgInput" placeholder="Scrie mesaj"><button onclick="sendMessage()"><img src="${icon('send')}"></button></div>
    `;
    setTimeout(() => { const l = document.getElementById('msgList'); if (l) l.scrollTop = l.scrollHeight; }, 30);
}
function sendMessage() { const i = document.getElementById('msgInput'); const text = i ? i.value : ''; if (!text.trim()) return; nui('sendMessage', { number: currentConversation, text, type: 'text' }); if (i) i.value = ''; play('message'); }
function shareLocation() { nui('shareLocation', { number: currentConversation }); play('message'); }
function setWaypoint(loc) { nui('setWaypoint', { location: loc }); }

function renderCall() {
    const name = state.otherName || state.otherNumber || 'Necunoscut';
    let buttons = '';
    if (state.incoming) buttons = `<button class="round green" onclick="answer()"><img src="${icon('call')}"></button><button class="round red" onclick="decline()"><img src="${icon('hangup')}"></button>`;
    else if (state.inCall) buttons = `<button class="round ${callOptions.speaker ? 'active' : ''}" onclick="toggleSpeaker()"><img src="${icon('speaker')}"></button><button class="round ${callOptions.muted ? 'active redish' : ''}" onclick="toggleMute()"><img src="${icon('mute')}"></button><button class="round red" onclick="hangup()"><img src="${icon('hangup')}"></button>`;
    screens.call.innerHTML = `<div class="call-main"><div class="call-avatar">${esc(String(name)[0] || '?')}</div><h2>${esc(name)}</h2><p id="callTimer"></p><div class="call-actions">${buttons}</div></div>`;
    updateTimer();
}
function answer() { stopRings(); nui('answer'); switchScreen('call'); }
function decline() { stopRings(); nui('decline'); }
function hangup() { stopRings(); nui('hangup'); }
function toggleSpeaker() { callOptions.speaker = !callOptions.speaker; nui('setCallOptions', callOptions); renderCall(); }
function toggleMute() { callOptions.muted = !callOptions.muted; nui('setCallOptions', callOptions); renderCall(); }
function updateTimer() {
    if (timer) clearInterval(timer); timer = null;
    const el = () => document.getElementById('callTimer');
    if (!state.active) { const e=el(); if(e) e.textContent = state.outgoing ? 'Se apeleaza...' : state.incoming ? 'Apel primit' : ''; return; }
    const start = (Number(state.startedAt || 0) || Math.floor(Date.now()/1000)) * 1000;
    const tick = () => { const d = Math.max(0, Math.floor((Date.now()-start)/1000)); const e=el(); if(e) e.textContent = `${String(Math.floor(d/60)).padStart(2,'0')}:${String(d%60).padStart(2,'0')}`; };
    tick(); timer = setInterval(tick, 1000);
}
function renderPeek(kind, payload) {
    if (kind === 'message') {
        screens.peek.innerHTML = `<div class="peek-card msg"><b>${esc(payload.name || payload.from || 'Mesaj')}</b><p>${esc(payload.type === 'location' ? 'Locatie partajata' : payload.text || '')}</p><button onclick="openPhone('messages')">Deschide</button></div>`;
    } else {
        const name = state.otherName || state.otherNumber || 'Necunoscut';
        screens.peek.innerHTML = `<div class="peek-card"><b>Te suna</b><h2>${esc(name)}</h2><div><button class="round green" onclick="answer()"><img src="${icon('call')}"></button><button class="round red" onclick="decline()"><img src="${icon('hangup')}"></button></div></div>`;
    }
}

function renderAll() {
    if (activeScreen === 'home') renderHome();
    if (activeScreen === 'dial') renderDial();
    if (activeScreen === 'contacts') selectedContact ? renderContactDetail() : renderContacts();
    if (activeScreen === 'calls') renderCalls();
    if (activeScreen === 'messages') renderMessages();
    if (activeScreen === 'conversation') renderConversation();
    if (activeScreen === 'call') renderCall();
}
function applyStateSounds(s) {
    if (!s.inCall) { stopRings(); return; }
    if (s.outgoing) { stop('ring2'); play('ring'); }
    else if (s.incoming) { stop('ring'); play('ring2'); }
    else if (s.active) stopRings();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
    if (data.action === 'setup') nui('requestState');
    if (data.action === 'focus') setFocusUi(data.focus === true);
    if (data.action === 'open') { state = data.state || state; openPhone(data.screen || 'home'); applyStateSounds(state); }
    if (data.action === 'incomingPeek') { state = data.state || state; openPeek('call'); play('ring2'); }
    if (data.action === 'messagePeek') { play('message'); openPeek('message', data.message || {}); }
    if (data.action === 'state') { state = data.state || {}; renderAll(); if (state.inCall && activeScreen !== 'call' && (state.active || state.incoming || state.outgoing)) { /* keep current app */ } applyStateSounds(state); }
    if (data.action === 'messageReceived') { play('message'); }
    if (data.action === 'feedback') { const p = data.payload || {}; if (p.sound) play(p.sound); if (!state.inCall) stopRings(); }
    if (data.action === 'close') { stopRings(); root.classList.add('hidden'); }
});

document.addEventListener('keydown', (e) => {
    if (e.code === 'Backquote' || e.key === '`') nui('toggleCursor');
    if (e.key === 'Escape' && !root.classList.contains('hidden')) closePhone();
});

setInterval(() => { if (!root.classList.contains('hidden')) nui('requestState'); }, 2000);
nui('ready');
