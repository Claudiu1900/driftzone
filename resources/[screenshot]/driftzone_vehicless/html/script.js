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

async function nuiAsync(name, data = {}) {
    const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });

    try { return await response.json(); } catch (e) { return { ok: response.ok }; }
}

function show() { root.classList.remove('hidden'); }
function hide() { root.classList.add('hidden'); }
function control(action) { nui('control', { action }); }

function closePanel() {
    nui('close');
    hide();
}

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
    hint.textContent = 'Se face screenshot si se salveaza pe server...';
    nui('screenshot');

    setTimeout(() => {
        if (shotBtn.disabled) {
            shotBtn.disabled = false;
            shotBtn.textContent = 'SCREENSHOT';
            hint.textContent = 'Daca nu apare salvarea, verifica F8 si consola serverului.';
        }
    }, 30000);
}

function nuiResult(ok, error) {
    nui('shotResult', { ok: !!ok, error: error ? String(error) : '' });
}

function makeShader(gl, type, src) {
    const shader = gl.createShader(type);
    if (!shader) throw new Error('shader create failed');

    gl.shaderSource(shader, src);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        const log = gl.getShaderInfoLog(shader) || 'shader compile failed';
        gl.deleteShader(shader);
        throw new Error(log);
    }

    return shader;
}

function createGameTexture(gl) {
    const tex = gl.createTexture();
    if (!tex) throw new Error('texture create failed');

    const texPixels = new Uint8Array([0, 0, 255, 255]);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, texPixels);

    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);

    // Cfx game-view hook sequence. Fara THREE, fara webpack.
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    return tex;
}

function createProgram(gl) {
    const vertexShaderSrc = `
        attribute vec2 a_position;
        attribute vec2 a_texcoord;
        varying vec2 v_texcoord;
        void main() {
            gl_Position = vec4(a_position, 0.0, 1.0);
            v_texcoord = a_texcoord;
        }
    `;

    const fragmentShaderSrc = `
        precision mediump float;
        varying vec2 v_texcoord;
        uniform sampler2D external_texture;
        void main() {
            gl_FragColor = texture2D(external_texture, v_texcoord);
        }
    `;

    const vertexShader = makeShader(gl, gl.VERTEX_SHADER, vertexShaderSrc);
    const fragmentShader = makeShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSrc);
    const program = gl.createProgram();
    if (!program) throw new Error('program create failed');

    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        throw new Error(gl.getProgramInfoLog(program) || 'program link failed');
    }

    return program;
}

function bindBuffer(gl, location, data) {
    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(data), gl.STATIC_DRAW);
    gl.vertexAttribPointer(location, 2, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(location);
    return buffer;
}

async function nextFrame() {
    await new Promise(resolve => requestAnimationFrame(resolve));
}

function encodePixelsToDataUrl(pixels, width, height, encoding, quality) {
    // WebGL readPixels citeste de jos in sus; canvas 2D vrea de sus in jos.
    const flipped = new Uint8ClampedArray(width * height * 4);
    const rowSize = width * 4;

    for (let y = 0; y < height; y++) {
        const src = (height - 1 - y) * rowSize;
        const dst = y * rowSize;
        flipped.set(pixels.subarray(src, src + rowSize), dst);
    }

    const out = document.createElement('canvas');
    out.width = width;
    out.height = height;

    const ctx = out.getContext('2d');
    if (!ctx) throw new Error('Canvas 2D indisponibil');
    ctx.putImageData(new ImageData(flipped, width, height), 0, 0);

    const enc = String(encoding || 'png').toLowerCase();
    const mime = enc === 'jpg' || enc === 'jpeg' ? 'image/jpeg' : enc === 'webp' ? 'image/webp' : 'image/png';
    return out.toDataURL(mime, Number(quality || 0.95));
}

function isProbablyBlack(pixels) {
    // Daca aproape tot bufferul este 0, captura este neagra si nu o salvam fals ca succes.
    if (!pixels || pixels.length < 4000) return true;

    let nonBlack = 0;
    const step = Math.max(4, Math.floor(pixels.length / 12000) * 4);
    for (let i = 0; i < pixels.length; i += step) {
        const r = pixels[i] || 0;
        const g = pixels[i + 1] || 0;
        const b = pixels[i + 2] || 0;
        const a = pixels[i + 3] || 0;
        if (a > 0 && (r + g + b) > 15) nonBlack++;
        if (nonBlack > 40) return false;
    }

    return true;
}

