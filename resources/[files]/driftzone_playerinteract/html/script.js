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
const tradeOfferPreview = document.getElementById('tradeOfferPreview');
const myTradeVehicles = document.getElementById('myTradeVehicles');
const targetTradeVehicles = document.getElementById('targetTradeVehicles');
const tradeTargetName = document.getElementById('tradeTargetName');
const tradeMoneyInput = document.getElementById('tradeMoneyInput');
const tradeError = document.getElementById('tradeError');
const tradeSubmitBtn = document.getElementById('tradeSubmitBtn');
const myConfirmStatus = document.getElementById('myConfirmStatus');
const theirConfirmStatus = document.getElementById('theirConfirmStatus');

let selectedPlayer = null;
let availableActions = [];
let payLocked = false;
let selectorMoveTimer = 0;
let tradeState = null;
let selectedTradeVehicles = new Set();
let tradeMoneyTimer = null;
let tradeConfirmed = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}
function setMainColor(color) { if (color) document.documentElement.style.setProperty('--main', color); }
function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }
function escapeHtml(value) {
    return String(value ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}
function money(n) { return '$' + Number(n || 0).toLocaleString('en-US'); }
function defaultActions() {
    return [
        { id: 'pay', label: 'PAY', title: 'Trimite bani', description: 'Transfer cash catre player' },
        { id: 'trade', label: 'TRADE', title: 'Schimba masini', description: 'Trade masini si bani' }
    ];
}
function setError(message) {
    if (!message) { payError.textContent = ''; payError.classList.add('hidden'); return; }
    payError.textContent = message; payError.classList.remove('hidden');
}
function setTradeError(message) {
    if (!message) { tradeError.textContent = ''; tradeError.classList.add('hidden'); return; }
    tradeError.textContent = message; tradeError.classList.remove('hidden');
}
function openSelector(data = {}) {
    setMainColor(data.mainColor); show(app); app.classList.add('selecting'); show(selectorView);
    hide(radialView); hide(payView); hide(tradeView); setError(''); setTradeError('');
}
function buildActionButton(action, index) {
    const special = action.id === 'trade' ? 'trade-action-card' : (action.id === 'pay' ? 'pay-action-card' : '');
    const posClass = action.id === 'trade' ? 'left' : 'right';
    return `<button class="action-card ${posClass} ${special}" style="--x:0px;--y:0px;--delay:${index * 70}ms" onclick="runAction('${escapeHtml(action.id)}')">
        <i>${String(index + 1).padStart(2, '0')}</i>
        <div><span>${escapeHtml(action.title || action.label || action.id)}</span><b>${escapeHtml(action.label || action.id)}</b><small>${escapeHtml(action.description || '')}</small></div>
    </button>`;
}
function renderActions(actions) {
    availableActions = Array.isArray(actions) && actions.length ? actions.filter(a => a && a.id) : defaultActions();
    actionsLayer.innerHTML = availableActions.map(buildActionButton).join('');
}
function openMenu(data = {}) {
    app.classList.remove('selecting'); hide(selectorView); selectedPlayer = data.player || data || {};
    setMainColor(data.mainColor); playerName.textContent = selectedPlayer.name || 'Player'; playerId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    renderActions(data.actions); show(app); show(radialView); hide(payView); hide(tradeView); setError(''); setTradeError('');
}
function openPayView(data = {}) {
    selectedPlayer = data.player || selectedPlayer || {}; payTargetName.textContent = selectedPlayer.name || 'Player'; payTargetId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    amountInput.value = ''; payLocked = false; confirmPayBtn.disabled = false; confirmPayBtn.querySelector('span').textContent = 'CONFIRM TRANSFER';
    setError(''); show(app); hide(radialView); hide(tradeView); show(payView); setTimeout(() => amountInput.focus(), 80);
}
function closeUi() {
    app.classList.remove('selecting'); hide(app); hide(selectorView); hide(radialView); hide(payView); hide(tradeView);
    setError(''); setTradeError(''); selectedPlayer = null; availableActions = []; payLocked = false; tradeState = null; selectedTradeVehicles = new Set(); tradeConfirmed = false; nui('close');
}
function closeUiLocal() {
    app.classList.remove('selecting'); hide(app); hide(selectorView); hide(radialView); hide(payView); hide(tradeView);
    setError(''); setTradeError(''); tradeState = null; selectedTradeVehicles = new Set(); tradeConfirmed = false;
}
function runAction(id) { if (id === 'pay') nui('openPay'); if (id === 'trade') nui('openTrade'); }
function backToMenu() { nui('backToMenu'); }
function quickAmount(value) { amountInput.value = String(value); setError(''); }
function confirmPay() {
    if (payLocked) return; const amount = Number(amountInput.value || 0);
    if (!Number.isFinite(amount) || amount <= 0) { setError('Pune o suma valida.'); return; }
    payLocked = true; confirmPayBtn.disabled = true; confirmPayBtn.querySelector('span').textContent = 'SE TRIMITE...'; nui('pay', { amount });
}
function vehicleLabel(v) { return { name: v?.name || v?.vehicle_name || v?.model || 'Vehicul', plate: v?.plate || v?.vehicle_plate || 'NO PLATE' }; }
function normalizeVehicleIds(value) {
    if (Array.isArray(value)) return value.map(v => String(v)).filter(v => v && v !== '0');
    if (value === undefined || value === null || value === 0 || value === '0') return [];
    return [String(value)];
}
function renderVehicleList(container, vehicles) {
    const list = Array.isArray(vehicles) ? vehicles : [];
    if (!list.length) { container.innerHTML = '<div class="trade-empty">Nu ai masini personale.</div>'; return; }
    container.innerHTML = list.map(v => {
        const id = String(v.id ?? ''); const lbl = vehicleLabel(v); const cls = selectedTradeVehicles.has(id) ? 'selected' : '';
        return `<button class="trade-vehicle ${cls}" onclick="selectTradeVehicle('${escapeHtml(id)}')"><div><b>${escapeHtml(lbl.name)}</b><small>${escapeHtml(lbl.plate)}</small></div></button>`;
    }).join('');
}
function renderOtherOffer(offer) {
    const vehicles = Array.isArray(offer?.vehicles) ? offer.vehicles : (offer?.vehicle ? [offer.vehicle] : []);
    const cash = Number(offer?.money || 0);
    const parts = [];
    if (vehicles.length) {
        parts.push(`<div class="trade-offer-line"><span>MASINI SELECTATE</span>${vehicles.map(v => `<div class="offer-vehicle"><b>${escapeHtml(vehicleLabel(v).name)}</b><small>${escapeHtml(vehicleLabel(v).plate)}</small></div>`).join('')}</div>`);
    }
    if (cash > 0) {
        parts.push(`<div class="trade-offer-line"><span>BANI</span><b>${money(cash)}</b></div>`);
    }
    targetTradeVehicles.innerHTML = parts.join('');
}
function currentTradeOffer() {
    const moneyValue = Number(tradeMoneyInput.value || 0);
    return {
        sessionId: tradeState?.sessionId,
        vehicleIds: Array.from(selectedTradeVehicles).map(v => Number(v)).filter(v => Number.isFinite(v) && v > 0),
        money: Number.isFinite(moneyValue) && moneyValue > 0 ? Math.floor(moneyValue) : 0
    };
}
function updateConfirmStatus(state = {}) {
    const my = state.myConfirmed === true; const other = state.otherConfirmed === true;
    myConfirmStatus.textContent = my ? 'Tu: confirmat' : 'Tu: neconfirmat';
    theirConfirmStatus.textContent = other ? 'Celalalt: confirmat' : 'Celalalt: neconfirmat';
    myConfirmStatus.classList.toggle('done', my); theirConfirmStatus.classList.toggle('done', other);
    tradeSubmitBtn.disabled = my;
    tradeSubmitBtn.querySelector('span').textContent = my ? 'CONFIRMAT' : 'CONFIRM TRADE';
}
function openTradeSession(payload = {}) {
    tradeState = payload;
    selectedTradeVehicles = new Set(normalizeVehicleIds(payload.myOffer?.vehicleIds || payload.myOffer?.vehicleId));
    tradeConfirmed = payload.myConfirmed === true;
    setMainColor(payload.mainColor);
    const target = payload.target || {};
    tradeTargetName.textContent = target.name || 'Player';
    tradeModeText.textContent = 'DRIFTZONE TRADE';
    tradeTitle.textContent = 'Vehicle Trade';
    tradeSubtitle.textContent = `Trade activ cu ${target.name || 'Player'}. Selecteaza masini si bani, apoi CONFIRM TRADE.`;
    const currentMoney = Number(payload.myOffer?.money || 0);
    tradeMoneyInput.value = currentMoney > 0 ? String(currentMoney) : '';
    setTradeError(''); hide(selectorView); hide(radialView); hide(payView); show(app); show(tradeView);
    renderVehicleList(myTradeVehicles, payload.myVehicles || []);
    renderOtherOffer(payload.otherOffer || {});
    updateConfirmStatus(payload);
}
function sendOfferUpdate() {
    if (!tradeState?.sessionId) return;
    const offer = currentTradeOffer();
    if (!Number.isFinite(offer.money) || offer.money < 0) { setTradeError('Suma invalida.'); return; }
    setTradeError('');
    nui('updateTradeOffer', offer);
}
function selectTradeVehicle(id) {
    if (selectedTradeVehicles.has(id)) selectedTradeVehicles.delete(id);
    else selectedTradeVehicles.add(id);
    renderVehicleList(myTradeVehicles, tradeState?.myVehicles || []);
    sendOfferUpdate();
}
function submitTrade() {
    if (!tradeState?.sessionId) return;
    const offer = currentTradeOffer();
    if (!Number.isFinite(offer.money) || offer.money < 0) { setTradeError('Suma invalida.'); return; }
    tradeSubmitBtn.disabled = true;
    tradeSubmitBtn.querySelector('span').textContent = 'SE CONFIRMA...';
    nui('confirmTrade', offer);
}
function cancelTradeUi() { nui('cancelTrade', { requestId: tradeState?.sessionId }); closeUi(); }

tradeMoneyInput.addEventListener('input', () => {
    if (!tradeState?.sessionId) return;
    if (tradeMoneyTimer) clearTimeout(tradeMoneyTimer);
    tradeMoneyTimer = setTimeout(sendOfferUpdate, 350);
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openSelector') openSelector(data);
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'openPay') openPayView(data);
    if (data.action === 'closeAll') closeUiLocal();
    if (data.action === 'tradeOpen') openTradeSession(data.payload || {});
    if (data.action === 'tradeUpdate') openTradeSession(data.payload || {});
    if (data.action === 'tradeStatus') {
        const p = data.payload || {};
        if (p.ok) {
            setTradeError(p.message || 'OK');
            if (p.close === true) setTimeout(closeUiLocal, 500);
        } else setTradeError(p.message || 'Trade esuat.');
        if (tradeState?.sessionId && !p.close && (p.myConfirmed !== undefined || p.otherConfirmed !== undefined)) updateConfirmStatus(p);
    }
    if (data.action === 'tradeClose') { setTradeError(data.message || 'Trade finalizat.'); setTimeout(closeUiLocal, 700); }
    if (data.action === 'payResult') {
        payLocked = false; confirmPayBtn.disabled = false; confirmPayBtn.querySelector('span').textContent = 'CONFIRM TRANSFER';
        if (data.ok) { setError(''); confirmPayBtn.querySelector('span').textContent = 'TRIMIS CU SUCCES'; } else setError(data.message || 'Plata a esuat.');
    }
});
window.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeUi(); if (e.key === 'Enter' && !payView.classList.contains('hidden')) confirmPay(); });
window.addEventListener('mousemove', (e) => {
    if (selectorView.classList.contains('hidden')) return; const now = Date.now(); if (now - selectorMoveTimer < 16) return; selectorMoveTimer = now;
    nui('mouseMove', { x: e.clientX / Math.max(1, window.innerWidth), y: e.clientY / Math.max(1, window.innerHeight) });
});
window.addEventListener('mousedown', (e) => { if (selectorView.classList.contains('hidden')) return; if (e.button !== 0) return; nui('selectClick'); });
document.addEventListener('DOMContentLoaded', () => nui('ready'));
