'use strict';

const root = document.getElementById('phoneRoot');
const statusTime = document.getElementById('statusTime');
const screens = {
    home: document.getElementById('homeScreen'),
    dial: document.getElementById('dialScreen'),
    contacts: document.getElementById('contactsScreen'),
    calls: document.getElementById('callsScreen'),
    messages: document.getElementById('messagesScreen'),
    garage: document.getElementById('garageScreen'),
    conversation: document.getElementById('conversationScreen'),
    call: document.getElementById('callScreen'),
    peek: document.getElementById('peekScreen')
};
const audio = {
    ring: document.getElementById('ringSound'),
    ring2: document.getElementById('ring2Sound'),
    decline: document.getElementById('declineSound'),
    message: document.getElementById('messageSound')
};

let state = { myNumber: '', contacts: [], callHistory: [], messages: [], garage: { vehicles: [], garages: [], atGarage: false } };
let selectedGarageVehicleId = 0;
let garageAdminGarages = [];
let garageAdminSelected = null;
let garageAdminSpots = [];
let dialTab = 'keypad';
let activeView = 'home';
let nav = ['home'];
let selectedContactId = 0;
let currentConversation = '';
let callOptions = { muted: false, speaker: false };
let focus = false;
let phoneMode = 'closed';
let callTimer = null;
let currentLoop = null;
let lastSoundKind = 'none';
let lastPlayAt = {};
let pendingSentTokens = new Set();
let rendering = false;

Object.keys(audio).forEach((key) => {
    const a = audio[key];
    if (!a) return;
    a.volume = key === 'message' ? 0.42 : 0.60;
    a.loop = false;
});

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function esc(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
function cleanNumber(value) { return String(value || '').replace(/[^0-9]/g, ''); }
function normalizeDialText(value) { return String(value || '').trim().toLowerCase(); }
function findContactByInput(value) {
    const raw = normalizeDialText(value);
    const digits = cleanNumber(value);
    if (!raw && !digits) return null;

    return (state.contacts || []).find((c) => {
        const name = normalizeDialText(c.name);
        const number = cleanNumber(c.number);
        return (digits && number === digits) || (raw && name === raw) || (raw && name.includes(raw));
    }) || null;
}
function resolveDialTarget(value) {
    const raw = String(value || '').trim();
    if (!raw) return '';
    const contact = findContactByInput(raw);
    if (contact) return cleanNumber(contact.number);
    return cleanNumber(raw);
}
function icon(name) { return `assets/icons/${name}.svg`; }
function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }
function nowTime() { const d = new Date(); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; }
function updateTime() { if (statusTime) statusTime.textContent = nowTime(); }
setInterval(updateTime, 1000); updateTime();

function normalizeState(incoming) {
    incoming = incoming || {};
    return {
        ...incoming,
        contacts: Array.isArray(incoming.contacts) ? incoming.contacts : [],
        callHistory: Array.isArray(incoming.callHistory) ? incoming.callHistory : [],
        messages: Array.isArray(incoming.messages) ? incoming.messages : [],
        garage: incoming.garage && typeof incoming.garage === 'object'
            ? { ...incoming.garage, vehicles: Array.isArray(incoming.garage.vehicles) ? incoming.garage.vehicles : [], garages: Array.isArray(incoming.garage.garages) ? incoming.garage.garages : [] }
            : { vehicles: [], garages: [], atGarage: false }
    };
}
function messageKey(m) { return m && m.clientToken ? `t_${m.clientToken}` : `i_${m && m.id}`; }
function isPhoneHidden() { return root.classList.contains('hidden'); }
function currentInputActive() {
    const el = document.activeElement;
    if (!el) return false;
    const tag = String(el.tagName || '').toLowerCase();
    return tag === 'input' || tag === 'textarea';
}
function displayName(number) {
    const clean = cleanNumber(number);
    const contact = (state.contacts || []).find((c) => cleanNumber(c.number) === clean);
    return contact ? contact.name : clean;
}
function getContactById(id) {
    id = Number(id || 0);
    return (state.contacts || []).find((c) => Number(c.id) === id) || null;
}
function screenFor(view) {
    if (view === 'contactDetail' || view === 'contactForm') return 'contacts';
    if (view === 'newMessage') return 'messages';
    if (view === 'garageDetail') return 'garage';
    return screens[view] ? view : 'home';
}
function callStatusText(r) {
    const dir = r.direction === 'incoming' ? 'Primit' : r.direction === 'missed' ? 'Ratat' : 'Trimis';
    const st = r.status === 'answered' ? 'răspuns' : r.status === 'missed' ? 'nepreluat' : r.status === 'declined' ? 'respins' : 'terminat';
    return `${dir} • ${st}${r.duration ? ` • ${r.duration}s` : ''}`;
}

function primeAudio() {
    Object.keys(audio).forEach((key) => {
        const a = audio[key];
        if (!a) return;
        try {
            a.preload = 'auto';
            a.volume = 1.0;
            a.muted = false;
            a.load();
        } catch (e) {}
    });
}

function tryPlay(a, retry = true) {
    if (!a) return;
    try {
        a.muted = false;
        a.volume = 1.0;
        const p = a.play();
        if (p && typeof p.catch === 'function') {
            p.catch(() => {
                if (retry) {
                    setTimeout(() => {
                        try { a.play().catch(() => {}); } catch (e) {}
                    }, 160);
                }
            });
        }
    } catch (e) {}
}

function playLoop(name) {
    const a = audio[name];
    if (!a) return;

    if (currentLoop === name && !a.paused) return;

    stopLoop();

    try {
        a.loop = true;
        a.pause();
        a.currentTime = 0;
        currentLoop = name;
        tryPlay(a, true);
    } catch (e) {}
}

function stopLoop() {
    if (!currentLoop) return;
    const a = audio[currentLoop];
    if (a) {
        try { a.pause(); a.currentTime = 0; a.loop = false; } catch (e) {}
    }
    currentLoop = null;
}

