'use strict';

const root = document.getElementById('phoneRoot');
const clockEl = document.getElementById('clock');
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

let open = false;
let lastState = {};
let audioCtx = null;
let ringTimer = null;
let timerInterval = null;
let currentScreen = 'home';

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }

function cleanNumber(value) {
    return String(value || '').replace(/[^0-9]/g, '').slice(0, 32);
}

function updateClock() {
    const d = new Date();
    const h = String(d.getHours()).padStart(2, '0');
    const m = String(d.getMinutes()).padStart(2, '0');
    clockEl.textContent = `${h}:${m}`;
}

function switchScreen(name) {
    currentScreen = name;
    hide(homeView);
    hide(dialView);
    hide(callView);

    if (name === 'dial') show(dialView);
    else if (name === 'call') show(callView);
    else show(homeView);
}

function openDialer() {
    if (lastState && lastState.inCall) return switchScreen('call');
    switchScreen('dial');
    setTimeout(() => numberInput.focus(), 60);
}

function goHome() {
    if (lastState && lastState.inCall) return switchScreen('call');
    switchScreen('home');
}

function setDialStatus(cls, title, text, icon) {
    dialStatus.className = `dial-status ${cls || 'idle'}`;
    dialStatusTitle.textContent = title || 'Ready';
    dialStatusText.textContent = text || '';
    if (icon) dialStatusIcon.src = icon;
}

function pressKey(key) {
    numberInput.value = cleanNumber(numberInput.value + key);
}

function clearNumber() {
    numberInput.value = '';
}

function backspace() {
    numberInput.value = cleanNumber(numberInput.value).slice(0, -1);
}

function dial() {
    const number = cleanNumber(numberInput.value);
    if (!number) {
        setDialStatus('error', 'Numar invalid', 'Scrie un numar de telefon.', 'assets/warning.svg');
        return;
    }
    stopRing();
    nui('dial', { number });
}

function answer() { stopRing(); nui('answer'); }
function decline() { stopRing(); nui('decline'); }
function hangup() { stopRing(); nui('hangup'); }

function closePhone() {
    open = false;
    stopRing();
    hide(root);
    nui('close');
}

function ensureAudio() {
    try {
        if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        if (audioCtx.state === 'suspended') audioCtx.resume();
        return audioCtx;
    } catch (e) {
        return null;
    }
}

function beep(freq, duration, delay) {
    const ctx = ensureAudio();
    if (!ctx) return;

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.value = freq;
    gain.gain.value = 0.0001;

    osc.connect(gain);
    gain.connect(ctx.destination);

    const start = ctx.currentTime + (delay || 0);
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.052, start + 0.025);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

    osc.start(start);
    osc.stop(start + duration + 0.03);
}

function startRing() {
    if (ringTimer) return;
    beep(920, 0.17, 0);
    beep(680, 0.17, 0.23);
    ringTimer = setInterval(() => {
        beep(920, 0.17, 0);
        beep(680, 0.17, 0.23);
    }, 1420);
}

function stopRing() {
    if (ringTimer) {
        clearInterval(ringTimer);
        ringTimer = null;
    }
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
        const m = String(Math.floor(diff / 60)).padStart(2, '0');
        const s = String(diff % 60).padStart(2, '0');
        callTimer.textContent = `${m}:${s}`;
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

function renderState(state = {}) {
    lastState = state || {};

    const ownNumber = lastState.myNumber || '';
    myNumber.textContent = ownNumber || 'Numar nesetat';
    renderHome(lastState);

    if (!ownNumber) {
        setDialStatus('error', 'Telefon inactiv', 'Nu ai users.phonenumber setat.', 'assets/warning.svg');
    } else {
        setDialStatus('idle', 'Ready', 'Scrie un numar si apasa apelare.', 'assets/phone.svg');
    }

    hide(incomingActions);
    hide(hangupBtn);
    stopTimer();

    if (lastState.inCall) {
        switchScreen('call');
        otherNumber.textContent = lastState.otherNumber || 'Necunoscut';

        if (lastState.incoming) {
            callMode.textContent = 'Apel primit';
            callSubtitle.textContent = 'Telefonul suna. Poti raspunde sau respinge.';
            show(incomingActions);
            hide(hangupBtn);
            startRing();
        } else if (lastState.outgoing) {
            callMode.textContent = 'Se apeleaza';
            callSubtitle.textContent = 'Asteapta raspunsul persoanei apelate.';
            hide(incomingActions);
            show(hangupBtn);
            stopRing();
        } else if (lastState.active) {
            callMode.textContent = 'Apel activ';
            callSubtitle.textContent = 'Vorbesti prin DriftZone VoiceChat. Tine N ca sa vorbesti.';
            hide(incomingActions);
            show(hangupBtn);
            stopRing();
            startTimer(lastState.startedAt);
        }
        return;
    }

    stopRing();
    if (currentScreen === 'call') switchScreen('home');
}

numberInput.addEventListener('input', () => {
    numberInput.value = cleanNumber(numberInput.value);
});

numberInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') dial();
});

document.addEventListener('keydown', (e) => {
    if (!open) return;
    if (e.key === 'Escape') closePhone();
    if (e.key === 'Backspace' && currentScreen === 'dial' && document.activeElement !== numberInput) backspace();
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'setup') {
        if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
    }

    if (data.action === 'open') {
        open = true;
        if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
        show(root);
        renderState(data.state || lastState || {});
        if (!(lastState && lastState.inCall)) switchScreen('home');
    }

    if (data.action === 'close') {
        open = false;
        hide(root);
        stopRing();
        stopTimer();
    }

    if (data.action === 'state' || data.action === 'incoming') {
        renderState(data.state || {});
    }
});

updateClock();
setInterval(updateClock, 1000);
setTimeout(() => nui('ready'), 80);
