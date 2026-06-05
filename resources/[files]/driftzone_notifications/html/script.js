'use strict';

const MAX_VISIBLE = 7;
const DEFAULT_DURATION = 5000;
const MIN_DURATION = 1500;
const MAX_DURATION = 20000;

const rootEl = document.getElementById('notifyRoot');
const notificationSound = document.getElementById('notificationSound');

let visibleCount = 0;
let queue = [];
let notificationId = 0;
let soundEnabled = true;

const typeData = {
    info: {
        title: 'Informatie',
        image: 'info.png'
    },
    warning: {
        title: 'Warning',
        image: 'warning.png'
    },
    error: {
        title: 'Error',
        image: 'error.png'
    }
};

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
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
    const safeType = String(type || '').trim().toLowerCase();

    if (safeType === 'warning') return 'warning';
    if (safeType === 'error') return 'error';

    return 'info';
}

function normalizeDuration(duration) {
    const value = Number(duration);

    if (!Number.isFinite(value)) {
        return DEFAULT_DURATION;
    }

    return Math.max(MIN_DURATION, Math.min(MAX_DURATION, Math.floor(value)));
}

function playNotificationSound() {
    if (!soundEnabled || !notificationSound) return;

    try {
        notificationSound.volume = 0.45;
        notificationSound.currentTime = 0;

        const promise = notificationSound.play();

        if (promise && typeof promise.catch === 'function') {
            promise.catch(() => {});
        }
    } catch (e) {}
}

function push(payload) {
    const item = {
        id: ++notificationId,
        type: normalizeType(payload && payload.type),
        duration: normalizeDuration(payload && payload.duration),
        message: String((payload && payload.message) || '').trim()
    };

    if (!item.message) return;

    if (visibleCount >= MAX_VISIBLE) {
        queue.push(item);

        if (queue.length > 40) {
            queue.shift();
        }

        return;
    }

    renderNotification(item);
}

function renderNotification(item) {
    visibleCount++;

    playNotificationSound();

    const data = typeData[item.type] || typeData.info;

    const el = document.createElement('div');
    el.className = `notification ${item.type}`;
    el.dataset.id = String(item.id);

    el.innerHTML = `
        <div class="notify-glow"></div>

        <div class="notify-icon-box">
            <img class="notify-icon" src="${data.image}" draggable="false" onerror="this.style.display='none';">
        </div>

        <div class="notify-content">
            <div class="notify-title">${escapeHtml(data.title)}</div>
            <div class="notify-message">${escapeHtml(item.message)}</div>
        </div>

        <div class="notify-progress-track">
            <div class="notify-progress-bar" style="animation-duration:${item.duration}ms;"></div>
        </div>
    `;

    rootEl.appendChild(el);

    setTimeout(() => {
        removeNotification(el);
    }, item.duration);
}

function removeNotification(el) {
    if (!el || !el.parentNode) return;

    el.classList.add('removing');

    setTimeout(() => {
        if (el.parentNode) {
            el.parentNode.removeChild(el);
        }

        visibleCount = Math.max(0, visibleCount - 1);
        processQueue();
    }, 270);
}

function processQueue() {
    while (visibleCount < MAX_VISIBLE && queue.length > 0) {
        const next = queue.shift();
        renderNotification(next);
    }
}

window.driftNotify = {
    push
};

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'notify') {
        push(data.payload || {});
    }

    if (data.action === 'setSound') {
        soundEnabled = data.enabled !== false;
    }
});

setTimeout(() => {
    nui('ready');
}, 100);