function playOne(name) {
    const a = audio[name];
    if (!a) return;
    const now = Date.now();
    if (lastPlayAt[name] && now - lastPlayAt[name] < 250) return;
    lastPlayAt[name] = now;
    try {
        if (currentLoop === name) currentLoop = null;
        a.loop = false;
        a.pause();
        a.currentTime = 0;
        tryPlay(a, true);
    } catch (e) {}
}

function stopAllSounds() {
    stopLoop();
    Object.keys(audio).forEach((key) => {
        const a = audio[key];
        if (!a) return;
        try { a.pause(); a.currentTime = 0; a.loop = false; } catch (e) {}
    });
    lastSoundKind = 'none';
}

function callSoundKind(s) {
    if (!s || !s.inCall) return 'none';
    if (s.outgoing && !s.active) return 'outgoing';
    if (s.incoming && !s.active) return 'incoming';
    if (s.active) return 'active';
    return 'none';
}
function applyCallSounds(newState) {
    const kind = callSoundKind(newState);
    if (kind === lastSoundKind) return;
    if (kind === 'outgoing') playLoop('ring');
    else if (kind === 'incoming') playLoop('ring2');
    else stopLoop();
    lastSoundKind = kind;
}

function setFocusUi(value) {
    focus = value === true;
    root.classList.toggle('no-focus', !focus);
}
function showScreen(view) {
    Object.values(screens).forEach(hide);
    const target = screens[screenFor(view)] || screens.home;
    show(target);
    activeView = view;
}
function navigate(view, push = true) {
    if (rendering) return;
    showScreen(view);
    if (push && nav[nav.length - 1] !== view) nav.push(view);
    renderCurrent();
}
function back() {
    if (activeView === 'home') return closePhone();
    if (activeView === 'contactForm') return navigate(selectedContactId ? 'contactDetail' : 'contacts', false);
    if (activeView === 'contactDetail') { selectedContactId = 0; return navigate('contacts', false); }
    if (activeView === 'newMessage') return navigate('messages', false);
    if (activeView === 'conversation') return navigate('messages', false);
    if (activeView === 'garageDetail') return navigate('garage', false);
    if (activeView === 'call') return navigate('home', false);
    nav.pop();
    navigate(nav[nav.length - 1] || 'home', false);
}
function homeBarAction() { back(); }
function openPhone(view = 'home') {
    phoneMode = 'full';
    root.classList.remove('hidden', 'closing', 'peek-mode');
    root.classList.add('opening');
    setTimeout(() => root.classList.remove('opening'), 260);
    nav = ['home'];
    if (view === 'messages' && state.lastMessageNumber) {
        currentConversation = cleanNumber(state.lastMessageNumber);
        navigate('conversation', false);
    } else {
        navigate(view || 'home', false);
    }
}
function closePhone() {
    phoneMode = 'closed';
    root.classList.add('closing');
    setTimeout(() => {
        root.classList.add('hidden');
        root.classList.remove('closing', 'opening', 'peek-mode');
    }, 230);
    nui('close');
}
let peekAutoCloseTimer = null;

function openPeek(kind, payload = {}) {
    phoneMode = 'peek';
    root.classList.remove('hidden', 'closing');
    root.classList.add('peek-mode', 'opening');
    setTimeout(() => root.classList.remove('opening'), 260);
    renderPeek(kind, payload);
    showScreen('peek');

    if (peekAutoCloseTimer) clearTimeout(peekAutoCloseTimer);
    if (kind === 'message') {
        peekAutoCloseTimer = setTimeout(() => {
            if (phoneMode === 'peek') closePhone();
        }, 3000);
    }
}
function openPhoneFromPeek(view, number = '') {
    if (number) state.lastMessageNumber = cleanNumber(number);
    nui('openFull', { screen: view || 'home' });
}

function appButton(img, label, view, cls = '') {
    return `<button class="app ${cls}" onclick="navigate('${view}')"><span class="app-icon"><img src="${icon(img)}" draggable="false"></span><span>${esc(label)}</span></button>`;
}
function header(title, backFn = 'back()', right = '<span class="blank"></span>') {
    return `<div class="app-head"><button onclick="${backFn}"><img src="${icon('back')}"></button><b>${esc(title)}</b>${right}</div>`;
}

function renderHome() {
    screens.home.classList.remove('scroll');
    const msgCount = getConversations().length;
    screens.home.innerHTML = `
        <div class="aurora"></div>
        <div class="lock-time">${esc(nowTime())}</div>
        <div class="phone-number-chip">${state.myNumber ? esc(state.myNumber) : 'Fără număr'}</div>
        ${state.inCall ? `<button class="call-banner" onclick="navigate('call')"><span>${state.incoming ? 'Te sună' : state.outgoing ? 'Se apelează' : 'Apel conectat'}</span><b>${esc(state.otherName || state.otherNumber || '')}</b></button>` : ''}
        <div class="apps apps-main">
            ${appButton('phone', 'Telefon', 'dial', 'phone-app')}
            ${appButton('messages', `Mesaje${msgCount ? ` (${msgCount})` : ''}`, 'messages', 'msg-app')}
            ${appButton('contacts', 'Contacte', 'contacts', 'contacts-app')}
            ${appButton('garage', 'Garaj', 'garage', 'garage-app')}
        </div>
    `;
}
function setDialTab(tab) {
    dialTab = tab === 'calls' ? 'calls' : 'keypad';
    renderDial();
}

