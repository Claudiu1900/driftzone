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

function screenshot() {
    shotBtn.disabled = true;
    shotBtn.textContent = 'CAPTURING...';
    nui('screenshot');
    setTimeout(() => {
        if (shotBtn.disabled) {
            shotBtn.disabled = false;
            shotBtn.textContent = 'SCREENSHOT';
        }
    }, 5000);
}

function downloadImage(dataUrl, filename) {
    try {
        const a = document.createElement('a');
        a.href = dataUrl;
        a.download = filename || `driftzone_vehicle_${Date.now()}.png`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        return true;
    } catch (e) {
        return false;
    }
}

function nuiResult(ok, error) {
    nui('shotResult', { ok: !!ok, error: error ? String(error) : '' });
}

function getThreeApi() {
    const t = window.THREE || window.three || null;
    const cfx = window.CfxTexture || (t && (t.CfxTexture || t.CFXTexture)) || null;
    return { t, cfx };
}

async function captureGameViewInternal(options = {}) {
    const { t, cfx } = getThreeApi();
    if (!t || !cfx) throw new Error('CfxTexture/THREE unavailable in this game build');

    const width = Math.max(1, window.innerWidth || 1280);
    const height = Math.max(1, window.innerHeight || 720);

    const cameraRTT = new t.OrthographicCamera(width / -2, width / 2, height / 2, height / -2, -10000, 10000);
    cameraRTT.position.z = 100;

    const sceneRTT = new t.Scene();
    const rtTexture = new t.WebGLRenderTarget(width, height, {
        minFilter: t.LinearFilter,
        magFilter: t.NearestFilter,
        format: t.RGBAFormat,
        type: t.UnsignedByteType
    });

    const gameTexture = new cfx();
    gameTexture.needsUpdate = true;

    const material = new t.ShaderMaterial({
        uniforms: { tDiffuse: { value: gameTexture } },
        vertexShader: `
            varying vec2 vUv;
            void main() {
                vUv = vec2(uv.x, 1.0 - uv.y);
                gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
            }
        `,
        fragmentShader: `
            varying vec2 vUv;
            uniform sampler2D tDiffuse;
            void main() {
                gl_FragColor = texture2D(tDiffuse, vUv);
            }
        `
    });

    const geometry = t.PlaneBufferGeometry ? new t.PlaneBufferGeometry(width, height) : new t.PlaneGeometry(width, height);
    const quad = new t.Mesh(geometry, material);
    quad.position.z = -100;
    sceneRTT.add(quad);

    const renderer = new t.WebGLRenderer({ alpha: true, preserveDrawingBuffer: true });
    renderer.setPixelRatio(window.devicePixelRatio || 1);
    renderer.setSize(width, height);
    renderer.autoClear = false;

    const holder = document.createElement('div');
    holder.style.cssText = 'position:fixed;left:-99999px;top:-99999px;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none;';
    holder.appendChild(renderer.domElement);
    document.body.appendChild(holder);

    renderer.clear();
    renderer.render(sceneRTT, cameraRTT, rtTexture, true);

    const read = new Uint8Array(width * height * 4);
    renderer.readRenderTargetPixels(rtTexture, 0, 0, width, height, read);

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    ctx.putImageData(new ImageData(new Uint8ClampedArray(read.buffer), width, height), 0, 0);

    const encoding = String(options.encoding || 'png').toLowerCase();
    const mime = encoding === 'jpg' || encoding === 'jpeg' ? 'image/jpeg' : encoding === 'webp' ? 'image/webp' : 'image/png';
    const quality = Number(options.quality || 0.95);
    const dataUrl = canvas.toDataURL(mime, quality);

    try { renderer.dispose && renderer.dispose(); } catch (e) {}
    try { rtTexture.dispose && rtTexture.dispose(); } catch (e) {}
    try { material.dispose && material.dispose(); } catch (e) {}
    try { geometry.dispose && geometry.dispose(); } catch (e) {}
    holder.remove();

    return dataUrl;
}

async function captureAndDownloadInternal(data = {}) {
    try {
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        const image = await captureGameViewInternal(data);
        const ok = downloadImage(image, data.filename || `driftzone_vehicle_${Date.now()}.png`);
        nuiResult(ok, ok ? '' : 'download failed');
    } catch (e) {
        console.error('[driftzone_vehicless] internal screenshot failed', e);
        hint.textContent = 'Screenshot intern nu este suportat pe build-ul tau NUI.';
        nuiResult(false, e && e.message ? e.message : e);
    }
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
    hint.textContent = 'Screenshot integrat în resource. Nu mai ai nevoie de screenshot-basic.';
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
        const model = String(data.model || 'Vehicle');
        modelName.textContent = model.toUpperCase();
        modelInput.value = model.toLowerCase();
        show();
        setTimeout(() => modelInput.select(), 120);
    }

    if (data.action === 'state') updateState(data);

    if (data.action === 'prepareShot') root.classList.add('shooting');

    if (data.action === 'captureInternal') captureAndDownloadInternal(data);

    if (data.action === 'downloadScreenshot') downloadImage(data.image, data.filename);

    if (data.action === 'shotDone') {
        root.classList.remove('shooting');
        shotBtn.disabled = false;
        shotBtn.textContent = 'SCREENSHOT';
    }

    if (data.action === 'close') hide();
});

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'Backspace') closePanel();
    if (e.key === 'Enter' && document.activeElement === modelInput) loadModel();
    if (e.key === 'ArrowLeft') control('rotate_left');
    if (e.key === 'ArrowRight') control('rotate_right');
    if (e.key === 'ArrowUp') control('fov_up');
    if (e.key === 'ArrowDown') control('fov_down');
});
