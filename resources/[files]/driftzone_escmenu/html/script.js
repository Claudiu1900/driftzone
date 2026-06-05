'use strict';

const root = document.getElementById('root');
const helloText = document.getElementById('helloText');
const dzCoins = document.getElementById('dzCoins');
const cardsEl = document.getElementById('cards');
const toast = document.getElementById('toast');

let payload = {};
let toastTimer = null;

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

function getImage(key) {
    const images = payload.images || {};
    return images[key] || '';
}

function formatNumber(value) {
    const n = Number(value || 0);
    return n.toLocaleString('en-US');
}

function showToast(text) {
    toast.textContent = String(text || 'DONE');
    toast.classList.remove('hidden');

    if (toastTimer) clearTimeout(toastTimer);

    toastTimer = setTimeout(() => {
        toast.classList.add('hidden');
    }, 1150);
}

async function copyText(text) {
    const value = String(text || '');
    let copied = false;

    try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(value);
            copied = true;
        }
    } catch (e) {}

    if (!copied) {
        try {
            const input = document.createElement('textarea');
            input.value = value;
            input.style.position = 'fixed';
            input.style.opacity = '0';
            input.style.pointerEvents = 'none';
            document.body.appendChild(input);
            input.focus();
            input.select();
            copied = document.execCommand('copy');
            document.body.removeChild(input);
        } catch (e) {
            copied = false;
        }
    }

    showToast(copied ? 'DISCORD COPIED' : 'COPY FAILED');

    if (copied) {
        nui('copied');
    }
}

function closeMenu() {
    root.classList.add('hidden');
    nui('close');
}

function runAction(action) {
    if (!action || typeof action !== 'object') return;

    if (action.type === 'copy_discord') {
        copyText(payload.discordInvite || '');
        return;
    }

    if (action.type === 'soon') {
        showToast('COMING SOON');
        return;
    }

    nui('runAction', { action });
}

function renderCards() {
    const cards = Array.isArray(payload.cards) ? payload.cards : [];

    cardsEl.innerHTML = cards.map((card) => {
        const image = getImage(card.image || '');

        return `
            <article class="card" onclick='runAction(${JSON.stringify(card.action || {})})'>
                <div class="card-bg" style="background-image:url('${escapeHtml(image)}')"></div>
                <div class="card-shade"></div>
                <div class="card-content">
                    <div class="card-title">${escapeHtml(card.title || 'CARD')}</div>
                    <div class="card-sub">${escapeHtml(card.subtitle || '')}</div>
                </div>
            </article>
        `;
    }).join('');
}

function openMenu(data) {
    payload = data || {};

    document.documentElement.style.setProperty('--main', payload.mainColor || '#04c7f7');

    helloText.textContent = `Hello ${payload.name || 'Player'}`;
    dzCoins.textContent = formatNumber(payload.dzcoins || 0);

    renderCards();

    root.classList.remove('hidden');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') openMenu(data.payload || {});
    if (data.action === 'close') root.classList.add('hidden');
    if (data.action === 'copyDiscord') copyText(data.value || '');
    if (data.action === 'soon') showToast('COMING SOON');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closeMenu();
    }
});

setTimeout(() => nui('ready'), 80);