function renderDial() {
    screens.dial.classList.remove('scroll');
    const rows = state.callHistory || [];

    const keypadHtml = `
        <div class="dial-card">
            <input id="dialInput" class="dial-input" placeholder="Numar sau nume contact" inputmode="text" autocomplete="off">
            <div class="keypad">
                ${['1','2','3','4','5','6','7','8','9','CLR','0','DEL'].map((k) => `<button class="${k.length > 1 ? 'util' : ''}" onclick="dialKey('${k}')">${k}</button>`).join('')}
            </div>
            <button class="main-call" onclick="dialNow()"><img src="${icon('call')}"></button>
        </div>
    `;

    const callsHtml = `
        <div class="phone-call-history">
            ${rows.length ? rows.map((r) => `
                <button class="phone-call-row ${esc(r.status || '')}" onclick="dialNow('${esc(r.number)}')">
                    <span class="call-dot ${esc(r.status || '')}"></span>
                    <div>
                        <b>${esc(r.name || r.number || 'Necunoscut')}</b>
                        <small>${esc(callStatusText(r))}</small>
                    </div>
                    <em>${esc(r.direction === 'missed' || r.status === 'missed' ? 'RATAT' : r.direction === 'incoming' ? 'PRIMIT' : 'TRIMIS')}</em>
                </button>
            `).join('') : `<div class="empty">Nu ai istoric de apeluri.</div>`}
        </div>
    `;

    screens.dial.innerHTML = `
        ${header('Telefon')}
        <div class="phone-tabs">
            <button class="${dialTab === 'keypad' ? 'active' : ''}" onclick="setDialTab('keypad')"><img src="${icon('phone')}"> Telefon</button>
            <button class="${dialTab === 'calls' ? 'active' : ''}" onclick="setDialTab('calls')"><img src="${icon('calls')}"> Apeluri</button>
        </div>
        ${dialTab === 'calls' ? callsHtml : keypadHtml}
    `;
}

function dialKey(k) {
    const input = document.getElementById('dialInput');
    if (!input) return;

    if (k === 'CLR') input.value = '';
    else if (k === 'DEL') input.value = String(input.value || '').slice(0, -1);
    else input.value = String(input.value || '') + String(k);

    input.focus();
}

function dialNow(value = null) {
    const input = document.getElementById('dialInput');
    const raw = value !== null && value !== undefined ? String(value) : (input ? input.value : '');
    const target = resolveDialTarget(raw);

    if (!target) {
        playOne('decline');
        return;
    }

    stopAllSounds();
    nui('dial', { number: target });
    navigate('call');
}


function renderContacts() {
    selectedContactId = 0;
    screens.contacts.classList.remove('scroll');
    const contacts = state.contacts || [];
    screens.contacts.innerHTML = `
        ${header('Contacte', 'back()', `<button onclick="openContactForm(0)" class="head-add"><img src="${icon('plus')}"></button>`)}
        <div class="search-title">${contacts.length} contacte</div>
        <div class="list clean-list">${contacts.length ? contacts.map((c) => `
            <button class="list-row contact-row" onclick="openContact(${Number(c.id)})">
                <span class="avatar">${esc((c.name || c.number || '?')[0])}</span>
                <div><b>${esc(c.name || c.number)}</b><small>${esc(c.number)}${c.blocked ? ' • blocat' : ''}</small></div>
            </button>`).join('') : `<div class="empty">Nu ai contacte. Apasă + ca să adaugi.</div>`}</div>
    `;
}
function openContact(id) { selectedContactId = Number(id || 0); navigate('contactDetail'); }
function renderContactDetail() {
    screens.contacts.classList.remove('scroll');
    const c = getContactById(selectedContactId);
    if (!c) return renderContacts();
    screens.contacts.innerHTML = `
        ${header(c.name || 'Contact', 'back()', `<button onclick="openContactForm(${Number(c.id)})"><img src="${icon('edit')}"></button>`)}
        <div class="profile-card"><span class="profile-avatar">${esc((c.name || '?')[0])}</span><h2>${esc(c.name)}</h2><p>${esc(c.number)}</p>${c.blocked ? '<em>Blocat</em>' : ''}</div>
        <div class="action-grid">
            <button onclick="dialNow('${esc(c.number)}')"><img src="${icon('call')}"><b>Sună</b></button>
            <button onclick="openConversation('${esc(c.number)}')"><img src="${icon('messages')}"><b>Mesaj</b></button>
            <button onclick="openContactForm(${Number(c.id)})"><img src="${icon('edit')}"><b>Edit</b></button>
            <button onclick="toggleBlock(${Number(c.id)})"><img src="${icon('block')}"><b>${c.blocked ? 'Unblock' : 'Block'}</b></button>
            <button class="danger wide" onclick="deleteContact(${Number(c.id)})"><img src="${icon('trash')}"><b>Șterge</b></button>
        </div>
    `;
}
function openContactForm(id = 0) { selectedContactId = Number(id || 0); navigate('contactForm'); }
function renderContactForm() {
    screens.contacts.classList.remove('scroll');
    const c = getContactById(selectedContactId);
    screens.contacts.innerHTML = `
        ${header(c ? 'Edit contact' : 'Contact nou')}
        <div class="form-card glass-card">
            <label>Nume<input id="contactName" value="${esc(c ? c.name : '')}" placeholder="Ex: Claudiu" autocomplete="off"></label>
            <label>Număr<input id="contactNumber" value="${esc(c ? c.number : '')}" placeholder="Număr telefon" inputmode="tel" autocomplete="off"></label>
            <button class="primary" onclick="saveContact(${c ? Number(c.id) : 0})">Salvează contactul</button>
        </div>
    `;
    setTimeout(() => { const el = document.getElementById('contactName'); if (el) el.focus(); }, 60);
}
function saveContact(id) {
    const name = document.getElementById('contactName');
    const number = document.getElementById('contactNumber');
    const payload = { id: Number(id || 0), name: name ? name.value : '', number: number ? number.value : '' };
    if (!payload.name.trim() || !cleanNumber(payload.number)) { playOne('decline'); return; }
    nui('saveContact', payload);
    selectedContactId = 0;
    navigate('contacts', false);
}
function toggleBlock(id) { nui('toggleBlock', { id: Number(id || 0) }); }
function deleteContact(id) { nui('deleteContact', { id: Number(id || 0) }); selectedContactId = 0; navigate('contacts', false); }

