'use strict';

const app = document.getElementById('app');
const selectorView = document.getElementById('selectorView');
const radialView = document.getElementById('radialView');
const payView = document.getElementById('payView');
const tradeView = document.getElementById('tradeView');
const actionsLayer = document.getElementById('actionsLayer');
const playerName = document.getElementById('playerName');
const playerId = document.getElementById('playerId');
const payTargetName = document.getElementById('payTargetName');
const payTargetId = document.getElementById('payTargetId');
const amountInput = document.getElementById('amountInput');
const payError = document.getElementById('payError');
const confirmPayBtn = document.getElementById('confirmPay');

const tradeModeText = document.getElementById('tradeModeText');
const tradeTitle = document.getElementById('tradeTitle');
const tradeSubtitle = document.getElementById('tradeSubtitle');
const tradeTimer = document.getElementById('tradeTimer');
const tradeOfferPreview = document.getElementById('tradeOfferPreview');
const myTradeVehicles = document.getElementById('myTradeVehicles');
const targetTradeVehicles = document.getElementById('targetTradeVehicles');
const tradeTargetName = document.getElementById('tradeTargetName');
const tradeMoneyInput = document.getElementById('tradeMoneyInput');
const tradeError = document.getElementById('tradeError');
const tradeSubmitBtn = document.getElementById('tradeSubmitBtn');

let selectedPlayer = null;
let availableActions = [];
let payLocked = false;
let selectorMoveTimer = 0;
let tradeState = null;
let selectedTradeVehicle = null;
let tradeCountdown = null;

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

function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }
function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function money(n) {
    const value = Number(n || 0);
    return '$' + value.toLocaleString('en-US');
}