async function captureGameView(options = {}) {
    const width = Math.max(1, window.innerWidth || 1280);
    const height = Math.max(1, window.innerHeight || 720);

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    canvas.style.cssText = 'position:fixed;left:0;top:0;width:100vw;height:100vh;opacity:0;pointer-events:none;z-index:-1;';
    document.body.appendChild(canvas);

    const gl = canvas.getContext('webgl', {
        antialias: false,
        depth: false,
        stencil: false,
        alpha: false,
        preserveDrawingBuffer: true,
        failIfMajorPerformanceCaveat: false
    });

    if (!gl) {
        canvas.remove();
        throw new Error('WebGL indisponibil in NUI');
    }

    let program;
    let vertexBuffer;
    let texBuffer;
    let texture;

    try {
        texture = createGameTexture(gl);
        program = createProgram(gl);
        gl.useProgram(program);

        const posLocation = gl.getAttribLocation(program, 'a_position');
        const texLocation = gl.getAttribLocation(program, 'a_texcoord');
        const samplerLocation = gl.getUniformLocation(program, 'external_texture');

        vertexBuffer = bindBuffer(gl, posLocation, [-1, -1, 1, -1, -1, 1, 1, 1]);
        texBuffer = bindBuffer(gl, texLocation, [0, 1, 1, 1, 0, 0, 1, 0]);

        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture);
        gl.uniform1i(samplerLocation, 0);
        gl.viewport(0, 0, width, height);

        // Lasam cateva frame-uri pentru ca texture hook-ul FiveM sa primeasca backbufferul real.
        for (let i = 0; i < 4; i++) {
            gl.clearColor(0, 0, 0, 1);
            gl.clear(gl.COLOR_BUFFER_BIT);
            gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
            gl.finish();
            await nextFrame();
        }

        gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
        gl.finish();

        const raw = new Uint8Array(width * height * 4);
        gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, raw);

        if (isProbablyBlack(raw)) {
            throw new Error('captura neagra - foloseste/pornește screenshot-basic sau update la artifacts');
        }

        const dataUrl = encodePixelsToDataUrl(new Uint8ClampedArray(raw.buffer), width, height, options.encoding || 'png', options.quality || 0.95);

        if (!dataUrl || dataUrl.length < 1000) {
            throw new Error('screenshot gol');
        }

        return dataUrl;
    } finally {
        try { if (vertexBuffer) gl.deleteBuffer(vertexBuffer); } catch (e) {}
        try { if (texBuffer) gl.deleteBuffer(texBuffer); } catch (e) {}
        try { if (texture) gl.deleteTexture(texture); } catch (e) {}
        try { if (program) gl.deleteProgram(program); } catch (e) {}
        canvas.remove();
    }
}

async function uploadScreenshotToServer(data, dataUrl) {
    const base64 = String(dataUrl || '').includes(',') ? String(dataUrl).split(',')[1] : String(dataUrl || '');
    if (!base64 || base64.length < 1000) throw new Error('imagine goala');

    const chunkSize = 14000;
    const total = Math.ceil(base64.length / chunkSize);
    const token = Number(data.token || Date.now());
    const filename = String(data.filename || `driftzone_vehicle_${Date.now()}.png`);

    hint.textContent = `Se trimite poza pe server: 0/${total}`;

    let response = await nuiAsync('shotUploadStart', {
        token,
        filename,
        total,
        size: base64.length,
        encoding: data.encoding || 'png'
    });
    if (!response || response.ok === false) throw new Error(response && response.error ? response.error : 'upload start failed');

    for (let i = 0; i < total; i++) {
        const chunk = base64.slice(i * chunkSize, (i + 1) * chunkSize);
        response = await nuiAsync('shotUploadChunk', { token, index: i + 1, total, chunk });
        if (!response || response.ok === false) throw new Error(response && response.error ? response.error : `upload chunk ${i + 1} failed`);
        if (i % 8 === 0 || i === total - 1) hint.textContent = `Se trimite poza pe server: ${i + 1}/${total}`;
    }

    response = await nuiAsync('shotUploadFinish', { token });
    if (!response || response.ok === false) throw new Error(response && response.error ? response.error : 'upload finish failed');

    hint.textContent = 'Poza a fost trimisa. Serverul o salveaza...';
}

async function captureAndUpload(data = {}) {
    try {
        await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        const image = await captureGameView(data);
        await uploadScreenshotToServer(data, image);
    } catch (e) {
        console.error('[driftzone_vehicless] screenshot/upload failed', e);
        hint.textContent = 'Screenshot/upload a esuat. Verifica F8.';
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
    hint.textContent = 'Screenshot-ul se salveaza pe server in folderul screenshots.';
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
    if (data.action === 'captureInternal') captureAndUpload(data);

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