function renderCalls() {
    dialTab = 'calls';
    navigate('dial', false);
}

function getConversations() {
    const map = {};
    (state.messages || []).forEach((m) => {
        const n = cleanNumber(m.otherNumber);
        if (!n) return;
        const current = map[n];
        if (!current || Number(m.id || 0) > Number(current.id || 0)) map[n] = m;
    });
    return Object.values(map).sort((a, b) => Number(b.id || 0) - Number(a.id || 0));
}
function renderMessages() {
    screens.messages.classList.remove('scroll');
    const convs = getConversations();
    screens.messages.innerHTML = `
        ${header('Mesaje', 'back()', `<button onclick="navigate('newMessage')" class="head-add"><img src="${icon('plus')}"></button>`)}
        <div class="messages-simple">
            ${convs.length ? convs.map((c) => `
                <button class="message-simple-row" onclick="openConversation('${esc(c.otherNumber)}')">
                    <span class="message-avatar">${esc((c.otherName || c.otherNumber || '?')[0])}</span>
                    <div>
                        <b>${esc(c.otherName || c.otherNumber)}</b>
                        <small>${esc(c.type === 'location' ? 'Locație partajată' : c.text)}</small>
                    </div>
                </button>
            `).join('') : `<div class="empty">Nu ai mesaje.</div>`}
        </div>
    `;
}
function renderNewMessage() {
    screens.messages.classList.remove('scroll');
    screens.messages.innerHTML = `
        ${header('Mesaj nou')}
        <div class="form-card glass-card">
            <label>Număr<input id="newMsgNumber" placeholder="Număr telefon" inputmode="tel" autocomplete="off"></label>
            <button class="primary" onclick="openNewMessageConversation()">Deschide conversația</button>
        </div>
    `;
    setTimeout(() => { const el = document.getElementById('newMsgNumber'); if (el) el.focus(); }, 60);
}
function openNewMessageConversation() {
    const input = document.getElementById('newMsgNumber');
    const number = resolveDialTarget(input ? input.value : '');
    if (!number) { playOne('decline'); return; }
    openConversation(number);
}
function openConversation(number) {
    currentConversation = cleanNumber(number);
    if (!currentConversation) { playOne('decline'); return; }
    navigate('conversation');
}
function messagesForConversation(number) {
    const n = cleanNumber(number);
    return (state.messages || []).filter((m) => cleanNumber(m.otherNumber) === n).sort((a, b) => Number(a.id || 0) - Number(b.id || 0));
}
function renderConversation() {
    screens.conversation.classList.remove('scroll');
    const n = cleanNumber(currentConversation);
    const name = displayName(n);
    const msgs = messagesForConversation(n);
    screens.conversation.innerHTML = `
        ${header(name || n, 'back()', `<button onclick="dialNow('${esc(n)}')"><img src="${icon('call')}"></button>`)}
        <div id="msgList" class="msg-list">${msgs.map(renderMessageBubble).join('')}</div>
        <div class="composer"><button onclick="shareLocation()" title="Trimite locația"><img src="${icon('pin')}"></button><input id="msgInput" placeholder="Scrie mesaj" autocomplete="off"><button onclick="sendMessage()"><img src="${icon('send')}"></button></div>
    `;
    setTimeout(scrollMessagesBottom, 30);
}
function renderMessageBubble(m) {
    const key = esc(messageKey(m));
    const cls = m.mine ? 'bubble mine' : 'bubble';
    if (m.type === 'location') {
        const loc = encodeURIComponent(JSON.stringify(m.location || {}));
        return `<div class="${cls}" data-key="${key}"><button class="location-bubble" onclick="setWaypointEncoded('${loc}')"><img src="${icon('pin')}"> Setează waypoint</button></div>`;
    }
    return `<div class="${cls}" data-key="${key}">${esc(m.text)}</div>`;
}
function scrollMessagesBottom() { const list = document.getElementById('msgList'); if (list) list.scrollTop = list.scrollHeight; }
function appendMessageToConversation(m) {
    if (cleanNumber(m.otherNumber) !== cleanNumber(currentConversation)) return;
    const list = document.getElementById('msgList');
    if (!list) return;
    const key = messageKey(m);
    const existing = list.querySelector(`[data-key="${key}"]`);
    if (existing) existing.outerHTML = renderMessageBubble(m);
    else list.insertAdjacentHTML('beforeend', renderMessageBubble(m));
    scrollMessagesBottom();
}
function mergeMessage(m, silent = false) {
    if (!m || !cleanNumber(m.otherNumber)) return;
    state.messages = Array.isArray(state.messages) ? state.messages : [];
    let index = -1;
    if (m.clientToken) index = state.messages.findIndex((x) => x.clientToken && x.clientToken === m.clientToken);
    if (index < 0 && Number(m.id || 0) > 0) index = state.messages.findIndex((x) => Number(x.id || 0) === Number(m.id));
    if (index >= 0) state.messages[index] = { ...state.messages[index], ...m };
    else state.messages.push(m);
    state.messages.sort((a, b) => Number(a.id || 0) - Number(b.id || 0));
    if (activeView === 'conversation' && cleanNumber(currentConversation) === cleanNumber(m.otherNumber)) appendMessageToConversation(m);
    else if (activeView === 'messages' && !isPhoneHidden()) renderMessages();
    if (!silent) playOne('message');
}
function sendMessage() {
    const input = document.getElementById('msgInput');
    const text = input ? input.value.trim() : '';
    if (!text || !currentConversation) return;
    const token = `c${Date.now()}${Math.floor(Math.random() * 9999)}`;
    const temp = {
        id: -Date.now(),
        clientToken: token,
        mine: true,
        otherNumber: currentConversation,
        otherName: displayName(currentConversation),
        from: state.myNumber || '',
        to: currentConversation,
        text,
        type: 'text',
        location: {},
        created_at: ''
    };
    pendingSentTokens.add(token);
    mergeMessage(temp, true);
    if (input) { input.value = ''; input.focus(); }
    nui('sendMessage', { number: currentConversation, text, type: 'text', clientToken: token });
}
function shareLocation() {
    if (!currentConversation) return;
    const token = `l${Date.now()}${Math.floor(Math.random() * 9999)}`;
    const temp = {
        id: -Date.now(),
        clientToken: token,
        mine: true,
        otherNumber: currentConversation,
        otherName: displayName(currentConversation),
        from: state.myNumber || '',
        to: currentConversation,
        text: 'Locație partajată',
        type: 'location',
        location: {},
        created_at: ''
    };
    pendingSentTokens.add(token);
    mergeMessage(temp, true);
    nui('shareLocation', { number: currentConversation, clientToken: token });
}
function setWaypoint(location) { nui('setWaypoint', { location: location || {} }); }
function setWaypointEncoded(raw) {
    try { setWaypoint(JSON.parse(decodeURIComponent(String(raw || '')))); } catch (e) {}
}


