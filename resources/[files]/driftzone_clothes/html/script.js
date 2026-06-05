'use strict';

const root = document.getElementById('root');
const itemsEl = document.getElementById('items');
const characterZone = document.getElementById('characterZone');

let categories = [];
let state = {};
let blacklist = {};
let dragging = false;
let lastMouseX = 0;
let lastMouseY = 0;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function safeNumber(value, fallback = 0) {
    const number = Number(value);
    return Number.isFinite(number) ? number : fallback;
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function openMenu() {
    root.classList.remove('hidden');
}

function closeMenu() {
    root.classList.add('hidden');
    dragging = false;
}

function getIconPath(icon) {
    return `icons/${String(icon || '')}`;
}

function getBlockedCount(key) {
    const list = Array.isArray(blacklist[key]) ? blacklist[key] : [];
    return list.length;
}

function isBlocked(key, drawable) {
    const list = Array.isArray(blacklist[key]) ? blacklist[key] : [];
    return list.includes(Number(drawable));
}

function handleDrawableKey(event, key, input) {
    if (event.key === 'Enter') {
        event.preventDefault();
        commitDrawableInput(key, input);
        input.blur();
        return;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        input.blur();
        render();
    }
}

function commitDrawableInput(key, input) {
    const value = Number(input.value);

    if (!Number.isInteger(value)) {
        render();
        return;
    }

    nui('setDrawable', { key, value });
}

function render() {
    if (!Array.isArray(categories) || categories.length === 0) {
        itemsEl.innerHTML = '<div class="empty">Nu exista categorii.</div>';
        return;
    }

    itemsEl.innerHTML = categories.map((cat) => {
        const item = state[cat.key] || {};
        const drawable = safeNumber(item.drawable, 0);
        const texture = safeNumber(item.texture, 0);
        const maxDrawable = Math.max(0, safeNumber(item.maxDrawable, 1) - 1);
        const maxTexture = Math.max(0, safeNumber(item.maxTexture, 1) - 1);
        const drawableText = cat.type === 'prop' && drawable < 0 ? '-1' : String(drawable);
        const blockedCount = getBlockedCount(cat.key);
        const blockedCurrent = isBlocked(cat.key, drawable);

        return `
            <div class="cloth-item ${blockedCurrent ? 'blocked-current' : ''}">
                <div class="icon-box">
                    <img src="${getIconPath(cat.icon)}" onerror="this.style.display='none'" draggable="false">
                </div>

                <div class="cloth-main">
                    <div class="cloth-name">${escapeHtml(cat.label)}</div>
                    <div class="cloth-meta">${cat.type === 'prop' ? 'Accesoriu' : 'Component'} • ${drawableText}/${maxDrawable}</div>
                    ${blockedCount > 0 ? `<div class="blacklist-badge">${blockedCount} numere blocate</div>` : ''}
                </div>

                <div class="controls">
                    <div class="control-row">
                        <button class="arrow" onclick="changeDrawable('${cat.key}', -1)">‹</button>
                        <input
                            class="drawable-input"
                            value="${drawableText}"
                            onclick="this.select()"
                            onfocus="this.select()"
                            onkeydown="handleDrawableKey(event, '${cat.key}', this)"
                            onblur="commitDrawableInput('${cat.key}', this)">
                        <button class="arrow" onclick="changeDrawable('${cat.key}', 1)">›</button>
                    </div>

                    <div class="control-row">
                        <button class="arrow" onclick="changeTexture('${cat.key}', -1)">‹</button>
                        <div class="value-box"><span>TEX</span>${texture}/${maxTexture}</div>
                        <button class="arrow" onclick="changeTexture('${cat.key}', 1)">›</button>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

function setState(payload) {
    const data = payload || {};

    categories = Array.isArray(data.categories) ? data.categories : [];
    state = data.state || {};
    blacklist = data.blacklist || {};

    if (data.mainColor) {
        document.documentElement.style.setProperty('--main', data.mainColor);
    }

    render();
}

function changeDrawable(key, direction) {
    nui('changeDrawable', { key, direction: Number(direction) });
}

function changeTexture(key, direction) {
    nui('changeTexture', { key, direction: Number(direction) });
}

function saveClothes() {
    nui('save');
}

function abandonClothes() {
    nui('abandon');
}

characterZone.addEventListener('mousedown', (event) => {
    if (event.button !== 0) return;

    dragging = true;
    lastMouseX = event.clientX;
    lastMouseY = event.clientY;
});

window.addEventListener('mouseup', () => {
    dragging = false;
});

window.addEventListener('mousemove', (event) => {
    if (!dragging) return;

    const dx = event.clientX - lastMouseX;
    const dy = event.clientY - lastMouseY;

    lastMouseX = event.clientX;
    lastMouseY = event.clientY;

    nui('rotate', { deltaX: dx, deltaY: dy });
});

characterZone.addEventListener('wheel', (event) => {
    event.preventDefault();
    event.stopPropagation();
    nui('zoom', { delta: event.deltaY });
}, { passive: false });

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        return false;
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') openMenu();
    if (data.action === 'close') closeMenu();
    if (data.action === 'setState') setState(data.payload || {});
});

window.driftClothes = { open: openMenu, close: closeMenu, setState };

setTimeout(() => nui('ready'), 100);
