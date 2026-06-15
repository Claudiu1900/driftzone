'use strict';

const MAX_VISIBLE = 5;
const MAX_QUEUE = 50;
const DEFAULT_DURATION = 5000;
const MIN_DURATION = 1200;
const MAX_DURATION = 20000;

const rootEl = document.getElementById('notifyRoot');
const notificationSound = document.getElementById('notificationSound');

let visibleCount = 0;
let queue = [];
let notificationId = 0;
let soundEnabled = true;

const typeData = {
    info: {
        title: 'INFORMARE',
        icon: 'assets/icons/info.svg'
    },
    success: {
        title: 'CONFIRMARE',
        icon: 'assets/icons/success.svg'
    },
    warning: {
        title: 'ATENTIE',
        icon: 'assets/icons/warning.svg'
    },
    error: {
        title: 'EROARE',
        icon: 'assets/icons/error.svg'
    }
};

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

function normalizeType(type) {
    const t = String(type || '').trim().toLowerCase();
    if (t === 'success' || t === 'succes' || t === 'ok') return 'success';
    if (t === 'warning' || t === 'warn' || t === 'atentie') return 'warning';
    if (t === 'error' || t === 'err' || t === 'danger') return 'error';
    return 'info';
}

function normalizeDuration(duration) {
    const value = Number(duration);
    if (!Number.isFinite(value)) return DEFAULT_DURATION;
    return Math.max(MIN_DURATION, Math.min(MAX_DURATION, Math.floor(value)));
}

function playNotificationSound(enabledForPayload) {
    if (!soundEnabled || enabledForPayload === false || !notificationSound) return;

    try {
        notificationSound.volume = 0.34;
        notificationSound.currentTime = 0;
        const promise = notificationSound.play();
        if (promise && typeof promise.catch === 'function') promise.catch(() => {});
    } catch (e) {}
}

function push(payload) {
    const item = {
        id: ++notificationId,
        type: normalizeType(payload && payload.type),
        duration: normalizeDuration(payload && payload.duration),
        message: String((payload && payload.message) || '').trim(),
        sound: payload ? payload.sound !== false : true
    };

    if (!item.message) return;

    if (visibleCount >= MAX_VISIBLE) {
        queue.push(item);
        if (queue.length > MAX_QUEUE) queue.shift();
        return;
    }

    renderNotification(item);
}

function renderNotification(item) {
    visibleCount++;
    playNotificationSound(item.sound);

    const data = typeData[item.type] || typeData.info;
    const el = document.createElement('div');
    el.className = `notification ${item.type}`;
    el.dataset.id = String(item.id);

    el.innerHTML = `
        <div class="accent-line"></div>
        <div class="icon-wrap">
            <img class="notify-icon" src="${data.icon}" draggable="false" alt="">
        </div>
        <div class="notify-body">
            <div class="notify-title">${escapeHtml(data.title)}</div>
            <div class="notify-message">${escapeHtml(item.message)}</div>
        </div>
        <div class="progress"><div class="progress-bar" style="animation-duration:${item.duration}ms;"></div></div>
    `;

    rootEl.appendChild(el);

    setTimeout(() => removeNotification(el), item.duration);
}

function removeNotification(el) {
    if (!el || !el.parentNode) return;
    el.classList.add('removing');

    setTimeout(() => {
        if (el.parentNode) el.parentNode.removeChild(el);
        visibleCount = Math.max(0, visibleCount - 1);
        processQueue();
    }, 240);
}

function processQueue() {
    while (visibleCount < MAX_VISIBLE && queue.length > 0) {
        renderNotification(queue.shift());
    }
}

function clearAll() {
    queue = [];
    Array.from(rootEl.children).forEach(el => {
        if (el && el.parentNode) el.parentNode.removeChild(el);
    });
    visibleCount = 0;
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'notify') push(data.payload || {});
    if (data.action === 'setSound') soundEnabled = data.enabled !== false;
    if (data.action === 'clear') clearAll();
});

window.driftNotify = { push, clear: clearAll };

setTimeout(() => nui('ready'), 100);
