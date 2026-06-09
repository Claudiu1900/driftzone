'use strict';

const app = document.getElementById('app');
const cashText = document.getElementById('cashText');
const betInput = document.getElementById('betInput');
const statusBox = document.getElementById('statusBox');
const dealerCards = document.getElementById('dealerCards');
const playerCards = document.getElementById('playerCards');
const dealerValue = document.getElementById('dealerValue');
const playerValue = document.getElementById('playerValue');
const dealBtn = document.getElementById('dealBtn');
const hitBtn = document.getElementById('hitBtn');
const standBtn = document.getElementById('standBtn');
const doubleBtn = document.getElementById('doubleBtn');
const surrenderBtn = document.getElementById('surrenderBtn');

let minBet = 1000;
let maxBetValue = 1000000;
let cash = 0;
let lastState = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function money(value) {
    const n = Number(value || 0);
    try { return '$' + n.toLocaleString('en-US'); } catch (e) { return '$' + n; }
}

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function setStatus(text, type = 'info') {
    if (!text) {
        statusBox.textContent = '';
        statusBox.className = 'status hidden';
        return;
    }
    statusBox.textContent = String(text);
    statusBox.className = `status ${type}`;
}

function setBet(value) {
    betInput.value = String(Math.min(maxBetValue, Math.max(minBet, Number(value || 0))));
    setStatus('');
}

function maxBet() {
    setBet(Math.min(maxBetValue, cash));
}

function rankClass(card) {
    if (!card || card.hidden) return '';
    return (card.suit === '♥' || card.suit === '♦') ? 'red' : 'black';
}

function renderCard(card, index) {
    if (!card || card.hidden) {
        return `<div class="card back" style="--i:${index}"><div class="back-inner">DZ</div></div>`;
    }

    const rank = escapeHtml(card.rank || '?');
    const suit = escapeHtml(card.suit || '♠');
    return `
        <div class="card ${rankClass(card)}" style="--i:${index}">
            <div class="corner top"><b>${rank}</b><span>${suit}</span></div>
            <div class="suit">${suit}</div>
            <div class="corner bottom"><b>${rank}</b><span>${suit}</span></div>
        </div>
    `;
}

function renderCards(container, cards) {
    const list = Array.isArray(cards) ? cards : [];
    container.innerHTML = list.map((card, index) => renderCard(card, index)).join('');
}

function setButtons(state) {
    const phase = state?.phase || 'idle';
    const playerPhase = phase === 'player';
    dealBtn.disabled = phase === 'player' || phase === 'dealer';
    hitBtn.disabled = !state?.canHit;
    standBtn.disabled = !state?.canStand;
    doubleBtn.disabled = !state?.canDouble;
    surrenderBtn.disabled = !state?.canSurrender;
    betInput.disabled = phase === 'player' || phase === 'dealer';
}

function applyState(state) {
    if (!state || typeof state !== 'object') return;
    lastState = { ...(lastState || {}), ...state };

    if (typeof state.cash !== 'undefined') {
        cash = Number(state.cash || 0);
        cashText.textContent = money(cash);
    }

    renderCards(dealerCards, state.dealerCards || []);
    renderCards(playerCards, state.playerCards || []);
    dealerValue.textContent = String(state.dealerValue ?? 0);
    playerValue.textContent = String(state.playerValue ?? 0);

    if (state.message) {
        const result = String(state.result || '').toLowerCase();
        const type = result === 'win' || result === 'blackjack' ? 'success' : result === 'push' ? 'info' : 'error';
        setStatus(state.message, type);
    }

    setButtons(state);
}

function startGame() {
    const bet = Math.floor(Number(betInput.value || 0));
    if (!Number.isFinite(bet) || bet < minBet || bet > maxBetValue) {
        setStatus(`Miza trebuie sa fie intre ${money(minBet)} si ${money(maxBetValue)}.`, 'error');
        return;
    }
    if (bet > cash) {
        setStatus('Nu ai destui bani pentru miza asta.', 'error');
        return;
    }
    setStatus('Se impart cartile...', 'info');
    nui('start', { bet });
}

function hit() { nui('hit'); }
function stand() { nui('stand'); }
function doubleDown() { nui('double'); }
function surrender() { nui('surrender'); }
function closeUi() { nui('close'); }

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        app.classList.remove('hidden');
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        minBet = Number(data.minBet || 1000);
        maxBetValue = Number(data.maxBet || 1000000);
        cash = Number(data.cash || 0);
        cashText.textContent = money(cash);
        betInput.min = String(minBet);
        betInput.max = String(maxBetValue);
        if (!betInput.value) betInput.value = String(Math.min(100000, maxBetValue, Math.max(minBet, cash)));
        setStatus('Pune miza si apasa DEAL.', 'info');
        setButtons({ phase: 'idle' });
    }

    if (data.action === 'close') {
        app.classList.add('hidden');
        setStatus('');
    }

    if (data.action === 'state') {
        applyState(data.data || {});
    }

    if (data.action === 'status') {
        setStatus(data.message || '', data.typ || 'info');
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeUi();
    if (event.key.toLowerCase() === 'h' && !hitBtn.disabled) hit();
    if (event.key.toLowerCase() === 's' && !standBtn.disabled) stand();
    if (event.key.toLowerCase() === 'd' && !doubleBtn.disabled) doubleDown();
});

nui('ready');
