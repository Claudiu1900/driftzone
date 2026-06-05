'use strict';

const MAX_MESSAGES = 90;
const MAX_LENGTH = 160;
const HIDE_AFTER_MS = 6000;
const HISTORY_LIMIT = 30;
const HISTORY_STORAGE_KEY = 'driftzone_chat_history';

const rootEl = document.getElementById('chatRoot');
const messagesEl = document.getElementById('messages');
const inputBoxEl = document.getElementById('inputBox');
const inputEl = document.getElementById('chatInput');

let opened = false;
let enabled = true;
let muted = false;
let hideTimer = null;
let userScrolledUp = false;

let messageHistory = [];
let historyIndex = -1;
let draftBeforeHistory = '';

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function loadHistory() {
    try {
        const raw = localStorage.getItem(HISTORY_STORAGE_KEY);
        const parsed = JSON.parse(raw || '[]');

        if (Array.isArray(parsed)) {
            messageHistory = parsed
                .filter((item) => typeof item === 'string' && item.trim().length > 0)
                .slice(-HISTORY_LIMIT);
        }
    } catch (e) {
        messageHistory = [];
    }
}

function saveHistory() {
    try {
        localStorage.setItem(
            HISTORY_STORAGE_KEY,
            JSON.stringify(messageHistory.slice(-HISTORY_LIMIT))
        );
    } catch (e) {}
}

function addToHistory(message) {
    const text = String(message || '').trim();
    if (!text) return;

    const last = messageHistory[messageHistory.length - 1];

    if (last !== text) {
        messageHistory.push(text);

        if (messageHistory.length > HISTORY_LIMIT) {
            messageHistory.shift();
        }

        saveHistory();
    }

    historyIndex = -1;
    draftBeforeHistory = '';
}

function setInputValue(value) {
    inputEl.value = String(value || '').slice(0, MAX_LENGTH);
    inputEl.setSelectionRange(inputEl.value.length, inputEl.value.length);
}

function handleHistoryNavigation(direction) {
    if (!opened) return;
    if (messageHistory.length === 0) return;

    if (direction === 'up') {
        if (historyIndex === -1) {
            draftBeforeHistory = inputEl.value;
            historyIndex = 0;
        } else if (historyIndex < messageHistory.length - 1) {
            historyIndex++;
        }

        const historyPosition = messageHistory.length - 1 - historyIndex;
        setInputValue(messageHistory[historyPosition]);
        return;
    }

    if (direction === 'down') {
        if (historyIndex === -1) return;

        if (historyIndex > 0) {
            historyIndex--;

            const historyPosition = messageHistory.length - 1 - historyIndex;
            setInputValue(messageHistory[historyPosition]);
            return;
        }

        historyIndex = -1;
        setInputValue(draftBeforeHistory);
        draftBeforeHistory = '';
    }
}

