'use strict';

const hud = document.getElementById('hud');
const cards = new Map();

for (const card of document.querySelectorAll('[data-card]')) {
    cards.set(card.dataset.card, {
        root: card,
        value: card.querySelector('.value')
    });
}

const clamp = (value, minimum = 0, maximum = 100) => {
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return minimum;
    return Math.min(maximum, Math.max(minimum, Math.round(numeric)));
};

function updateCard(name, value) {
    const card = cards.get(name);
    if (!card) return;

    const safeValue = clamp(value);
    card.value.textContent = String(safeValue);
    card.root.style.setProperty('--value', `${safeValue}%`);
    card.root.classList.toggle('is-critical', safeValue <= 15);
}

function setCollapsed(name, collapsed) {
    const card = cards.get(name);
    if (!card) return;
    card.root.classList.toggle('is-collapsed', Boolean(collapsed));
}

function updateHud(data = {}) {
    const visible = data.visible === true;
    hud.classList.toggle('is-hidden', !visible);

    if (!visible) return;

    updateCard('health', data.health);
    updateCard('armour', data.armour);
    updateCard('food', data.food);
    updateCard('water', data.water);
    updateCard('stamina', data.stamina);

    setCollapsed('armour', data.showArmour !== true);
    setCollapsed('stamina', data.showStamina !== true);
}

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || message.action !== 'update') return;
    updateHud(message.data);
});
