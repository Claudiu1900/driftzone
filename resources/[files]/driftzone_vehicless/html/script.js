'use strict';

const root = document.getElementById('root');
const modelName = document.getElementById('modelName');
const rotationValue = document.getElementById('rotationValue');
const fovValue = document.getElementById('fovValue');
const distanceValue = document.getElementById('distanceValue');
const heightValue = document.getElementById('heightValue');
const autoBtn = document.getElementById('autoBtn');
const lightsBtn = document.getElementById('lightsBtn');
const doorsBtn = document.getElementById('doorsBtn');
const shotBtn = document.getElementById('shotBtn');
const hint = document.getElementById('hint');

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
function screenshot() {
    shotBtn.disabled = true;
    shotBtn.textContent = 'CAPTURING...';
    nui('screenshot');
}

function downloadImage(dataUrl, filename) {
    try {
        const a = document.createElement('a');
        a.href = dataUrl;
        a.download = filename || `driftzone_vehicle_${Date.now()}.png`;
        document.body.appendChild(a);
        a.click();
        a.remove();
    } catch (e) {}
}

function updateState(data = {}) {
    modelName.textContent = String(data.model || 'Vehicle').toUpperCase();
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
    hint.textContent = data.screenshotReady ? 'Screenshot-ul se salvează în Downloads sau în folderul ales de browser.' : 'Pentru screenshot pornește resource-ul screenshot-basic.';
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        modelName.textContent = String(data.model || 'Vehicle').toUpperCase();
        show();
    }

    if (data.action === 'state') updateState(data);

    if (data.action === 'prepareShot') {
        root.classList.add('shooting');
    }

    if (data.action === 'downloadScreenshot') {
        downloadImage(data.image, data.filename);
    }

    if (data.action === 'shotDone') {
        root.classList.remove('shooting');
        shotBtn.disabled = false;
        shotBtn.textContent = 'SCREENSHOT';
    }

    if (data.action === 'close') hide();
});

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'Backspace') closePanel();
    if (e.key === 'ArrowLeft') control('rotate_left');
    if (e.key === 'ArrowRight') control('rotate_right');
    if (e.key === 'ArrowUp') control('fov_up');
    if (e.key === 'ArrowDown') control('fov_down');
});