function garageState() {
    const g = state.garage || {};
    return {
        ...g,
        vehicles: Array.isArray(g.vehicles) ? g.vehicles : [],
        garages: Array.isArray(g.garages) ? g.garages : []
    };
}

function garageVehicleById(id) {
    id = Number(id || 0);
    return garageState().vehicles.find((v) => Number(v.id || 0) === id) || null;
}

function currentGarageName() {
    const g = garageState();
    return g.currentGarage && g.currentGarage.name ? g.currentGarage.name : 'Nu ești la garaj';
}

function renderGarage() {
    screens.garage.classList.remove('scroll');
    selectedGarageVehicleId = 0;

    const g = garageState();
    const vehicles = g.vehicles || [];
    const atGarage = g.atGarage === true;
    const current = g.currentGarage || null;

    screens.garage.innerHTML = `
        ${header('Garaj', 'back()', `<button onclick="nui('requestState')"><img src="${icon('garage')}"></button>`)}
        <div class="garage-phone-head">
            <div>
                <span>${atGarage ? 'GARAJ' : 'GARAJ'}</span>
                <b>${esc(current ? current.name : 'Nu ești la garaj')}</b>
                <small>${Number(g.outsideCount || 0)}/${Number(g.outsideLimit || 1)} vehicule afara</small>
            </div>
            <img src="${icon('garage')}" draggable="false">
        </div>
        <div class="garage-cars">
            ${vehicles.length ? vehicles.map(renderGarageCar).join('') : `<div class="empty">Nu ai mașini.</div>`}
        </div>
    `;
}

function vehicleDisplayName(v) {
    return String(v?.name || v?.vehicle_name || v?.label || 'Vehicul');
}

function vehicleIsSpawned(v) {
    if (!v) return false;
    if (v.entitySpawned === true) return true;
    if (v.spawned === true) return true;
    if (Number(v.rawGarage ?? v.garage ?? v.garageId ?? 1) <= 0) return true;
    return false;
}

function renderGarageCar(v) {
    const spawned = vehicleIsSpawned(v);
    const place = spawned ? 'Pe strada' : (v.garageName || 'In garaj');
    const statusCls = spawned ? 'out' : 'stored';

    return `
        <button class="garage-car ${statusCls}" onclick="openGarageVehicle(${Number(v.id || 0)})">
            <span class="garage-car-img"><img src="${icon('car')}" draggable="false"></span>
            <span class="garage-car-info">
                <b>${esc(vehicleDisplayName(v))}</b>
                <small>${esc(v.plate || 'DRIFT')} • ${esc(place)}</small>
            </span>
            <em>${spawned ? 'AFARA' : 'GARAJ'}</em>
        </button>
    `;
}

function openGarageVehicle(id) {
    selectedGarageVehicleId = Number(id || 0);
    navigate('garageDetail');
}

function renderGarageDetail() {
    screens.garage.classList.remove('scroll');
    const g = garageState();
    const v = garageVehicleById(selectedGarageVehicleId);

    if (!v) {
        selectedGarageVehicleId = 0;
        return renderGarage();
    }

    const spawned = vehicleIsSpawned(v);
    const atGarage = g.atGarage === true;
    const garageName = v.garageName || (spawned ? 'Pe strada' : 'In garaj');

    const spawnDisabled = (!atGarage || spawned) ? 'disabled' : '';
    const parkDisabled = (!atGarage || !spawned) ? 'disabled' : '';

    screens.garage.innerHTML = `
        ${header('Vehicul', "navigate('garage', false)")}
        <div class="garage-detail-card">
            <div class="garage-detail-visual"><img src="${icon('car')}" draggable="false"></div>
            <h2>${esc(vehicleDisplayName(v))}</h2>
            <p>${esc(v.plate || 'DRIFT')}</p>
            <div class="garage-status-row">
                <span>${spawned ? 'Pe strada' : 'In garaj'}</span>
                <b>${esc(garageName)}</b>
            </div>
        </div>
        <div class="garage-actions">
            <button ${spawnDisabled} onclick="garageAction('spawn', ${Number(v.id || 0)})"><img src="${icon('spawn')}"><b>Scoate din Garaj</b><small>${atGarage ? 'Ridica vehiculul de aici' : 'Trebuie sa fii la un garaj'}</small></button>
            ${atGarage && spawned ? `<button ${parkDisabled} onclick="garageAction('park', ${Number(v.id || 0)})"><img src="${icon('park')}"><b>Parcheaza</b><small>Parcheaza vehiculul langa garaj</small></button>` : ''}
            <button ${spawned ? 'disabled' : ''} onclick="garageAction('tow', ${Number(v.id || 0)})"><img src="${icon('tow')}"><b>Tracteaza</b><small>${spawned ? 'Vehiculul este pe strada' : `${Number(g.towPrice || 5000).toLocaleString('en-US')} cash`}</small></button>
            ${spawned ? `<button onclick="garageAction('locate', ${Number(v.id || 0)})"><img src="${icon('locate')}"><b>Localizeaza</b><small>Marcheaza locatia vehiculului</small></button>` : ''}
        </div>
    `;
}

