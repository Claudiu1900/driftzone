'use strict';

const root = document.getElementById('root');
const modelName = document.getElementById('modelName');
const modelInput = document.getElementById('modelInput');
const loadBtn = document.getElementById('loadBtn');
const statusText = document.getElementById('statusText');
const emptyBox = document.getElementById('emptyBox');
const studioControls = document.getElementById('studioControls');
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
let hasVehicle = false;
let loading = false;

function nui(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((res) => res.json().catch(() => ({}))).catch(() => ({}));
}

function show() { root.classList.remove('hidden'); }
function hide() { root.classList.add('hidden'); }
function setStatus(text, type = '') {
    statusText.textContent = text || '';
    statusText.classList.remove('ok', 'bad');
    if (type) statusText.classList.add(type);
}
function control(action) {
    if (!hasVehicle) {
        setStatus('Incarca un model de masina mai intai.', 'bad');
        return;
    }
    nui('control', { action });
}
function closePanel() { nui('close'); hide(); }
function toggleClean() { nui('toggleClean'); }

function cleanModel(value) {
    return String(value || '').toLowerCase().replace(/\s+/g, '').replace(/[^a-z0-9_\-]/g, '');
}

async function loadModel() {
    if (loading) return;
    const model = cleanModel(modelInput.value);
    modelInput.value = model;

    if (!model) {
        setStatus('Scrie modelul masinii.', 'bad');
        modelInput.focus();
        return;
    }

    loading = true;
    loadBtn.disabled = true;
    loadBtn.textContent = '...';
    setStatus(`Se incarca ${model.toUpperCase()}...`);

    const response = await nui('loadModel', { model, keepView: true });

    loading = false;
    loadBtn.disabled = false;
    loadBtn.textContent = 'LOAD';

    if (response && response.ok) {
        setStatus(`${model.toUpperCase()} incarcat in studio.`, 'ok');
    } else {
        const error = response && response.error ? String(response.error) : '';
        if (error === 'invalid') setStatus(`Model invalid: ${model}`, 'bad');
        else if (error === 'timeout') setStatus(`Modelul nu s-a incarcat: ${model}`, 'bad');
        else setStatus(`Nu am putut incarca modelul: ${model}`, 'bad');
    }
}

function updateVehicleState(vehicleState) {
    hasVehicle = !!vehicleState;
    emptyBox.classList.toggle('hidden', hasVehicle);
    studioControls.classList.toggle('disabled', !hasVehicle);
}

function updateState(data = {}) {
    updateVehicleState(!!data.hasVehicle);
    const model = String(data.model || '').trim();
    modelName.textContent = model ? model.toUpperCase() : 'Alege modelul';
    if (model) modelInput.value = model.toLowerCase();

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
    if (hasVehicle && model && !loading) setStatus(`${model.toUpperCase()} incarcat in studio.`, 'ok');
    hint.textContent = hasVehicle
        ? 'Tasta ` ascunde/arata UI-ul, minimap-ul si HUD-ul. Escape inchide meniul.'
        : 'Scrie modelul masinii si apasa Enter sau LOAD.';
}

function setCleanModeUI(enabled) {
    cleanMode = !!enabled;
    cleanBtn.textContent = cleanMode ? 'SHOW UI / HUD (`)' : 'HIDE UI / HUD (`)';
    if (cleanMode) hide(); else show();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        const model = cleanModel(data.model || '');
        cleanMode = false;
        show();

        if (model) {
            modelName.textContent = model.toUpperCase();
            modelInput.value = model;
            setStatus(`Se incarca ${model.toUpperCase()}...`);
        } else {
            modelName.textContent = 'Alege modelul';
            modelInput.value = '';
            setStatus('Scrie modelul masinii si apasa Enter sau LOAD.');
        }

        setTimeout(() => {
            modelInput.focus();
            modelInput.select();
        }, 80);
    }

    if (data.action === 'state') updateState(data);
    if (data.action === 'cleanMode') setCleanModeUI(!!data.enabled);
    if (data.action === 'loadFailed') {
        const model = cleanModel(data.model || modelInput.value);
        setStatus(model ? `Nu am putut incarca modelul: ${model}` : 'Scrie modelul masinii.', 'bad');
    }
    if (data.action === 'close') hide();
});

window.addEventListener('keydown', (e) => {
    if (e.key === '`' || e.code === 'Backquote') {
        e.preventDefault();
        toggleClean();
        return;
    }

    if (e.key === 'Escape' || e.key === 'Backspace') {
        if (document.activeElement === modelInput && modelInput.value.length > 0 && e.key === 'Backspace') return;
        closePanel();
        return;
    }

    if (e.key === 'Enter' && document.activeElement === modelInput) loadModel();
    if (e.key === 'ArrowLeft') control('rotate_left');
    if (e.key === 'ArrowRight') control('rotate_right');
    if (e.key === 'ArrowUp') control('fov_up');
    if (e.key === 'ArrowDown') control('fov_down');
});
