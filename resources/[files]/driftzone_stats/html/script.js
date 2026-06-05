'use strict';

const root = document.getElementById('root');
const playerName = document.getElementById('playerName');
const playerId = document.getElementById('playerId');
const rankPill = document.getElementById('rankPill');
const xpText = document.getElementById('xpText');
const levelText = document.getElementById('levelText');
const xpFill = document.getElementById('xpFill');
const playtimeText = document.getElementById('playtimeText');
const cashText = document.getElementById('cashText');
const vehiclesText = document.getElementById('vehiclesText');
const createdText = document.getElementById('createdText');
const dzcoinsText = document.getElementById('dzcoinsText');
const staffCard = document.getElementById('staffCard');
const staffText = document.getElementById('staffText');
const staffDuty = document.getElementById('staffDuty');

let currentStats = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function safeText(value, fallback = '') {
    if (value === null || value === undefined) return fallback;
    return String(value);
}

function formatMoney(value) {
    const number = Number(value || 0);
    return '$' + number.toLocaleString('en-US');
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function setRankColor(color) {
    const safe = /^#[0-9a-fA-F]{6}$/.test(String(color || '')) ? color : '#04c7f7';

    document.documentElement.style.setProperty('--rank', safe);
    rankPill.style.borderColor = safe;
    rankPill.style.color = safe;
}

function render(stats) {
    currentStats = stats || {};

    playerName.textContent = safeText(currentStats.username, 'Player');
    playerId.textContent = `ID: ${Number(currentStats.uid || 0)}`;

    rankPill.textContent = safeText(currentStats.rank, 'Newbie');
    setRankColor(currentStats.rankColor || '#04c7f7');

    const xp = Number(currentStats.xp || 0);
    const goal = Number(currentStats.xpNextGoal || 1000);
    const progress = clamp(Number(currentStats.xpProgress || 0), 0, 100);

    xpText.textContent = `${xp.toLocaleString('en-US')}/${goal.toLocaleString('en-US')} XP`;
    levelText.textContent = String(Number(currentStats.level || 1));
    xpFill.style.width = `${progress}%`;

    playtimeText.textContent = safeText(currentStats.playtimeText, '0m');
    cashText.textContent = formatMoney(currentStats.cash);
    vehiclesText.textContent = String(Number(currentStats.vehicles || 0));
    createdText.textContent = safeText(currentStats.createdDate, '-');
    dzcoinsText.textContent = String(Number(currentStats.dzcoins || 0).toLocaleString('en-US'));

    if (currentStats.staff && currentStats.staff.label) {
        staffCard.classList.remove('hidden');
        staffText.textContent = currentStats.staff.label;
        staffDuty.textContent = currentStats.staff.aduty ? 'ON DUTY' : 'OFF DUTY';
    } else {
        staffCard.classList.add('hidden');
    }
}

function open(stats) {
    root.classList.remove('hidden');
    render(stats || {});
}

function closeMenu() {
    root.classList.add('hidden');
    nui('close');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        open(data.stats || {});
    }

    if (data.action === 'update') {
        render(data.stats || {});
    }

    if (data.action === 'close') {
        root.classList.add('hidden');
    }

    if (data.action === 'ping') {
        nui('ready');
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        event.preventDefault();
        closeMenu();
    }
});

setTimeout(() => {
    nui('ready');
}, 100);
