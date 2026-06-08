'use strict';

const app = document.getElementById('app');
const selectorView = document.getElementById('selectorView');
const menuView = document.getElementById('menuView');
const payView = document.getElementById('payView');
const playerName = document.getElementById('playerName');
const playerId = document.getElementById('playerId');
const payTargetName = document.getElementById('payTargetName');
const payTargetId = document.getElementById('payTargetId');
const amountInput = document.getElementById('amountInput');
const payError = document.getElementById('payError');
const confirmPayBtn = document.getElementById('confirmPay');

let selectedPlayer = null;
let payLocked = false;
let selectorMoveTimer = 0;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(el) {
    if (el) el.classList.remove('hidden');
}

function hide(el) {
    if (el) el.classList.add('hidden');
}

function setMainColor(color) {
    if (color) document.documentElement.style.setProperty('--main', String(color));
}

function onlyNumbers(value) {
    return String(value || '').replace(/[^0-9]/g, '');
}

function setError(message) {
    if (!payError) return;
    if (!message) {
        payError.textContent = '';
        payError.classList.add('hidden');
        return;
    }
    payError.textContent = String(message);
    payError.classList.remove('hidden');
}

function resetPayButton() {
    payLocked = false;
    confirmPayBtn.disabled = false;
    confirmPayBtn.querySelector('span').textContent = 'CONFIRM TRANSFER';
}

function openSelector(data = {}) {
    setMainColor(data.mainColor);
    selectedPlayer = null;
    setError('');
    show(app);
    show(selectorView);
    hide(menuView);
    hide(payView);
}

function openMenu(data = {}) {
    selectedPlayer = data.player || data || {};
    setMainColor(data.mainColor);
    playerName.textContent = selectedPlayer.name || 'Player';
    playerId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    setError('');
    resetPayButton();
    show(app);
    hide(selectorView);
    show(menuView);
    hide(payView);
}

function openPayView(data = {}) {
    selectedPlayer = data.player || selectedPlayer || {};
    payTargetName.textContent = selectedPlayer.name || 'Player';
    payTargetId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    amountInput.value = '';
    resetPayButton();
    setError('');
    show(app);
    hide(selectorView);
    hide(menuView);
    show(payView);
    setTimeout(() => amountInput.focus(), 40);
}

function closeUiLocal() {
    hide(app);
    hide(selectorView);
    hide(menuView);
    hide(payView);
    setError('');
    selectedPlayer = null;
    payLocked = false;
}

function closeUi() {
    closeUiLocal();
    nui('close');
}

function openPay() {
    nui('openPay');
}

function quickAmount(value) {
    amountInput.value = String(value);
    setError('');
}

function confirmPay() {
    if (payLocked) return;
    const amount = Number(onlyNumbers(amountInput.value));
    if (!Number.isFinite(amount) || amount <= 0) {
        setError('Pune o suma valida.');
        return;
    }

    payLocked = true;
    confirmPayBtn.disabled = true;
    confirmPayBtn.querySelector('span').textContent = 'SE TRIMITE...';

    // Cerinta: imediat dupa PAY dispare UI-ul.
    nui('pay', { amount });
    closeUiLocal();
}

if (amountInput) {
    amountInput.addEventListener('input', () => {
        const clean = onlyNumbers(amountInput.value);
        if (amountInput.value !== clean) amountInput.value = clean;
        setError('');
    });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openSelector') openSelector(data);
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'openPay') openPayView(data);
    if (data.action === 'closeAll') closeUiLocal();
    if (data.action === 'payResult') {
        if (data.ok) {
            closeUiLocal();
        } else if (!payView.classList.contains('hidden')) {
            resetPayButton();
            setError(data.message || 'Plata a esuat.');
        }
    }
});

window.addEventListener('keydown', (e) => {
    // Nu exista UI cu ESC/X, dar tasta ramane ca fallback de siguranta.
    if (e.key === 'Escape') closeUi();
    if (e.key === 'Enter' && !payView.classList.contains('hidden')) confirmPay();
});

window.addEventListener('mousemove', (e) => {
    if (selectorView.classList.contains('hidden')) return;
    const now = Date.now();
    if (now - selectorMoveTimer < 16) return;
    selectorMoveTimer = now;
    nui('mouseMove', {
        x: e.clientX / Math.max(1, window.innerWidth),
        y: e.clientY / Math.max(1, window.innerHeight)
    });
});

window.addEventListener('mousedown', (e) => {
    if (selectorView.classList.contains('hidden')) return;
    if (e.button !== 0) return;
    nui('selectClick');
});

document.addEventListener('DOMContentLoaded', () => {
    nui('ready');
});
