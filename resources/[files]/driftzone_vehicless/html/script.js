'use strict';

const root = document.getElementById('root');
const modelName = document.getElementById('modelName');
const modelInput = document.getElementById('modelInput');
const rotationValue = document.getElementById('rotationValue');
const fovValue = document.getElementById('fovValue');
const distanceValue = document.getElementById('distanceValue');
const heightValue = document.getElementById('heightValue');
const autoBtn = document.getElementById('autoBtn');
const lightsBtn = document.getElementById('lightsBtn');
const doorsBtn = document.getElementById('doorsBtn');
const cleanBtn = document.getElementById('cleanBtn');
const hint = document.getElementById('hint');

let cleanMode = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show() { root.classList.remove('hidden'); }
function hide() { root.classList.add('hidden'); }
function control(action) { nui('control', { action }); }
function closePanel() { nui('close'); hide(); }
function toggleClean() { nui('toggleClean'); }

function cleanModel(value) {
    return String(value || '').toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9_\-]/g, '');
}

function loadModel() {
    const model = cleanModel(modelInput.value);
    if (!model) {
        hint.textContent = 'Scrie modelul masinii.';
        return;
    }
    hint.textContent = `Se incarca ${model.toUpperCase()}...`;
    nui('loadModel', { model, keepView: true });
}

function updateState(data = {}) {
    const model = String(data.model || 'Vehicle').toUpperCase();
    modelName.textContent = model;
    modelInput.value = String(data.model || '').toLowerCase();
    rotationValue.textContent = `${Number(data.heading || 0).toFixed(1)}°`;
    fovValue.textContent = Number(data.fov || 0).toFixed(1);
    distanceValue.textContent = Number(data.distance || 0).toFixed(1);
    heightValue.textContent = Number(data.height || 0).toFixed(1);
    autoBtn.textContent = data.autoRotate ? 'AUTO ROTATE ON' : 'AUTO ROTATE OFF';
    autoBtn.classList.toggle('active', !!data.autoRotate);
    lightsBtn.textContent = data.lights ? 'LIGHTS ON' : 'LIGHTS OFF';
    lightsBtn.classList.toggle('active', !!data.lights);
    doorsBtn.textContent = data.doors ? 'DOORS ON' : 'DOORS OFF';
    doorsBtn.classList.toggle('active', !!data.doors);
    cleanMode = !!data.cleanMode;
    cleanBtn.textContent = cleanMode ? 'SHOW UI / HUD (`)' : 'HIDE UI / HUD (`)';
    hint.textContent = 'Apasa tasta ` ca sa dispara UI-ul, minimap-ul si HUD-ul. Apasa iar ca sa revina.';
}

function setCleanModeUI(enabled) {
    cleanMode = !!enabled;
    cleanBtn.textContent = cleanMode ? 'SHOW UI / HUD (`)' : 'HIDE UI / HUD (`)';

    if (cleanMode) {
        hide();
    } else {
        show();
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        const model = String(data.model || 'Vehicle');
        modelName.textContent = model.toUpperCase();
        modelInput.value = model.toLowerCase();
        cleanMode = false;
        show();
        setTimeout(() => modelInput.select(), 120);
    }

    if (data.action === 'state') updateState(data);
    if (data.action === 'cleanMode') setCleanModeUI(!!data.enabled);
    if (data.action === 'close') hide();
});

window.addEventListener('keydown', (e) => {
    if (e.key === '`' || e.code === 'Backquote') {
        e.preventDefault();
        toggleClean();
        return;
    }

    if (e.key === 'Escape' || e.key === 'Backspace') closePanel();
    if (e.key === 'Enter' && document.activeElement === modelInput) loadModel();
    if (e.key === 'ArrowLeft') control('rotate_left');
    if (e.key === 'ArrowRight') control('rotate_right');
    if (e.key === 'ArrowUp') control('fov_up');
    if (e.key === 'ArrowDown') control('fov_down');
});
