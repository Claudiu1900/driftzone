'use strict';

const root = document.getElementById('phoneRoot');
const clockEl = document.getElementById('clock');
const peekView = document.getElementById('peekView');
const peekNumber = document.getElementById('peekNumber');
const homeView = document.getElementById('homeView');
const dialView = document.getElementById('dialView');
const callView = document.getElementById('callView');
const homeNumber = document.getElementById('homeNumber');
const homeBanner = document.getElementById('homeBanner');
const homeBannerText = document.getElementById('homeBannerText');
const myNumber = document.getElementById('myNumber');
const numberInput = document.getElementById('numberInput');
const dialStatus = document.getElementById('dialStatus');
const dialStatusIcon = document.getElementById('dialStatusIcon');
const dialStatusTitle = document.getElementById('dialStatusTitle');
const dialStatusText = document.getElementById('dialStatusText');
const incomingActions = document.getElementById('incomingActions');
const hangupBtn = document.getElementById('hangupBtn');
const callMode = document.getElementById('callMode');
const otherNumber = document.getElementById('otherNumber');
const callSubtitle = document.getElementById('callSubtitle');
const callTimer = document.getElementById('callTimer');

let isOpen = false;
let isPeek = false;
let hasFocus = true;
let lastState = {};
let currentScreen = 'home';
let timerInterval = null;
let closeTimer = null;

const sounds = {
    ring: new Audio('assets/sounds/ring.mp3'),
    ring2: new Audio('assets/sounds/ring2.mp3'),
    decline: new Audio('assets/sounds/decline.mp3')
};

sounds.ring.loop = true;
sounds.ring2.loop = true;
sounds.ring.volume = 0.48;
sounds.ring2.volume = 0.56;
sounds.decline.volume = 0.58;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }

function playSound(name) {
    const audio = sounds[name];
    if (!audio) return;
    try {
        audio.currentTime = 0;
        const p = audio.play();
        if (p && typeof p.catch === 'function') p.catch(() => {});
    } catch (e) {}
}

function stopSound(name) {
    const audio = sounds[name];
    if (!audio) return;
    try {
        audio.pause();
        audio.currentTime = 0;
    } catch (e) {}
}

function stopRings() {
    stopSound('ring');
    stopSound('ring2');
}

function cleanNumber(value) {
    return String(value || '').replace(/[^0-9]/g, '').slice(0, 32);
}

