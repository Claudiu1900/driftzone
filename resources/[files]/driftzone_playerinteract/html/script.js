'use strict';

const app = document.getElementById('app');
const selectorView = document.getElementById('selectorView');
const radialView = document.getElementById('radialView');
const payView = document.getElementById('payView');
const actionsLayer = document.getElementById('actionsLayer');
const playerName = document.getElementById('playerName');
const playerId = document.getElementById('playerId');
const payTargetName = document.getElementById('payTargetName');
const payTargetId = document.getElementById('payTargetId');
const amountInput = document.getElementById('amountInput');
const payError = document.getElementById('payError');
const confirmPayBtn = document.getElementById('confirmPay');

let selectedPlayer = null;
let availableActions = [];
let payLocked = false;
let selectorMoveTimer = 0;

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
function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function defaultActions() {
    return [{ id: 'pay', label: 'PAY', title: 'Trimite bani', description: 'Transfer cash catre player' }];
}

function setError(message) {
    if (!message) {
        payError.textContent = '';
        payError.classList.add('hidden');
        return;
    }
    payError.textContent = message;
    payError.classList.remove('hidden');
}

function openSelector(data = {}) {
    setMainColor(data.mainColor);
    show(app);
    app.classList.add('selecting');
    show(selectorView);
    hide(radialView);
    hide(payView);
    setError('');
}

function buildActionButton(action, index, total) {
    const spread = total <= 1 ? 0 : 210;
    const start = total <= 1 ? 0 : -spread / 2;
    const angle = total <= 1 ? 0 : start + (spread / Math.max(1, total - 1)) * index;
    const radius = total <= 1 ? 520 : 560;
    const rad = (angle - 90) * Math.PI / 180;
    const x = Math.cos(rad) * radius;
    const y = Math.sin(rad) * radius;
    const side = x < -60 ? 'left' : (x > 60 ? 'right' : 'center');

    return `
        <button class="action-card ${side}" style="--x:${x.toFixed(2)}px;--y:${y.toFixed(2)}px;--delay:${index * 70}ms" onclick="runAction('${escapeHtml(action.id)}')">
            <i>${String(index + 1).padStart(2, '0')}</i>
            <div>
                <span>${escapeHtml(action.title || action.label || action.id)}</span>
                <b>${escapeHtml(action.label || action.id)}</b>
                <small>${escapeHtml(action.description || '')}</small>
            </div>
        </button>`;
}

function renderActions(actions) {
    availableActions = Array.isArray(actions) && actions.length ? actions.filter(a => a && a.id) : defaultActions();
    actionsLayer.innerHTML = availableActions.map(buildActionButton).join('');
}

function openMenu(data = {}) {
    app.classList.remove('selecting');
    hide(selectorView);
    selectedPlayer = data.player || data || {};
    setMainColor(data.mainColor);
    playerName.textContent = selectedPlayer.name || 'Player';
    playerId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    renderActions(data.actions);
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
    confirmPayBtn.querySelector('span').textContent = 'CONFIRM TRANSFER';
    setError('');
    show(app);
    hide(radialView);
    show(payView);
    setTimeout(() => amountInput.focus(), 80);
}

function closeUi() {
    app.classList.remove('selecting');
    hide(app);
    hide(selectorView);
    hide(radialView);
    hide(payView);
    setError('');
    selectedPlayer = null;
    availableActions = [];
    payLocked = false;
    nui('close');
}

function closeUiLocal() {
    app.classList.remove('selecting');
    hide(app);
    hide(selectorView);
    hide(radialView);
    hide(payView);
    setError('');
}

function runAction(id) {
    if (id === 'pay') {
        nui('openPay');
    }
}

function openPay() {
    nui('openPay');
}

function backToMenu() {
    nui('backToMenu');
}

function quickAmount(value) {
    amountInput.value = String(value);
    setError('');
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
    confirmPayBtn.querySelector('span').textContent = 'SE TRIMITE...';
    nui('pay', { amount });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openSelector') openSelector(data);
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'openPay') openPayView(data);
    if (data.action === 'closeAll') closeUiLocal();
    if (data.action === 'payResult') {
        payLocked = false;
        confirmPayBtn.disabled = false;
        confirmPayBtn.querySelector('span').textContent = 'CONFIRM TRANSFER';
        if (data.ok) {
            setError('');
            confirmPayBtn.querySelector('span').textContent = 'TRIMIS CU SUCCES';
        } else {
            setError(data.message || 'Plata a esuat.');
        }
    }
});

window.addEventListener('keydown', (e) => {
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
