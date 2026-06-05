'use strict';

const root = document.getElementById('root');
const list = document.getElementById('list');
const statusEl = document.getElementById('status');

let keybinds = [];
let listeningId = null;
let previousKey = null;

function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).then((response) => response.json()).catch(() => ({ ok: false, error: 'NUI error.' }));
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function showStatus(text, error = false) {
    statusEl.textContent = String(text || '');
    statusEl.classList.toggle('error', error === true);
    statusEl.classList.remove('hidden');

    if (!error) {
        setTimeout(() => {
            if (!listeningId) statusEl.classList.add('hidden');
        }, 1800);
    }
}

function clearStatus() {
    if (listeningId) return;
    statusEl.classList.add('hidden');
    statusEl.classList.remove('error');
    statusEl.textContent = '';
}

function normalizeKeyFromEvent(event) {
    const key = event.key || '';
    const code = event.code || '';

    if (key === ' ') return 'SPACE';
    if (key === 'Escape') return 'ESC';
    if (key === 'Control') return 'CTRL';
    if (key === 'Shift') return 'SHIFT';
    if (key === 'Alt') return 'ALT';
    if (key === 'ArrowUp') return 'UP';
    if (key === 'ArrowDown') return 'DOWN';
    if (key === 'ArrowLeft') return 'LEFT';
    if (key === 'ArrowRight') return 'RIGHT';
    if (key === 'Backspace') return 'BACKSPACE';
    if (key === 'Delete') return 'DELETE';
    if (key === 'Enter') return 'ENTER';
    if (key === 'Tab') return 'TAB';

    if (/^F\d{1,2}$/i.test(key)) return key.toUpperCase();
    if (/^Key[A-Z]$/.test(code)) return code.replace('Key', '').toUpperCase();
    if (/^Digit\d$/.test(code)) return code.replace('Digit', '').toUpperCase();

    if (key.length === 1) return key.toUpperCase();

    return key.toUpperCase().replace(/\s+/g, '');
}

function open(payload) {
    const data = payload || {};

    if (data.mainColor) {
        document.documentElement.style.setProperty('--main', data.mainColor);
    }

    keybinds = Array.isArray(data.keybinds) ? data.keybinds : [];
    listeningId = null;
    previousKey = null;

    root.classList.remove('hidden');
    clearStatus();
    render();
}

function close() {
    root.classList.add('hidden');
    listeningId = null;
    previousKey = null;
    clearStatus();
}

function closeMenu() {
    nui('close');
}

function startListening(id) {
    const bind = keybinds.find((item) => item.id === id);
    if (!bind) return;

    listeningId = id;
    previousKey = bind.key;
    showStatus('Apasa pe o tasta. ESC = abandon.', false);
    render();
}

async function setKey(id, key) {
    const response = await nui('setKey', { id, key });

    if (!response || response.ok !== true) {
        showStatus(response && response.error ? response.error : 'Tasta nu a putut fi salvata.', true);
        listeningId = null;
        previousKey = null;
        render();
        return;
    }

    showStatus(`Keybind salvat: ${key}`, false);
    listeningId = null;
    previousKey = null;
}

async function resetKey(id) {
    const response = await nui('resetKey', { id });

    if (!response || response.ok !== true) {
        showStatus('Nu am putut reseta keybind-ul.', true);
        return;
    }

    showStatus('Keybind resetat.', false);
}

async function resetAll() {
    const response = await nui('resetAll');

    if (!response || response.ok !== true) {
        showStatus('Nu am putut reseta keybind-urile.', true);
        return;
    }

    showStatus('Toate keybind-urile au fost resetate.', false);
}

function render() {
    if (!keybinds.length) {
        list.innerHTML = '<div class="bind-card"><div><div class="bind-title">Nu exista keybind-uri configurate.</div></div></div>';
        return;
    }

    list.innerHTML = keybinds.map((bind) => {
        const listening = listeningId === bind.id;
        const supported = bind.supported !== false;
        const meta = supported
            ? `${escapeHtml(bind.eventType || 'command')} • ${escapeHtml(bind.eventName || '')}`
            : 'Tasta nesuportata fara RegisterKeyMapping. Alege alta tasta.';

        return `
            <div class="bind-card">
                <div>
                    <div class="bind-title">${escapeHtml(bind.name)}</div>
                    <div class="bind-desc">${escapeHtml(bind.description)}</div>
                    <div class="bind-meta ${supported ? '' : 'unsupported'}">${meta}</div>
                </div>

                <button class="key-btn ${listening ? 'listening' : ''}" onclick="startListening('${escapeHtml(bind.id)}')">
                    ${listening ? 'APASA O TASTA' : escapeHtml(bind.key || '-')}
                </button>

                <button class="reset-key" onclick="resetKey('${escapeHtml(bind.id)}')">
                    RESET KEY
                </button>
            </div>
        `;
    }).join('');
}

window.addEventListener('keydown', (event) => {
    if (listeningId) {
        event.preventDefault();
        event.stopPropagation();

        const key = normalizeKeyFromEvent(event);

        if (key === 'ESC') {
            listeningId = null;
            previousKey = null;
            showStatus('Schimbarea a fost abandonata.', false);
            render();
            return false;
        }

        setKey(listeningId, key);
        return false;
    }

    if (event.key === 'Escape') {
        event.preventDefault();
        event.stopPropagation();
        closeMenu();
        return false;
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        open(data.payload || {});
    }

    if (data.action === 'refresh') {
        const wasListening = listeningId;
        open(data.payload || {});
        listeningId = null;
        previousKey = null;
        if (wasListening) clearStatus();
    }

    if (data.action === 'close') {
        close();
    }
});

setTimeout(() => {
    nui('ready');
}, 50);