function updateGarageVehicleLocalState(id, spawned) {
    id = Number(id || 0);
    const g = garageState();
    const v = (g.vehicles || []).find((entry) => Number(entry.id || 0) === id);
    if (!v) return;

    v.spawned = spawned === true;
    v.entitySpawned = spawned === true;
    v.stored = spawned !== true;

    if (spawned === true) {
        v.rawGarage = 0;
        v.garage = 0;
        v.garageId = 0;
        v.garageName = 'Pe strada';
    }
}

function garageAction(action, id) {
    id = Number(id || selectedGarageVehicleId || 0);
    if (id <= 0) return;

    if (action === 'spawn') {
        nui('garageSpawn', { id });
        updateGarageVehicleLocalState(id, true);
        renderGarageDetail();
    } else if (action === 'park') {
        nui('garagePark', { id });
        updateGarageVehicleLocalState(id, false);
        renderGarageDetail();
    } else if (action === 'tow') {
        nui('garageTow', { id });
    } else if (action === 'locate') {
        nui('garageLocate', { id });
    }

    setTimeout(() => nui('requestState'), 450);
    setTimeout(() => nui('requestState'), 1200);
}



function gaNum(value, digits = 2) {
    const n = Number(value || 0);
    return Number.isFinite(n) ? n.toFixed(digits) : '0.00';
}

function gaCoordLine(x, y, z, h = null) {
    const parts = [gaNum(x, 6), gaNum(y, 6), gaNum(z, 6)];
    if (h !== null && h !== undefined) parts.push(gaNum(h, 2));
    return parts.join(', ');
}

function gaParseCoords(value, needsHeading = false) {
    const parts = String(value || '').replace(/;/g, ',').split(/[,\s]+/).map(v => v.trim()).filter(Boolean).map(Number);
    if (parts.length < 3 || parts.some(v => !Number.isFinite(v))) return null;
    return {
        x: parts[0],
        y: parts[1],
        z: parts[2],
        h: Number.isFinite(parts[3]) ? parts[3] : (needsHeading ? 0 : undefined)
    };
}

function gaRoot() { return document.getElementById('garageAdminRoot'); }
function gaStatus(text, good = null) {
    const el = document.getElementById('garageAdminStatus');
    if (!el) return;
    el.textContent = text || '';
    el.classList.remove('success', 'error');
    if (good === true) el.classList.add('success');
    if (good === false) el.classList.add('error');
}

function gaNormalizeGarage(g) {
    g = g || {};
    const coords = g.coords || g;
    return {
        id: Number(g.id || 0),
        name: String(g.name || 'Garaj'),
        coords: {
            x: Number(coords.x || 0),
            y: Number(coords.y || 0),
            z: Number(coords.z || 0)
        },
        radius: Number(g.radius || 4),
        park_radius: Number(g.park_radius || g.parkRadius || 12),
        visible_radius: g.visible_radius !== false,
        parking_spots: Array.isArray(g.parking_spots) ? g.parking_spots.map(s => ({
            x: Number(s.x || 0),
            y: Number(s.y || 0),
            z: Number(s.z || 0),
            h: Number(s.h || s.heading || 0)
        })) : []
    };
}

function garageAdminOpen(payload = {}) {
    garageAdminGarages = Array.isArray(payload.garages) ? payload.garages.map(gaNormalizeGarage) : [];
    const root = gaRoot();
    if (root) root.classList.remove('hidden');

    if (payload.mode === 'add') garageAdminNew();
    else {
        garageAdminSelected = garageAdminGarages[0] || null;
        if (garageAdminSelected) garageAdminLoad(garageAdminSelected);
        else garageAdminNew();
    }

    garageAdminRenderList();
}

function garageAdminClose() {
    const root = gaRoot();
    if (root) root.classList.add('hidden');
    nui('garageAdminClose');
}

function garageAdminRenderList() {
    const list = document.getElementById('garageAdminList');
    if (!list) return;

    if (!garageAdminGarages.length) {
        list.innerHTML = `<div class="garage-admin-empty">Nu exista garaje.</div>`;
        return;
    }

    list.innerHTML = garageAdminGarages.map(g => `
        <button class="garage-admin-row ${garageAdminSelected && garageAdminSelected.id === g.id ? 'active' : ''}" onclick="garageAdminSelect(${g.id})">
            <b>#${g.id} ${esc(g.name)}</b>
            <span>${g.parking_spots.length} locuri • open ${gaNum(g.radius, 1)} • park ${gaNum(g.park_radius, 1)}</span>
        </button>
    `).join('');
}

function garageAdminSelect(id) {
    const g = garageAdminGarages.find(x => Number(x.id) === Number(id));
    if (!g) return;
    garageAdminLoad(g);
    garageAdminRenderList();
}

function garageAdminLoad(g) {
    garageAdminSelected = gaNormalizeGarage(g);
    garageAdminSpots = [...garageAdminSelected.parking_spots];

    document.getElementById('gaId').value = garageAdminSelected.id || '';
    document.getElementById('gaName').value = garageAdminSelected.name || '';
    document.getElementById('gaRadius').value = String(garageAdminSelected.radius || 4);
    document.getElementById('gaParkRadius').value = String(garageAdminSelected.park_radius || 12);
    document.getElementById('gaVisible').value = garageAdminSelected.visible_radius === false ? '0' : '1';
    document.getElementById('gaCoords').value = gaCoordLine(garageAdminSelected.coords.x, garageAdminSelected.coords.y, garageAdminSelected.coords.z);
    garageAdminRenderSpots();
    gaStatus('Editezi garajul selectat.');
}

