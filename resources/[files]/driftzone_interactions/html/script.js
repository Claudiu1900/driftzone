'use strict';

const interactionRoot = document.getElementById('interactionRoot');
const keyBox = document.getElementById('keyBox');
const interactionText = document.getElementById('interactionText');
const interactionSubText = document.getElementById('interactionSubText');
let visible = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(data) {
    const payload = data || {};
    if (payload.mainColor) {
        document.documentElement.style.setProperty('--main', payload.mainColor);
    }
    keyBox.textContent = String(payload.key || 'E');
    interactionText.textContent = String(payload.text || 'Apasa E pentru a interactiona');
    interactionSubText.textContent = String(payload.subText || '');
    if (!visible) {
        visible = true;
        interactionRoot.classList.remove('hidden');
    }
}

function hide() {
    if (!visible) return;
    visible = false;
    interactionRoot.classList.add('hidden');
}

window.driftInteractions = { show, hide };

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'show') show(data.data || {});
    if (data.action === 'hide') hide();
});

setTimeout(() => nui('ready'), 50);
