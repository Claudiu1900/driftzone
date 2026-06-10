'use strict';

const selector = document.getElementById('selector');
const panel = document.getElementById('panel');
const gradientName = document.getElementById('gradientName');
const plateText = document.getElementById('plateText');
let inSelector = false;
let lastCursor = 0;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }

function cancel() {
    hide(selector);
    hide(panel);
    inSelector = false;
    nui('cancel');
}

function apply(type) {
    hide(panel);
    nui('apply', { applyTo: type });
}

window.addEventListener('mousemove', (e) => {
    if (!inSelector) return;
    const now = performance.now();
    if (now - lastCursor < 16) return;
    lastCursor = now;
    nui('cursor', { x: e.clientX / window.innerWidth, y: e.clientY / window.innerHeight });
});

window.addEventListener('mousedown', (e) => {
    if (!inSelector || e.button !== 0) return;
    nui('click');
});

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'Backspace') cancel();
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'selector') {
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        inSelector = true;
        show(selector);
        hide(panel);
    }

    if (data.action === 'applyMenu') {
        inSelector = false;
        hide(selector);
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        gradientName.textContent = data.gradient?.label || `Gradient ${data.gradient?.id || ''}`;
        plateText.textContent = data.plate ? `Plate ${data.plate}` : 'Vehicle selected';
        show(panel);
    }

    if (data.action === 'close') {
        inSelector = false;
        hide(selector);
        hide(panel);
    }
});

setTimeout(() => nui('ready'), 100);