function garageAdminNew() {
    garageAdminSelected = { id: 0, name: 'Garaj', coords: { x: 0, y: 0, z: 0 }, radius: 4, park_radius: 12, visible_radius: true, parking_spots: [] };
    garageAdminSpots = [];
    document.getElementById('gaId').value = '';
    document.getElementById('gaName').value = 'Garaj';
    document.getElementById('gaRadius').value = '4';
    document.getElementById('gaParkRadius').value = '12';
    document.getElementById('gaVisible').value = '1';
    document.getElementById('gaCoords').value = '';
    garageAdminRenderSpots();
    gaStatus('Creezi un garaj nou.');
    garageAdminRenderList();
}

function garageAdminRenderSpots() {
    const el = document.getElementById('garageAdminSpots');
    if (!el) return;
    if (!garageAdminSpots.length) {
        el.innerHTML = `<div class="garage-admin-empty">Nu ai locuri de parcare.</div>`;
        return;
    }
    el.innerHTML = garageAdminSpots.map((s, i) => `
        <div class="garage-admin-spot">
            <span>${i + 1}. ${gaCoordLine(s.x, s.y, s.z, s.h)}</span>
            <button onclick="garageAdminRemoveSpot(${i})">×</button>
        </div>
    `).join('');
}

function garageAdminRemoveSpot(index) {
    garageAdminSpots.splice(Number(index), 1);
    garageAdminRenderSpots();
}

async function garageAdminUsePosition() {
    const res = await nui('garageAdminGetPlayerPosition');
    if (!res || !res.ok) return gaStatus('Nu pot lua pozitia.', false);
    document.getElementById('gaCoords').value = gaCoordLine(res.x, res.y, res.z);
}

async function garageAdminAddSpot() {
    const res = await nui('garageAdminGetPlayerPosition');
    if (!res || !res.ok) return gaStatus('Nu pot lua pozitia.', false);
    garageAdminSpots.push({ x: Number(res.x), y: Number(res.y), z: Number(res.z), h: Number(res.h || 0) });
    garageAdminRenderSpots();
}

function garageAdminPayload() {
    const coords = gaParseCoords(document.getElementById('gaCoords').value, false);
    return {
        id: Number(document.getElementById('gaId').value || 0),
        name: String(document.getElementById('gaName').value || '').trim(),
        radius: Number(document.getElementById('gaRadius').value || 4),
        park_radius: Number(document.getElementById('gaParkRadius').value || 12),
        visible_radius: document.getElementById('gaVisible').value === '1',
        coords: coords ? { x: coords.x, y: coords.y, z: coords.z } : null,
        parking_spots: garageAdminSpots
    };
}

function garageAdminSave() {
    const p = garageAdminPayload();
    if (!p.name) return gaStatus('Pune nume la garaj.', false);
    if (!p.coords) return gaStatus('Coordonatele trebuie sa fie: x, y, z.', false);
    if (!p.parking_spots.length) return gaStatus('Adauga minim un loc de parcare.', false);
    gaStatus('Se salveaza...');
    nui('garageAdminSave', p);
}

function garageAdminDelete() {
    const id = Number(document.getElementById('gaId').value || 0);
    if (!id) return;
    gaStatus('Se dezactiveaza...');
    nui('garageAdminDelete', { id });
}

function garageAdminReload() {
    gaStatus('Se reincarca...');
    nui('garageAdminReload');
}

function garageAdminResult(ok, message, garages) {
    gaStatus(message || (ok ? 'Gata.' : 'Eroare.'), ok === true);
    if (Array.isArray(garages)) {
        garageAdminGarages = garages.map(gaNormalizeGarage);
        if (garageAdminSelected && garageAdminSelected.id) {
            const updated = garageAdminGarages.find(g => g.id === garageAdminSelected.id);
            if (updated) garageAdminLoad(updated);
        }
        garageAdminRenderList();
    }
}


function renderCall() {
    screens.call.classList.remove('scroll');
    const name = state.otherName || state.otherNumber || 'Necunoscut';
    let buttons = '';
    if (state.incoming && !state.active) {
        buttons = `<button class="round green" onclick="answer()"><img src="${icon('call')}"></button><button class="round red" onclick="decline()"><img src="${icon('hangup')}"></button>`;
    } else if (state.inCall) {
        buttons = `<button class="round ${callOptions.speaker ? 'active' : ''}" onclick="toggleSpeaker()"><img src="${icon('speaker')}"><span>Speaker</span></button><button class="round ${callOptions.muted ? 'active redish' : ''}" onclick="toggleMute()"><img src="${icon('mute')}"><span>Mute</span></button><button class="round red" onclick="hangup()"><img src="${icon('hangup')}"></button>`;
    } else {
        buttons = `<button class="round red" onclick="navigate('home')"><img src="${icon('hangup')}"></button>`;
    }
    screens.call.innerHTML = `<div class="call-main"><div class="call-bg"></div><div class="call-avatar">${esc(String(name)[0] || '?')}</div><h2>${esc(name)}</h2><p id="callTimer"></p><div class="call-actions">${buttons}</div></div>`;
    updateCallTimer();
}
function answer() { stopLoop(); nui('answer'); openPhone('call'); }
function decline() { stopLoop(); nui('decline'); if (phoneMode === 'peek') setTimeout(() => closePhone(), 120); }
function hangup() { stopLoop(); nui('hangup'); setTimeout(() => { navigate('home', false); }, 150); }
function toggleSpeaker() { callOptions.speaker = !callOptions.speaker; nui('setCallOptions', callOptions); renderCall(); }
function toggleMute() { callOptions.muted = !callOptions.muted; nui('setCallOptions', callOptions); renderCall(); }
function updateCallTimer() {
    if (callTimer) clearInterval(callTimer);
    callTimer = null;
    const el = () => document.getElementById('callTimer');
    const set = (txt) => { const e = el(); if (e) e.textContent = txt; };
    if (!state.inCall) return set('');
    if (state.incoming && !state.active) return set('apel primit');
    if (state.outgoing && !state.active) return set('apelezi...');
    const start = (Number(state.startedAt || 0) || Math.floor(Date.now() / 1000)) * 1000;
    const tick = () => {
        const d = Math.max(0, Math.floor((Date.now() - start) / 1000));
        set(`${String(Math.floor(d / 60)).padStart(2, '0')}:${String(d % 60).padStart(2, '0')}`);
    };
    tick();
    callTimer = setInterval(tick, 1000);
}
function renderPeek(kind, payload = {}) {
    if (kind === 'message') {
        const name = payload.name || displayName(payload.from) || payload.from || 'Mesaj';
        screens.peek.innerHTML = `<div class="peek-card msg"><span>Mesaj nou</span><b>${esc(name)}</b><p>${esc(payload.type === 'location' ? 'Locație partajată' : payload.text || '')}</p><button class="open-btn" onclick="openPhoneFromPeek('messages', '${esc(payload.from || '')}')">Deschide</button></div>`;
        return;
    }
    const name = state.otherName || state.otherNumber || 'Necunoscut';
    screens.peek.innerHTML = `<div class="peek-card"><span>Te sună</span><h2>${esc(name)}</h2><div class="peek-actions"><button class="round green" onclick="answer()"><img src="${icon('call')}"></button><button class="round red" onclick="decline()"><img src="${icon('hangup')}"></button></div></div>`;
}