function resetHistoryNavigation() {
    historyIndex = -1;
    draftBeforeHistory = '';
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function sanitizeHexColor(value, fallback) {
    const raw = String(value || '').trim();

    if (/^#[0-9a-fA-F]{6}$/.test(raw) || /^#[0-9a-fA-F]{3}$/.test(raw)) {
        return raw;
    }

    return fallback;
}

function normalizeType(type) {
    if (type === 'error') return 'error';
    if (type === 'system') return 'system';

    return 'chat';
}

function isNearBottom() {
    return messagesEl.scrollHeight - messagesEl.scrollTop - messagesEl.clientHeight < 20;
}

function showChat() {
    if (!enabled) return;

    rootEl.classList.remove('hidden-root');

    if (hideTimer) {
        clearTimeout(hideTimer);
        hideTimer = null;
    }
}

function scheduleHide() {
    if (hideTimer) {
        clearTimeout(hideTimer);
        hideTimer = null;
    }

    if (opened) return;

    hideTimer = setTimeout(() => {
        if (opened) return;
        rootEl.classList.add('hidden-root');
    }, HIDE_AFTER_MS);
}

function buildBadges(payload) {
    const badges = [];

    if (payload.admin && payload.admin.label && payload.admin.color) {
        const adminLabel = escapeHtml(payload.admin.label);
        const adminColor = sanitizeHexColor(payload.admin.color, '#04c7f7');

        badges.push(
            `<span class="badge badge-admin" style="background:${adminColor};">${adminLabel}</span>`
        );
    }

    if (payload.rank && payload.rank.label && payload.rank.color) {
        const rankLabel = escapeHtml(payload.rank.label);
        const rankColor = sanitizeHexColor(payload.rank.color, '#cbd5e1');

        badges.push(
            `<span class="badge badge-rank" style="background:${rankColor};">${rankLabel}</span>`
        );
    }

    const uid = Number(payload.uid || 0);

    if (payload.type !== 'system' && uid > 0) {
        badges.push(`<span class="badge badge-id">ID: ${uid}</span>`);
    }

    return badges.join('');
}

function buildMessage(payload) {
    const type = normalizeType(payload.type);
    const time = escapeHtml(payload.time || '--:--');
    const text = escapeHtml(payload.text || '');

    if (type === 'error') {
        return `
            <span class="time">${time}</span>
            <span class="badge badge-id">ERROR</span>
            <span class="text">${text}</span>
        `;
    }

    if (type === 'system') {
        return `
            <span class="time">${time}</span>
            <span class="badge badge-id">SERVER</span>
            <span class="text">${text}</span>
        `;
    }

    const name = escapeHtml(payload.name || 'Player');

    return `
        <span class="time">${time}</span>
        ${buildBadges(payload)}
        <span class="name">${name}:</span>
        <span class="text">${text}</span>
    `;
}

function addMessage(payload) {
    if (!enabled) return;

    const shouldStickToBottom = isNearBottom() && !userScrolledUp;

    const safePayload = payload || {};
    const type = normalizeType(safePayload.type);

    const el = document.createElement('div');
    el.className = `message ${type}`;
    el.innerHTML = buildMessage({
        ...safePayload,
        type
    });

    messagesEl.appendChild(el);

    while (messagesEl.children.length > MAX_MESSAGES) {
        messagesEl.removeChild(messagesEl.firstElementChild);
    }

    showChat();

    requestAnimationFrame(() => {
        if (shouldStickToBottom || !opened) {
            messagesEl.scrollTop = messagesEl.scrollHeight;
            userScrolledUp = false;
        }
    });

    scheduleHide();
}

function open(prefill) {
    if (!enabled) return;

    opened = true;
    userScrolledUp = false;
    resetHistoryNavigation();

    showChat();

    rootEl.classList.remove('hidden-root');
    rootEl.classList.add('opened');

    inputBoxEl.classList.remove('hidden');

    setInputValue(String(prefill || '').slice(0, MAX_LENGTH));

    setTimeout(() => {
        inputEl.focus();
        inputEl.setSelectionRange(inputEl.value.length, inputEl.value.length);
    }, 0);

    messagesEl.scrollTop = messagesEl.scrollHeight;
}

function close() {
    opened = false;

    resetHistoryNavigation();

    rootEl.classList.remove('opened');
    inputBoxEl.classList.add('hidden');

    inputEl.blur();

    scheduleHide();
}

function submitFromGame() {
    if (!opened) return;

    const value = inputEl.value.trim();

    if (value.length > 0) {
        addToHistory(value);
    }

    nui('submit', {
        message: value
    });
}

function clear() {
    messagesEl.innerHTML = '';
    userScrolledUp = false;

    if (!opened) {
        rootEl.classList.add('hidden-root');
    }
}

function setEnabled(state) {
    enabled = state === true;

    if (!enabled) {
        opened = false;

        inputEl.blur();

        inputBoxEl.classList.add('hidden');
        rootEl.classList.remove('opened');
        rootEl.classList.add('hidden-root');

        resetHistoryNavigation();
        return;
    }

    scheduleHide();
}

function setMuted(state) {
    muted = state === true;
}

messagesEl.addEventListener('scroll', () => {
    userScrolledUp = !isNearBottom();
});

inputEl.addEventListener('keydown', (event) => {
    if (event.key === 'ArrowUp') {
        event.preventDefault();
        handleHistoryNavigation('up');
        return;
    }

    if (event.key === 'ArrowDown') {
        event.preventDefault();
        handleHistoryNavigation('down');
        return;
    }

    if (event.key === 'Enter') {
        event.preventDefault();
        submitFromGame();
        return;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        nui('close');
        return;
    }

    if (
        event.key.length === 1 ||
        event.key === 'Backspace' ||
        event.key === 'Delete'
    ) {
        resetHistoryNavigation();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        open(data.prefill || '');
    }

    if (data.action === 'close') {
        close();
    }

    if (data.action === 'addMessage') {
        addMessage(data.payload || {});
    }

    if (data.action === 'clear') {
        clear();
    }

    if (data.action === 'setEnabled') {
        setEnabled(data.enabled === true);
    }

    if (data.action === 'setMuted') {
        setMuted(data.muted === true);
    }
});

window.driftChat = {
    open,
    close,
    addMessage,
    clear,
    setEnabled,
    setMuted,
    submitFromGame
};

loadHistory();
setEnabled(true);
clear();

setTimeout(() => {
    nui('ready');
}, 50);