function defaultActions() {
    return [
        { id: 'pay', label: 'PAY', title: 'Trimite bani', description: 'Transfer cash catre player' },
        { id: 'trade', label: 'TRADE', title: 'Schimba masini', description: 'Trade masini si cash' }
    ];
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

function setTradeError(message) {
    if (!message) {
        tradeError.textContent = '';
        tradeError.classList.add('hidden');
        return;
    }
    tradeError.textContent = message;
    tradeError.classList.remove('hidden');
}

function openSelector(data = {}) {
    setMainColor(data.mainColor);
    show(app);
    app.classList.add('selecting');
    show(selectorView);
    hide(radialView);
    hide(payView);
    hide(tradeView);
    setError('');
    setTradeError('');
}

function buildActionButton(action, index, total) {
    let x = 0;
    let y = 0;

    if (total <= 1) {
        x = 520;
        y = 0;
    } else {
        const gap = 134;
        x = 520;
        y = (index - ((total - 1) / 2)) * gap;
    }

    const side = x < -60 ? 'left' : (x > 60 ? 'right' : 'center');
    const special = action.id === 'trade' ? 'trade-action-card' : (action.id === 'pay' ? 'pay-action-card' : '');

    return `
        <button class="action-card ${side} ${special}" style="--x:${x.toFixed(2)}px;--y:${y.toFixed(2)}px;--delay:${index * 70}ms" onclick="runAction('${escapeHtml(action.id)}')">
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
    hide(tradeView);
    setError('');
    setTradeError('');
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
    hide(tradeView);
    show(payView);
    setTimeout(() => amountInput.focus(), 80);
}

function closeUi() {
    app.classList.remove('selecting');
    hide(app);
    hide(selectorView);
    hide(radialView);
    hide(payView);
    hide(tradeView);
    setError('');
    setTradeError('');
    selectedPlayer = null;
    availableActions = [];
    payLocked = false;
    clearTradeTimer();
    nui('close');
}

function closeUiLocal() {
    app.classList.remove('selecting');
    hide(app);
    hide(selectorView);
    hide(radialView);
    hide(payView);
    hide(tradeView);
    setError('');
    setTradeError('');
    clearTradeTimer();
}

function runAction(id) {
    if (id === 'pay') nui('openPay');
    if (id === 'trade') nui('openTrade');
}

function backToMenu() { nui('backToMenu'); }
function quickAmount(value) { amountInput.value = String(value); setError(''); }

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

function clearTradeTimer() {
    if (tradeCountdown) clearInterval(tradeCountdown);
    tradeCountdown = null;
}

function startTradeTimer(seconds) {
    clearTradeTimer();
    let left = Math.max(0, Number(seconds || 30));
    tradeTimer.textContent = String(left);
    tradeCountdown = setInterval(() => {
        left -= 1;
        if (left <= 0) {
            left = 0;
            clearTradeTimer();
        }
        tradeTimer.textContent = String(left);
    }, 1000);
}

function vehicleLabel(v) {
    const name = v.name || v.vehicle_name || v.model || 'Vehicul';
    const plate = v.plate || v.vehicle_plate || 'NO PLATE';
    return { name, plate };
}

function renderVehicleList(container, vehicles, selectable) {
    const list = Array.isArray(vehicles) ? vehicles : [];
    if (!list.length) {
        container.innerHTML = '<div class="trade-empty">Nu exista masini.</div>';
        return;
    }
    container.innerHTML = list.map(v => {
        const id = String(v.id ?? '');
        const lbl = vehicleLabel(v);
        const cls = selectable && String(selectedTradeVehicle || '') === id ? 'selected' : '';
        return `<button class="trade-vehicle ${cls}" ${selectable ? `onclick="selectTradeVehicle('${escapeHtml(id)}')"` : ''}>
            <b>${escapeHtml(lbl.name)}</b>
            <small>${escapeHtml(lbl.plate)}</small>
        </button>`;
    }).join('');
}

function selectTradeVehicle(id) {
    selectedTradeVehicle = selectedTradeVehicle === id ? null : id;
    renderVehicleList(myTradeVehicles, tradeState?.myVehicles || [], true);
    setTradeError('');
}

function renderOfferPreview(offer, title) {
    if (!offer) {
        hide(tradeOfferPreview);
        tradeOfferPreview.innerHTML = '';
        return;
    }
    const veh = offer.vehicle;
    const cash = Number(offer.money || 0);
    const vehText = veh ? `${escapeHtml(vehicleLabel(veh).name)} <small>${escapeHtml(vehicleLabel(veh).plate)}</small>` : 'Fara masina';
    tradeOfferPreview.innerHTML = `
        <span>${escapeHtml(title || 'OFERTA PRIMITA')}</span>
        <div><b>Masina:</b> ${vehText}</div>
        <div><b>Bani:</b> ${money(cash)}</div>`;
    show(tradeOfferPreview);
}

function openTradeView(payload = {}, mode = 'create') {
    tradeState = payload;
    selectedTradeVehicle = null;
    setMainColor(payload.mainColor);
    const target = payload.target || payload.from || {};
    tradeTargetName.textContent = target.name || 'Player';
    tradeMoneyInput.value = '0';
    setTradeError('');
    hide(selectorView);
    hide(radialView);
    hide(payView);
    show(app);
    show(tradeView);

    if (mode === 'incoming') {
        tradeModeText.textContent = 'TRADE REQUEST';
        tradeTitle.textContent = 'Accepta trade';
        tradeSubtitle.textContent = `${target.name || 'Player'} ti-a trimis trade. Alege ce dai inapoi.`;
        tradeSubmitBtn.querySelector('span').textContent = 'ACCEPTA TRADE';
        renderOfferPreview(payload.offer, 'OFERTA CELUILALT PLAYER');
    } else {
        tradeModeText.textContent = 'DRIFTZONE TRADE';
        tradeTitle.textContent = 'Vehicle Trade';
        tradeSubtitle.textContent = `Trimite trade catre ${target.name || 'Player'}. El trebuie sa accepte in 30 secunde.`;
        tradeSubmitBtn.querySelector('span').textContent = 'TRIMITE TRADE';
        renderOfferPreview(null);
    }

    renderVehicleList(myTradeVehicles, payload.myVehicles || [], true);
    renderVehicleList(targetTradeVehicles, payload.targetVehicles || payload.fromVehicles || [], false);
    startTradeTimer(payload.timeout || 30);
}

function submitTrade() {
    if (!tradeState) return;
    const moneyValue = Number(tradeMoneyInput.value || 0);
    if (!Number.isFinite(moneyValue) || moneyValue < 0) {
        setTradeError('Suma trebuie sa fie 0 sau mai mare.');
        return;
    }
    const payload = {
        requestId: tradeState.requestId,
        target: tradeState.target?.serverId,
        vehicleId: selectedTradeVehicle ? Number(selectedTradeVehicle) : 0,
        money: Math.floor(moneyValue)
    };
    tradeSubmitBtn.disabled = true;
    tradeSubmitBtn.querySelector('span').textContent = tradeState.mode === 'incoming' ? 'SE ACCEPTA...' : 'SE TRIMITE...';
    if (tradeState.mode === 'incoming') nui('answerTrade', payload);
    else nui('sendTradeOffer', payload);
}

function cancelTradeUi() {
    nui('cancelTrade', { requestId: tradeState?.requestId });
    closeUi();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openSelector') openSelector(data);
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'openPay') openPayView(data);
    if (data.action === 'closeAll') closeUiLocal();
    if (data.action === 'openTrade') {
        const p = data.payload || {};
        p.mode = 'create';
        openTradeView(p, 'create');
    }
    if (data.action === 'tradeIncoming') {
        const p = data.payload || {};
        p.mode = 'incoming';
        openTradeView(p, 'incoming');
    }
    if (data.action === 'tradeStatus') {
        const p = data.payload || {};
        tradeSubmitBtn.disabled = false;
        tradeSubmitBtn.querySelector('span').textContent = tradeState?.mode === 'incoming' ? 'ACCEPTA TRADE' : 'TRIMITE TRADE';
        if (p.ok) {
            setTradeError(p.message || 'Trade trimis. Asteapta raspuns.');
        } else {
            setTradeError(p.message || 'Trade esuat.');
        }
    }
    if (data.action === 'tradeClose') {
        setTradeError(data.message || 'Trade finalizat.');
        setTimeout(closeUiLocal, 650);
    }
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
