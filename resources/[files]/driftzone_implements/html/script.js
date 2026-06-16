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

function setMainColor(color) {
    if (color) document.documentElement.style.setProperty('--main', String(color));
}

function show(data = {}) {
    setMainColor(data.mainColor);
    keyBox.textContent = String(data.key || 'E');
    interactionText.textContent = String(data.text || 'Apasă E pentru interacțiune');
    const sub = String(data.subText || '');
    interactionSubText.textContent = sub;
    interactionSubText.classList.toggle('hidden', sub.trim() === '');
    if (!visible) {
        visible = true;
        interactionRoot.classList.remove('hidden');
        interactionRoot.classList.remove('closing');
    }
}

function hide() {
    if (!visible) return;
    visible = false;
    interactionRoot.classList.add('closing');
    setTimeout(() => {
        if (!visible) interactionRoot.classList.add('hidden');
        interactionRoot.classList.remove('closing');
    }, 160);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'show') show(data.data || {});
    if (data.action === 'hide') hide();
});

setTimeout(() => nui('ready'), 60);
