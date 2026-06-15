'use strict';

const root = document.getElementById('phoneRoot');
const myNumber = document.getElementById('myNumber');
const numberInput = document.getElementById('numberInput');
const statusCard = document.getElementById('statusCard');
const statusIcon = document.getElementById('statusIcon');
const statusTitle = document.getElementById('statusTitle');
const statusText = document.getElementById('statusText');
const dialView = document.getElementById('dialView');
const callView = document.getElementById('callView');
const callMode = document.getElementById('callMode');
const otherNumber = document.getElementById('otherNumber');
const callSubtitle = document.getElementById('callSubtitle');
const incomingActions = document.getElementById('incomingActions');
const hangupBtn = document.getElementById('hangupBtn');

let lastState = {};
let open = false;
let audioCtx = null;
let ringTimer = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(el) { el && el.classList.remove('hidden'); }
function hide(el) { el && el.classList.add('hidden'); }

function setStatus(type, title, text, icon) {
    statusCard.className = `status-card ${type || 'idle'}`;
    statusTitle.textContent = title || 'Ready';
    statusText.textContent = text || '';
    statusIcon.src = icon || 'assets/phone.svg';
}

function cleanNumber(value) {
    return String(value || '').replace(/\D/g, '').slice(0, 16);
}

function pressKey(key) {
    numberInput.value = cleanNumber(numberInput.value + key);
}

function backspace() {
    numberInput.value = cleanNumber(numberInput.value).slice(0, -1);
}

function clearNumber() {
    numberInput.value = '';
}

function dial() {
    const number = cleanNumber(numberInput.value);
    if (!number) {
        setStatus('error', 'Număr invalid', 'Introdu un număr de telefon.', 'assets/warning.svg');
        return;
    }
    nui('dial', { number });
}

function answer() { stopRing(); nui('answer'); }
function decline() { stopRing(); nui('decline'); }
function hangup() { stopRing(); nui('hangup'); }
function closePhone() { open = false; stopRing(); hide(root); nui('close'); }

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
    gain.gain.exponentialRampToValueAtTime(0.055, start + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);

    osc.start(start);
    osc.stop(start + duration + 0.02);
}

function startRing() {
    if (ringTimer) return;
    beep(880, 0.16, 0);
    beep(660, 0.16, 0.20);
    ringTimer = setInterval(() => {
        beep(880, 0.16, 0);
        beep(660, 0.16, 0.20);
    }, 1450);
}

function stopRing() {
    if (ringTimer) {
        clearInterval(ringTimer);
        ringTimer = null;
    }
}

function renderState(state = {}) {
    lastState = state || {};

    myNumber.textContent = lastState.myNumber || 'Nesetat';

    if (!lastState.myNumber) {
        setStatus('error', 'Telefon inactiv', 'Nu ai users.phonenumber setat.', 'assets/warning.svg');
    } else {
        setStatus('idle', 'Ready', 'Formează un număr de telefon.', 'assets/phone.svg');
    }

    hide(callView);
    show(dialView);
    hide(incomingActions);
    hide(hangupBtn);

    if (lastState.inCall) {
        hide(dialView);
        show(callView);

        otherNumber.textContent = lastState.otherNumber || 'Necunoscut';

        if (lastState.incoming) {
            callMode.textContent = 'Apel primit';
            callSubtitle.textContent = 'Te sună acum.';
            setStatus('ringing', 'Apel primit', `Te sună ${lastState.otherNumber || 'necunoscut'}.`, 'assets/call.svg');
            show(incomingActions);
            hide(hangupBtn);
            startRing();
        } else if (lastState.outgoing) {
            callMode.textContent = 'Se apelează';
            callSubtitle.textContent = 'Așteaptă răspunsul.';
            setStatus('ringing', 'Se apelează', `Suni la ${lastState.otherNumber || 'necunoscut'}.`, 'assets/call.svg');
            hide(incomingActions);
            show(hangupBtn);
            stopRing();
        } else if (lastState.active) {
            callMode.textContent = 'Apel activ';
            callSubtitle.textContent = 'Vorbești prin DriftZone VoiceChat. Ține N ca să vorbești.';
            setStatus('active', 'Apel conectat', 'Folosește push-to-talk pe N.', 'assets/call.svg');
            hide(incomingActions);
            show(hangupBtn);
            stopRing();
        }
    } else {
        stopRing();
    }
}

numberInput.addEventListener('input', () => {
    numberInput.value = cleanNumber(numberInput.value);
});

numberInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') dial();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closePhone();
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
        setTimeout(() => numberInput.focus(), 80);
    }

    if (data.action === 'close') {
        open = false;
        hide(root);
        stopRing();
    }

    if (data.action === 'state' || data.action === 'incoming') {
        renderState(data.state || {});
    }
});

setTimeout(() => nui('ready'), 80);
