'use strict';

const app = document.getElementById('app');
const radialView = document.getElementById('radialView');
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

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function setMainColor(color) {
    if (color) document.documentElement.style.setProperty('--main', color);
}

function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }

function setError(message) {
    if (!message) {
        payError.textContent = '';
        payError.classList.add('hidden');
        return;
    }
    payError.textContent = message;
    payError.classList.remove('hidden');
}

function openMenu(data) {
    selectedPlayer = data.player || data || {};
    setMainColor(data.mainColor);
    playerName.textContent = selectedPlayer.name || 'Player';
    playerId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    show(app);
    show(radialView);
    hide(payView);
    setError('');
}

function openPayView(data = {}) {
    selectedPlayer = data.player || selectedPlayer || {};
    payTargetName.textContent = selectedPlayer.name || 'Player';
    payTargetId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    amountInput.value = '';
    payLocked = false;
    confirmPayBtn.disabled = false;
    confirmPayBtn.textContent = 'CONFIRM';
    setError('');
    show(app);
    hide(radialView);
    show(payView);
    setTimeout(() => amountInput.focus(), 80);
}

function closeUi() {
    hide(app);
    hide(radialView);
    hide(payView);
    setError('');
    selectedPlayer = null;
    payLocked = false;
    nui('close');
}

function openPay() {
    nui('openPay');
}

function backToMenu() {
    nui('backToMenu');
}

function confirmPay() {
    if (payLocked) return;
    const amount = Number(amountInput.value || 0);
    if (!Number.isFinite(amount) || amount <= 0) {
        setError('Pune o suma valida.');
        return;
    }
    payLocked = true;
    confirmPayBtn.disabled = true;
    confirmPayBtn.textContent = 'SE TRIMITE...';
    nui('pay', { amount });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'openPay') openPayView(data);
    if (data.action === 'closeAll') closeUiLocal();
    if (data.action === 'payResult') {
        payLocked = false;
        confirmPayBtn.disabled = false;
        confirmPayBtn.textContent = 'CONFIRM';
        if (data.ok) {
            setError('');
            confirmPayBtn.textContent = 'TRIMIS';
        } else {
            setError(data.message || 'Plata a esuat.');
        }
    }
});

function closeUiLocal() {
    hide(app);
    hide(radialView);
    hide(payView);
    setError('');
}

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeUi();
    if (e.key === 'Enter' && !payView.classList.contains('hidden')) confirmPay();
});

document.addEventListener('DOMContentLoaded', () => {
    nui('ready');
});
