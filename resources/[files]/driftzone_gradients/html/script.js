'use strict';

const selector = document.getElementById('selector');
const panel = document.getElementById('panel');
const gradientName = document.getElementById('gradientName');
const plateText = document.getElementById('plateText');
const modeText = document.getElementById('modeText');
const question = document.getElementById('question');
const actions = document.getElementById('actions');

let inSelector = false;
let lastCursor = 0;
let currentMode = 'apply';

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(el) { el.classList.remove('hidden'); }
function hide(el) { el.classList.add('hidden'); }
function clearActions() { actions.innerHTML = ''; }

function button(label, type, main) {
    const btn = document.createElement('button');
    btn.textContent = label;
    if (main) btn.classList.add('main');
    btn.onclick = () => apply(type);
    actions.appendChild(btn);
}

function cancel() {
    hide(selector);
    hide(panel);
    inSelector = false;
    currentMode = 'apply';
    nui('cancel');
}

function apply(type) {
    hide(panel);
    const endpoint = currentMode === 'remove' ? 'remove' : 'apply';
    nui(endpoint, { applyTo: type });
}

function renderApplyMenu(data) {
    currentMode = 'apply';
    clearActions();
    modeText.textContent = 'DRIFTZONE GRADIENT';
    gradientName.textContent = data.gradient?.label || `Gradient ${data.gradient?.id || ''}`;
    plateText.textContent = data.plate ? `Plate ${data.plate}` : 'Vehicle selected';
    question.textContent = 'Seteaza culoarea Gradient pe:';
    button('Culoare Principala', 'primary', false);
    button('Culoare Secundara', 'secondary', false);
    button('Ambele', 'both', true);
}

function renderRemoveMenu(data) {
    currentMode = 'remove';
    clearActions();
    modeText.textContent = 'DRIFTZONE REMOVE GRADIENT';
    gradientName.textContent = 'Scoate gradient';
    plateText.textContent = data.plate ? `Plate ${data.plate}` : 'Vehicle selected';
    question.textContent = 'Scoate gradientul de pe:';

    const parts = data.parts || {};
    if (parts.primary) button('Culoare Principala', 'primary', false);
    if (parts.secondary) button('Culoare Secundara', 'secondary', false);
    if (parts.both) button('Ambele', 'both', true);

    if (!parts.primary && !parts.secondary && !parts.both) {
        const empty = document.createElement('div');
        empty.className = 'empty';
        empty.textContent = 'Masina nu are gradient disponibil.';
        actions.appendChild(empty);
    }
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
        currentMode = data.mode === 'remove' ? 'remove' : 'apply';
        inSelector = true;
        show(selector);
        hide(panel);
    }

    if (data.action === 'applyMenu') {
        inSelector = false;
        hide(selector);
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        renderApplyMenu(data);
        show(panel);
    }

    if (data.action === 'removeMenu') {
        inSelector = false;
        hide(selector);
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        renderRemoveMenu(data);
        show(panel);
    }

    if (data.action === 'close') {
        inSelector = false;
        hide(selector);
        hide(panel);
    }
});

setTimeout(() => nui('ready'), 100);
