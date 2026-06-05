'use strict';

const panel = document.getElementById('coordsPanel');
const coordsInput = document.getElementById('coordsInput');
const xInput = document.getElementById('xInput');
const yInput = document.getElementById('yInput');
const zInput = document.getElementById('zInput');
const headingInput = document.getElementById('headingInput');
const dimensionInput = document.getElementById('dimensionInput');
const statusEl = document.getElementById('status');

let currentCoords = '';

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

async function copyText(text) {
    try {
        await navigator.clipboard.writeText(text);
        statusEl.textContent = 'Coordonatele au fost copiate.';
        return true;
    } catch (e) {
        try {
            coordsInput.focus();
            coordsInput.select();
            document.execCommand('copy');
            statusEl.textContent = 'Coordonatele au fost copiate.';
            return true;
        } catch (err) {
            statusEl.textContent = 'Auto-copy blocat. Apasa COPY.';
            return false;
        }
    }
}

function showCoords(data) {
    const payload = data || {};

    currentCoords = String(payload.coords || '');

    coordsInput.value = currentCoords;
    xInput.value = Number(payload.x || 0).toFixed(6);
    yInput.value = Number(payload.y || 0).toFixed(6);
    zInput.value = Number(payload.z || 0).toFixed(6);
    headingInput.value = Number(payload.heading || 0).toFixed(2);
    dimensionInput.value = Number(payload.dimension || 0);

    panel.classList.remove('hidden');

    setTimeout(() => {
        copyText(currentCoords);
    }, 120);
}

function copyCoords() {
    copyText(currentCoords);
}

function closePanel() {
    panel.classList.add('hidden');
    nui('closeCoords');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'coords') {
        showCoords(data.data || {});
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closePanel();
    }
});