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
const barbutView = document.getElementById('barbutView');
const barbutInvitePanel = document.getElementById('barbutInvitePanel');
const barbutGamePanel = document.getElementById('barbutGamePanel');
const barbutInviteTarget = document.getElementById('barbutInviteTarget');
const barbutAmountInput = document.getElementById('barbutAmountInput');
const barbutInviteError = document.getElementById('barbutInviteError');
const barbutInviteBtn = document.getElementById('barbutInviteBtn');
const barbutGameTitle = document.getElementById('barbutGameTitle');
const barbutGameSubtitle = document.getElementById('barbutGameSubtitle');
const barbutBetText = document.getElementById('barbutBetText');
const barbutMyName = document.getElementById('barbutMyName');
const barbutOtherName = document.getElementById('barbutOtherName');
const barbutMyReady = document.getElementById('barbutMyReady');
const barbutOtherReady = document.getElementById('barbutOtherReady');
const barbutMyDice = document.getElementById('barbutMyDice');
const barbutOtherDice = document.getElementById('barbutOtherDice');
const barbutMyTotal = document.getElementById('barbutMyTotal');
const barbutOtherTotal = document.getElementById('barbutOtherTotal');
const barbutResultText = document.getElementById('barbutResultText');
const barbutTaxText = document.getElementById('barbutTaxText');
const barbutError = document.getElementById('barbutError');
const barbutCloseBtn = document.getElementById('barbutCloseBtn');
const barbutRetryBtn = document.getElementById('barbutRetryBtn');
const barbutReadyBtn = document.getElementById('barbutReadyBtn');
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
let barbutState = null;
let barbutRolling = false;
let barbutInviteLocked = false;

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
        { id: 'trade', label: 'TRADE', title: 'Schimba masini', description: 'Trade masini si bani' },
        { id: 'pay', label: 'PAY', title: 'Trimite bani', description: 'Transfer cash catre player' },
        { id: 'barbut', label: 'BARBUT', title: 'Joaca barbut', description: 'Zaruri pe cash' }
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
    hide(radialView); hide(payView); hide(tradeView); hide(barbutView); setError(''); setTradeError(''); setBarbutError('');
}
function buildActionButton(action, index) {
    const special = action.id === 'trade' ? 'trade-card-action' : (action.id === 'pay' ? 'pay-card-action' : (action.id === 'barbut' ? 'barbut-card-action' : 'pay-card-action'));
    const numberText = action.id === 'trade' ? '01' : action.id === 'pay' ? '02' : action.id === 'barbut' ? '03' : String(index + 1).padStart(2, '0');
    return `<button class="${special}" style="--delay:${index * 70}ms" onclick="runAction('${escapeHtml(action.id)}')">
        <i>${numberText}</i>
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
    renderActions(data.actions); show(app); show(radialView); hide(payView); hide(tradeView); hide(barbutView); setError(''); setTradeError(''); setBarbutError('');
}
function openPayView(data = {}) {
    selectedPlayer = data.player || selectedPlayer || {}; payTargetName.textContent = selectedPlayer.name || 'Player'; payTargetId.textContent = selectedPlayer.uid || selectedPlayer.serverId || 0;
    amountInput.value = ''; payLocked = false; confirmPayBtn.disabled = false; confirmPayBtn.querySelector('span').textContent = 'CONFIRM TRANSFER';
    setError(''); show(app); hide(radialView); hide(tradeView); show(payView); setTimeout(() => amountInput.focus(), 80);
}
function closeUi() {
    app.classList.remove('selecting'); hide(app); hide(selectorView); hide(radialView); hide(payView); hide(tradeView); hide(barbutView);
    setError(''); setTradeError(''); selectedPlayer = null; availableActions = []; payLocked = false; tradeState = null; selectedTradeVehicles = new Set(); tradeConfirmed = false; barbutState = null; barbutRolling = false; barbutInviteLocked = false; nui('close');
}
function closeUiLocal() {
    app.classList.remove('selecting'); hide(app); hide(selectorView); hide(radialView); hide(payView); hide(tradeView); hide(barbutView);
    setError(''); setTradeError(''); tradeState = null; selectedTradeVehicles = new Set(); tradeConfirmed = false; barbutState = null; barbutRolling = false; barbutInviteLocked = false;
}
function runAction(id) { if (id === 'pay') nui('openPay'); if (id === 'trade') nui('openTrade'); if (id === 'barbut') nui('openBarbut'); }
function backToMenu() { nui('backToMenu'); }
function quickAmount(value) { amountInput.value = String(value); setError(''); }
function confirmPay() {
    if (payLocked) return; const amount = Number(amountInput.value || 0);
    if (!Number.isFinite(amount) || amount <= 0) { setError('Pune o suma valida.'); return; }
    payLocked = true; confirmPayBtn.disabled = true; confirmPayBtn.querySelector('span').textContent = 'SE TRIMITE...'; nui('pay', { amount });
}
function vehicleLabel(v) {
    const name = v?.name || v?.vehicle_name || v?.model || 'Vehicul';
    const plate = v?.plate || v?.vehicle_plate || 'NO PLATE';
    return { name, plate, display: `${name} (${plate})` };
}
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
        return `<button class="trade-vehicle ${cls}" onclick="selectTradeVehicle('${escapeHtml(id)}')"><div><b>${escapeHtml(lbl.display)}</b></div></button>`;
    }).join('');
}
function renderOtherOffer(offer) {
    const vehicles = Array.isArray(offer?.vehicles) ? offer.vehicles : (offer?.vehicle ? [offer.vehicle] : []);
    const cash = Number(offer?.money || 0);
    const parts = [];
    if (vehicles.length) {
        parts.push(`<div class="trade-offer-line"><span>MASINI SELECTATE</span>${vehicles.map(v => `<div class="offer-vehicle"><b>${escapeHtml(vehicleLabel(v).display)}</b></div>`).join('')}</div>`);
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
function offerHasSomething(offer) {
    const vehicles = Array.isArray(offer?.vehicles) ? offer.vehicles : (Array.isArray(offer?.vehicleIds) ? offer.vehicleIds : []);
    const cash = Number(offer?.money || 0);
    return vehicles.length > 0 || cash > 0;
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
    const myHasOffer = offer.vehicleIds.length > 0 || offer.money > 0;
    const otherHasOffer = offerHasSomething(tradeState.otherOffer || {});
    if (!myHasOffer && !otherHasOffer) {
        setTradeError('Nu poti confirma un trade gol. Selecteaza o masina sau pune bani.');
        return;
    }
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


function setBarbutError(message) {
    const targets = [barbutInviteError, barbutError];
    targets.forEach((el) => {
        if (!el) return;
        if (!message) { el.textContent = ''; el.classList.add('hidden'); return; }
        el.textContent = String(message);
        el.classList.remove('hidden');
    });
}
function diceHtml(value, rolling = false) {
    const v = Math.max(1, Math.min(6, Number(value || 1)));
    const dots = Array.from({ length: v }, (_, i) => `<i class="dot d${v}-${i + 1} ${v === 1 ? 'red' : ''}"></i>`).join('');
    return `<div class="dice ${rolling ? 'rolling' : ''}" data-value="${v}"><div class="dice-face">${dots}</div></div>`;
}
function renderDice(container, values, rolling = false) {
    const list = Array.isArray(values) && values.length ? values : [1, 1];
    container.innerHTML = list.map(v => diceHtml(v, rolling)).join('');
}
function barbutPayload(payload = {}) {
    barbutState = payload || {};
    const finished = barbutState.phase === 'finished';
    const rolling = barbutState.phase === 'rolling' || barbutRolling;

    barbutBetText.textContent = money(barbutState.amount || 0);
    barbutTaxText.textContent = `Taxa castigator: ${Number(barbutState.taxPercent || 10)}%`;
    barbutMyName.textContent = barbutState.me?.name || 'Tu';
    barbutOtherName.textContent = barbutState.other?.name || 'Oponent';
    barbutMyReady.textContent = barbutState.myReady ? 'READY' : 'NOT READY';
    barbutOtherReady.textContent = barbutState.otherReady ? 'READY' : 'NOT READY';
    barbutMyReady.classList.toggle('done', barbutState.myReady === true);
    barbutOtherReady.classList.toggle('done', barbutState.otherReady === true);

    const myDice = barbutState.myDice || [1, 1];
    const otherDice = barbutState.otherDice || [1, 1];
    renderDice(barbutMyDice, myDice, false);
    renderDice(barbutOtherDice, otherDice, false);

    barbutMyTotal.textContent = finished ? (barbutState.myScoreLabel || Number(barbutState.myTotal || (myDice[0] + myDice[1]) || 0)) : '—';
    barbutOtherTotal.textContent = finished ? (barbutState.otherScoreLabel || Number(barbutState.otherTotal || (otherDice[0] + otherDice[1]) || 0)) : '—';

    // Nu mai exista buton separat de retry. Dupa fiecare runda apare direct READY.
    barbutRetryBtn.classList.add('hidden');
    barbutRetryBtn.disabled = true;
    barbutReadyBtn.classList.toggle('hidden', rolling);
    barbutReadyBtn.disabled = barbutState.myReady === true || rolling;
    barbutCloseBtn.disabled = rolling || barbutState.closeLocked === true;
    barbutCloseBtn.classList.toggle('disabled', barbutCloseBtn.disabled);
    barbutReadyBtn.querySelector('span').textContent = barbutState.myReady ? 'WAITING' : 'READY';

    if (!finished && !rolling) {
        barbutResultText.textContent = barbutState.myReady || barbutState.otherReady ? 'WAITING' : 'READY';
        barbutGameSubtitle.textContent = 'Runda este pregatita.';
    }
    if (rolling) {
        barbutResultText.textContent = 'ROLLING';
        barbutGameSubtitle.textContent = 'Zarurile se invart. Rezultatul apare la final.';
    }
    if (finished && barbutState.resultText) {
        barbutResultText.textContent = barbutState.resultText;
        barbutGameSubtitle.textContent = 'Apasa READY pentru o runda noua.';
    }
}
function openBarbutInvite(payload = {}) {
    selectedPlayer = payload.target || selectedPlayer || {};
    barbutInviteLocked = false;
    barbutInviteTarget.textContent = selectedPlayer.name || 'Player';
    barbutAmountInput.value = '';
    barbutInviteBtn.disabled = false;
    barbutInviteBtn.querySelector('span').textContent = 'INVITE';
    setBarbutError('');
    show(app); hide(radialView); hide(payView); hide(tradeView); show(barbutView); show(barbutInvitePanel); hide(barbutGamePanel);
    setTimeout(() => barbutAmountInput.focus(), 80);
}
function sendBarbutInvite() {
    if (barbutInviteLocked) return;
    const amount = Math.floor(Number(barbutAmountInput.value || 0));
    if (!Number.isFinite(amount) || amount <= 0) { setBarbutError('Pune o suma valida.'); return; }
    barbutInviteLocked = true;
    barbutInviteBtn.disabled = true;
    barbutInviteBtn.querySelector('span').textContent = 'SE TRIMITE...';
    nui('barbutInvite', { amount });
    setTimeout(() => {
        if (!barbutInvitePanel.classList.contains('hidden')) {
            barbutInviteLocked = false;
            barbutInviteBtn.disabled = false;
            barbutInviteBtn.querySelector('span').textContent = 'INVITE';
        }
    }, 2200);
}
function openBarbutGame(payload = {}) {
    setBarbutError('');
    show(app); hide(radialView); hide(payView); hide(tradeView); show(barbutView); hide(barbutInvitePanel); show(barbutGamePanel);
    barbutGameTitle.textContent = 'Barbut Duel';
    barbutPayload(payload);
}
function readyBarbutGame() {
    if (!barbutState || barbutRolling) return;
    barbutReadyBtn.disabled = true;
    nui('barbutReady', { sessionId: barbutState.sessionId });
}
function retryBarbutGame() {
    // Compatibilitate veche: retry foloseste acelasi flux ca READY.
    readyBarbutGame();
}
function closeBarbutGame() {
    if (barbutRolling || barbutCloseBtn.disabled) {
        setBarbutError('Nu poti inchide cat timp runda este in desfasurare.');
        return;
    }
    nui('barbutClose', { sessionId: barbutState?.sessionId });
}
function rollBarbut(payload = {}) {
    barbutRolling = true;
    openBarbutGame({ ...payload, phase: 'rolling', resultText: '', myDice: [1, 1], otherDice: [1, 1], myTotal: 0, otherTotal: 0, myScoreLabel: '', otherScoreLabel: '' });
    barbutResultText.textContent = 'ROLLING';
    barbutGameSubtitle.textContent = 'Zarurile se invart. Rezultatul apare la final.';
    barbutMyTotal.textContent = '—';
    barbutOtherTotal.textContent = '—';
    barbutReadyBtn.disabled = true;
    barbutReadyBtn.classList.add('hidden');
    barbutRetryBtn.classList.add('hidden');
    barbutCloseBtn.disabled = true;
    barbutCloseBtn.classList.add('disabled');

    let ticks = 0;
    const maxTicks = 52;
    const timer = setInterval(() => {
        ticks++;
        const my = [1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)];
        const other = [1 + Math.floor(Math.random() * 6), 1 + Math.floor(Math.random() * 6)];
        renderDice(barbutMyDice, my, true);
        renderDice(barbutOtherDice, other, true);
        if (ticks >= maxTicks) {
            clearInterval(timer);
            setTimeout(() => {
                renderDice(barbutMyDice, payload.myDice || [1, 1], false);
                renderDice(barbutOtherDice, payload.otherDice || [1, 1], false);
                barbutMyDice.classList.add('dice-reveal');
                barbutOtherDice.classList.add('dice-reveal');
                setTimeout(() => {
                    barbutRolling = false;
                    barbutPayload(payload);
                    barbutCloseBtn.disabled = false;
                    barbutCloseBtn.classList.remove('disabled');
                    setTimeout(() => {
                        barbutMyDice.classList.remove('dice-reveal');
                        barbutOtherDice.classList.remove('dice-reveal');
                    }, 420);
                }, 420);
            }, 180);
        }
    }, 72);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openSelector') openSelector(data);
    if (data.action === 'openMenu') openMenu(data);
    if (data.action === 'openPay') openPayView(data);
    if (data.action === 'closeAll') closeUiLocal();
    if (data.action === 'barbutInviteMenu') { setMainColor(data.mainColor); openBarbutInvite(data.payload || {}); }
    if (data.action === 'barbutOpen') { setMainColor(data.mainColor); openBarbutGame(data.payload || {}); }
    if (data.action === 'barbutUpdate') { setMainColor(data.mainColor); openBarbutGame(data.payload || {}); }
    if (data.action === 'barbutRoll') { setMainColor(data.mainColor); rollBarbut(data.payload || {}); }
    if (data.action === 'barbutClose') { setBarbutError(data.message || 'Partida a fost inchisa.'); setTimeout(closeUiLocal, 700); }
    if (data.action === 'tradeOpen') openTradeSession(data.payload || {});
    if (data.action === 'tradeUpdate') openTradeSession(data.payload || {});
    if (data.action === 'tradeStatus') {
        const p = data.payload || {};
        if (p.ok) {
            setTradeError(p.message || 'OK');
            if (p.close === true) setTimeout(closeUiLocal, 500);
        } else {
            setTradeError(p.message || 'Trade esuat.');
            if (tradeState?.sessionId && !tradeConfirmed) {
                tradeSubmitBtn.disabled = false;
                tradeSubmitBtn.querySelector('span').textContent = 'CONFIRM TRADE';
            }
        }
        if (tradeState?.sessionId && !p.close && (p.myConfirmed !== undefined || p.otherConfirmed !== undefined)) updateConfirmStatus(p);
    }
    if (data.action === 'tradeClose') { setTradeError(data.message || 'Trade finalizat.'); setTimeout(closeUiLocal, 700); }
    if (data.action === 'payResult') {
        payLocked = false; confirmPayBtn.disabled = false; confirmPayBtn.querySelector('span').textContent = 'CONFIRM TRANSFER';
        if (data.ok) { setError(''); confirmPayBtn.querySelector('span').textContent = 'TRIMIS CU SUCCES'; } else setError(data.message || 'Plata a esuat.');
    }
});
window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === '`' || e.code === 'Backquote') {
        e.preventDefault();
        if (!barbutView.classList.contains('hidden') && barbutState && barbutState.sessionId) {
            if (!barbutRolling && !barbutCloseBtn.disabled) closeBarbutGame();
        } else {
            closeUi();
        }
        return;
    }
    if (e.key === 'Enter' && !payView.classList.contains('hidden')) confirmPay();
});
window.addEventListener('mousemove', (e) => {
    if (selectorView.classList.contains('hidden')) return; const now = Date.now(); if (now - selectorMoveTimer < 16) return; selectorMoveTimer = now;
    nui('mouseMove', { x: e.clientX / Math.max(1, window.innerWidth), y: e.clientY / Math.max(1, window.innerHeight) });
});
window.addEventListener('mousedown', (e) => { if (selectorView.classList.contains('hidden')) return; if (e.button !== 0) return; nui('selectClick'); });
document.addEventListener('DOMContentLoaded', () => nui('ready'));
