'use strict';

const root = document.getElementById('root');
const nodes = new Map();
let lastIds = new Set();

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function isHexColor(value) {
    return /^#[0-9a-fA-F]{6}$/.test(String(value || ''));
}

function createNode(id) {
    const el = document.createElement('div');
    el.className = 'plate';
    el.dataset.id = String(id);

    el.innerHTML = `
        <div class="staff hidden"></div>
        <div class="name"></div>
        <div class="rank"></div>
        <div class="accent"></div>
    `;

    root.appendChild(el);
    nodes.set(id, el);

    return el;
}

function update(players) {
    const active = new Set();

    for (const player of players || []) {
        const id = Number(player.id || 0);
        if (!id) continue;

        active.add(id);

        const el = nodes.get(id) || createNode(id);
        const staffEl = el.querySelector('.staff');
        const nameEl = el.querySelector('.name');
        const rankEl = el.querySelector('.rank');

        const x = Math.round(Number(player.x || 0) * window.innerWidth);
        const y = Math.round(Number(player.y || 0) * window.innerHeight);
        const scale = Number(player.scale || 1).toFixed(3);
        const opacity = Number(player.opacity || 1).toFixed(3);

        el.style.transform = `translate(${x}px, ${y}px) translate(-50%, -100%) scale(${scale})`;
        el.style.opacity = opacity;
        el.classList.toggle('far', Number(player.distance || 0) > 12);
        el.classList.toggle('talking', player.isTalking === true);

        const staff = String(player.staff || '').trim();
        if (staff) {
            staffEl.classList.remove('hidden');
            staffEl.textContent = staff;
        } else {
            staffEl.classList.add('hidden');
            staffEl.textContent = '';
        }

        nameEl.innerHTML = `${escapeHtml(player.name || 'Player')} <span class="uid">(${escapeHtml(player.uid || id)})</span>`;

        const rankColor = isHexColor(player.rankColor) ? player.rankColor : '#04c7f7';
        el.style.setProperty('--rank-color', rankColor);
        rankEl.textContent = String(player.rank || 'STARTER').toUpperCase();
    }

    for (const [id, el] of nodes.entries()) {
        if (!active.has(id)) {
            el.remove();
            nodes.delete(id);
        }
    }

    lastIds = active;
}

function clearAll() {
    for (const [, el] of nodes.entries()) {
        el.remove();
    }

    nodes.clear();
    lastIds = new Set();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'update') {
        update(data.players || []);
    }

    if (data.action === 'clear') {
        clearAll();
    }
});

setTimeout(() => nui('ready'), 100);
