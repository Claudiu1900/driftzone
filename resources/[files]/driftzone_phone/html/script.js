'use strict';

const root = document.getElementById('phoneRoot');
const statusTime = document.getElementById('statusTime');
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
const audio = {
    ring: document.getElementById('ringSound'),
    ring2: document.getElementById('ring2Sound'),
    decline: document.getElementById('declineSound'),
    message: document.getElementById('messageSound')
};

let state = { myNumber: '', contacts: [], callHistory: [], messages: [] };
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
        messages: Array.isArray(incoming.messages) ? incoming.messages : []
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
    return screens[view] ? view : 'home';
}
function callStatusText(r) {
    const dir = r.direction === 'incoming' ? 'Primit' : r.direction === 'missed' ? 'Ratat' : 'Trimis';
    const st = r.status === 'answered' ? 'răspuns' : r.status === 'missed' ? 'nepreluat' : r.status === 'declined' ? 'respins' : 'terminat';
    return `${dir} • ${st}${r.duration ? ` • ${r.duration}s` : ''}`;
}

function playLoop(name) {
    if (currentLoop === name) return;
    stopLoop();
    const a = audio[name];
    if (!a) return;
    try {
        a.loop = true;
        a.pause();
        a.currentTime = 0;
        a.play().catch(() => {});
        currentLoop = name;
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
    if (lastPlayAt[name] && now - lastPlayAt[name] < 350) return;
    lastPlayAt[name] = now;
    try {
        if (currentLoop === name) currentLoop = null;
        a.loop = false;
        a.pause();
        a.currentTime = 0;
        a.play().catch(() => {});
    } catch (e) {}
}
function stopAllSounds() {
    stopLoop();
    Object.keys(audio).forEach((key) => {
        const a = audio[key];
        if (!a) return;
        try { a.pause(); a.currentTime = 0; a.loop = false; } catch (e) {}
    });
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
function openPeek(kind, payload = {}) {
    phoneMode = 'peek';
    root.classList.remove('hidden', 'closing');
    root.classList.add('peek-mode', 'opening');
    setTimeout(() => root.classList.remove('opening'), 260);
    renderPeek(kind, payload);
    showScreen('peek');
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
            ${appButton('calls', 'Apeluri', 'calls', 'calls-app')}
        </div>
    `;
}
function renderDial() {
    screens.dial.classList.remove('scroll');
    screens.dial.innerHTML = `
        ${header('Telefon', 'back()', `<button onclick="navigate('calls')"><img src="${icon('calls')}"></button>`)}
        <div class="dial-card">
            <input id="dialInput" class="dial-input" placeholder="Număr telefon" inputmode="numeric" autocomplete="off">
            <div class="keypad">
                ${['1','2','3','4','5','6','7','8','9','CLR','0','DEL'].map((k) => `<button class="${k.length > 1 ? 'util' : ''}" onclick="dialKey('${k}')">${k}</button>`).join('')}
            </div>
            <button class="main-call" onclick="dialNow()"><img src="${icon('call')}"></button>
        </div>
    `;
}
function dialKey(k) {
    const input = document.getElementById('dialInput');
    if (!input) return;
    if (k === 'CLR') input.value = '';
    else if (k === 'DEL') input.value = cleanNumber(input.value).slice(0, -1);
    else input.value = cleanNumber(input.value + k);
    input.focus();
}
function dialNow(number) {
    const input = document.getElementById('dialInput');
    const n = cleanNumber(number || (input ? input.value : ''));
    if (!n) { playOne('decline'); return; }
    stopLoop();
    nui('dial', { number: n });
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
    screens.calls.classList.remove('scroll');
    const rows = state.callHistory || [];
    screens.calls.innerHTML = `
        ${header('Apeluri')}
        <div class="list clean-list">${rows.length ? rows.map((r) => `<button class="list-row call-row" onclick="dialNow('${esc(r.number)}')"><span class="call-dot ${esc(r.status)}"></span><div><b>${esc(r.name || r.number)}</b><small>${esc(callStatusText(r))}</small></div></button>`).join('') : `<div class="empty">Nu ai istoric de apeluri.</div>`}</div>
    `;
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
        <div class="list clean-list">${convs.length ? convs.map((c) => `<button class="list-row message-row" onclick="openConversation('${esc(c.otherNumber)}')"><span class="avatar">${esc((c.otherName || c.otherNumber || '?')[0])}</span><div><b>${esc(c.otherName || c.otherNumber)}</b><small>${esc(c.type === 'location' ? 'Locație partajată' : c.text)}</small></div></button>`).join('') : `<div class="empty">Nu ai conversații. Apasă + ca să începi.</div>`}</div>
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
    const number = cleanNumber(input ? input.value : '');
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
    if (data.action === 'setup') nui('requestState');
    if (data.action === 'focus') setFocusUi(data.focus === true);
    if (data.action === 'open') {
        state = normalizeState(data.state || state);
        applyCallSounds(state);
        openPhone(data.screen || 'home');
    }
    if (data.action === 'incomingPeek') {
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
        if (oldInCall && !state.inCall && activeView === 'call') navigate('home', false);
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
    if (data.action === 'feedback') {
        const payload = data.payload || {};
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