function renderCurrent() {
    rendering = true;
    try {
        if (activeView === 'home') renderHome();
        else if (activeView === 'dial') renderDial();
        else if (activeView === 'contacts') renderContacts();
        else if (activeView === 'contactDetail') renderContactDetail();
        else if (activeView === 'contactForm') renderContactForm();
        else if (activeView === 'calls') renderCalls();
        else if (activeView === 'messages') renderMessages();
        else if (activeView === 'garage') renderGarage();
        else if (activeView === 'garageDetail') renderGarageDetail();
        else if (activeView === 'newMessage') renderNewMessage();
        else if (activeView === 'conversation') renderConversation();
        else if (activeView === 'call') renderCall();
    } finally {
        rendering = false;
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
    if (data.action === 'setup') { primeAudio(); nui('requestState'); }
    if (data.action === 'focus') setFocusUi(data.focus === true);
    if (data.action === 'open') {
        primeAudio();
        state = normalizeState(data.state || state);
        applyCallSounds(state);
        openPhone(data.screen || 'home');
    }
    if (data.action === 'incomingPeek') {
        primeAudio();
        state = normalizeState(data.state || state);
        applyCallSounds(state);
        openPeek('call');
    }
    if (data.action === 'messagePeek') {
        openPeek('message', data.message || {});
    }
    if (data.action === 'state') {
        const oldInCall = state && state.inCall === true;
        const oldView = activeView;
        state = normalizeState(data.state || {});
        applyCallSounds(state);
        if (oldInCall && !state.inCall) {
            stopAllSounds();
            if (activeView === 'call') navigate('home', false);
            if (phoneMode === 'peek') closePhone();
        }
        const skip = currentInputActive() && ['contactForm', 'newMessage', 'conversation', 'dial'].includes(activeView);
        if (!skip && !isPhoneHidden() && oldView !== 'peek') renderCurrent();
    }
    if (data.action === 'messageSync') {
        const msg = data.message || {};
        const ownToken = msg.clientToken && pendingSentTokens.has(msg.clientToken);
        if (ownToken) pendingSentTokens.delete(msg.clientToken);
        mergeMessage(msg, ownToken);
    }
    if (data.action === 'messageReceived') {
        const payload = data.message || {};
        if (phoneMode !== 'full') openPeek('message', payload);
        playOne('message');
    }
    if (data.action === 'garageAdminOpen') garageAdminOpen(data.data || {});
    if (data.action === 'garageAdminResult') garageAdminResult(data.ok === true, data.message || '', data.garages || []);

    if (data.action === 'feedback') {
        const payload = data.payload || {};
        if (payload.kind === 'call_closed') {
            stopAllSounds();
            if (phoneMode === 'peek') closePhone();
        }
        if (payload.sound === 'decline') playOne('decline');
        else if (payload.sound === 'message') playOne('message');
        else if (payload.sound === 'ring') playLoop('ring');
        else if (payload.sound === 'ring2') playLoop('ring2');
    }
    if (data.action === 'close') {
        stopAllSounds();
        root.classList.add('closing');
        setTimeout(() => {
            root.classList.add('hidden');
            root.classList.remove('closing', 'opening', 'peek-mode');
        }, 230);
    }
});

document.addEventListener('keydown', (event) => {
    if (event.code === 'Backquote' || event.key === '`') {
        event.preventDefault();
        nui('toggleCursor');
    }
    if (event.key === 'Escape' && !isPhoneHidden() && focus && !currentInputActive()) {
        closePhone();
    }
});

nui('ready');

window.dialNow = dialNow;
window.dialKey = dialKey;
window.setDialTab = setDialTab;

window.garageAdminClose = garageAdminClose;
window.garageAdminNew = garageAdminNew;
window.garageAdminReload = garageAdminReload;
window.garageAdminSelect = garageAdminSelect;
window.garageAdminUsePosition = garageAdminUsePosition;
window.garageAdminAddSpot = garageAdminAddSpot;
window.garageAdminRemoveSpot = garageAdminRemoveSpot;
window.garageAdminSave = garageAdminSave;
window.garageAdminDelete = garageAdminDelete;