function updateClock() {
    const d = new Date();
    clockEl.textContent = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function setFocusUi(state) {
    hasFocus = state === true;
    root.classList.toggle('no-focus', !hasFocus);
}

function showRoot(mode) {
    if (closeTimer) {
        clearTimeout(closeTimer);
        closeTimer = null;
    }

    hide(root) === undefined;
    root.classList.remove('hidden', 'closing', 'peek', 'no-focus');
    root.classList.add('opening');
    isOpen = true;
    isPeek = mode === 'peek';
    root.classList.toggle('peek', isPeek);

    setTimeout(() => root.classList.remove('opening'), 260);
}

function hideRootAnimated() {
    if (root.classList.contains('hidden')) return;

    root.classList.remove('opening');
    root.classList.add('closing');
    isOpen = false;
    isPeek = false;

    closeTimer = setTimeout(() => {
        root.classList.add('hidden');
        root.classList.remove('closing', 'peek', 'no-focus');
        closeTimer = null;
    }, 240);
}

function switchScreen(name) {
    currentScreen = name;
    hide(peekView);
    hide(homeView);
    hide(dialView);
    hide(callView);

    if (name === 'peek') show(peekView);
    else if (name === 'dial') show(dialView);
    else if (name === 'call') show(callView);
    else show(homeView);
}

function openDialer() {
    if (lastState && lastState.inCall) return switchScreen('call');
    switchScreen('dial');
    setTimeout(() => numberInput.focus(), 60);
}

function goHome() {
    if (isPeek) return nui('openFull');
    if (lastState && lastState.inCall) return switchScreen('call');
    switchScreen('home');
}

function requestClosePhone() {
    hideRootAnimated();
    nui('close');
}

function setDialStatus(cls, title, text, icon) {
    dialStatus.className = `dial-status ${cls || 'idle'}`;
    dialStatusTitle.textContent = title || 'Ready';
    dialStatusText.textContent = text || '';
    if (icon) dialStatusIcon.src = icon;
}

function pressKey(key) { numberInput.value = cleanNumber(numberInput.value + key); }
function clearNumber() { numberInput.value = ''; }
function backspace() { numberInput.value = cleanNumber(numberInput.value).slice(0, -1); }

function dial() {
    const number = cleanNumber(numberInput.value);
    if (!number) {
        setDialStatus('error', 'Numar invalid', 'Scrie un numar de telefon.', 'assets/warning.svg');
        playSound('decline');
        return;
    }
    stopRings();
    nui('dial', { number });
}

function answer() {
    stopRings();
    showRoot('full');
    switchScreen('call');
    nui('answer');
}

function decline() {
    stopRings();
    nui('decline');
}

function hangup() {
    stopRings();
    nui('hangup');
}

function stopTimer() {
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = null;
    hide(callTimer);
}

function startTimer(startedAt) {
    stopTimer();
    show(callTimer);
    const start = Number(startedAt || 0) > 0 ? Number(startedAt) * 1000 : Date.now();
    const tick = () => {
        const diff = Math.max(0, Math.floor((Date.now() - start) / 1000));
        callTimer.textContent = `${String(Math.floor(diff / 60)).padStart(2, '0')}:${String(diff % 60).padStart(2, '0')}`;
    };
    tick();
    timerInterval = setInterval(tick, 1000);
}

function renderHome(state = {}) {
    homeNumber.textContent = state.myNumber ? `Numar: ${state.myNumber}` : 'Numar nesetat';

    if (state.inCall) {
        show(homeBanner);
        homeBannerText.textContent = state.incoming
            ? `Te suna ${state.otherNumber || 'necunoscut'}`
            : state.outgoing
                ? `Suni la ${state.otherNumber || 'necunoscut'}`
                : `In apel cu ${state.otherNumber || 'necunoscut'}`;
    } else {
        hide(homeBanner);
    }
}

function renderPeek(state = {}) {
    peekNumber.textContent = state.otherNumber || 'Necunoscut';
    switchScreen('peek');
}

function applyCallSounds(state = {}) {
    if (!state.inCall) {
        stopRings();
        return;
    }

    if (state.outgoing) {
        stopSound('ring2');
        playSound('ring');
        return;
    }

    if (state.incoming) {
        stopSound('ring');
        playSound('ring2');
        return;
    }

    if (state.active) {
        stopRings();
    }
}

function renderState(state = {}) {
    lastState = state || {};

    const ownNumber = lastState.myNumber || '';
    myNumber.textContent = ownNumber || 'Numar nesetat';
    renderHome(lastState);
    applyCallSounds(lastState);

    if (!ownNumber) {
        setDialStatus('error', 'Telefon inactiv', 'Nu ai users.phonenumber setat.', 'assets/warning.svg');
    } else {
        setDialStatus('idle', 'Ready', 'Scrie un numar si apasa apelare.', 'assets/phone.svg');
    }

    hide(incomingActions);
    hide(hangupBtn);
    stopTimer();

    if (lastState.inCall) {
        if (isPeek && lastState.incoming) {
            renderPeek(lastState);
            return;
        }

        switchScreen('call');
        otherNumber.textContent = lastState.otherNumber || 'Necunoscut';

        if (lastState.incoming) {
            callMode.textContent = 'Apel primit';
            callSubtitle.textContent = 'Telefonul suna. Poti raspunde sau respinge.';
            show(incomingActions);
            hide(hangupBtn);
        } else if (lastState.outgoing) {
            callMode.textContent = 'Se apeleaza';
            callSubtitle.textContent = 'Asteapta raspunsul persoanei apelate.';
            hide(incomingActions);
            show(hangupBtn);
        } else if (lastState.active) {
            callMode.textContent = 'Apel activ';
            callSubtitle.textContent = 'Tine N ca sa vorbesti. Oamenii de langa tine te aud normal, dar nu aud persoana din telefon.';
            hide(incomingActions);
            show(hangupBtn);
            startTimer(lastState.startedAt);
        }
        return;
    }

    if (isPeek) {
        hideRootAnimated();
        return;
    }

    if (currentScreen === 'call') switchScreen('home');
}

function handleFeedback(payload = {}) {
    const sound = String(payload.sound || '').toLowerCase();
    const title = payload.title || 'Telefon';
    const text = payload.text || '';
    const kind = String(payload.kind || 'info').toLowerCase();

    if (sound === 'decline') {
        stopRings();
        playSound('decline');
    } else if (sound === 'ring') {
        stopSound('ring2');
        playSound('ring');
    } else if (sound === 'ring2') {
        stopSound('ring');
        playSound('ring2');
    }

    if (kind === 'error' || kind === 'busy' || kind === 'declined' || kind === 'missed' || kind === 'ended') {
        setDialStatus('error', title, text, 'assets/warning.svg');
    } else {
        setDialStatus('idle', title, text, 'assets/phone.svg');
    }
}

numberInput.addEventListener('input', () => { numberInput.value = cleanNumber(numberInput.value); });
numberInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') dial(); });

document.addEventListener('keydown', (e) => {
    if (!isOpen) return;
    if (e.key === 'Escape') requestClosePhone();
    if (e.key === 'Backspace' && currentScreen === 'dial' && document.activeElement !== numberInput) backspace();
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);

    if (data.action === 'setup') {
        return;
    }

    if (data.action === 'focus') {
        setFocusUi(data.focus === true);
        return;
    }

    if (data.action === 'open') {
        showRoot('full');
        renderState(data.state || lastState || {});
        if (!(lastState && lastState.inCall)) switchScreen('home');
        return;
    }

    if (data.action === 'peek') {
        showRoot('peek');
        renderState(data.state || lastState || {});
        renderPeek(data.state || lastState || {});
        return;
    }

    if (data.action === 'close') {
        hideRootAnimated();
        return;
    }

    if (data.action === 'state' || data.action === 'incoming') {
        renderState(data.state || {});
        return;
    }

    if (data.action === 'feedback') {
        handleFeedback(data.payload || {});
    }
});

updateClock();
setInterval(updateClock, 1000);
setTimeout(() => nui('ready'), 80);
