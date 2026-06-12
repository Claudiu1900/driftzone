'use strict';

const results = {};
let correlationId = 0;

RegisterNuiCallbackType('screenshot_created');

function registerCorrelation(cb) {
    const id = String(correlationId++);
    results[id] = { cb };
    return id;
}

on('__cfx_nui:screenshot_created', (body, cb) => {
    if (typeof cb === 'function') cb(true);

    if (body && body.id !== undefined && results[body.id]) {
        const fn = results[body.id].cb;
        delete results[body.id];
        try { fn(body.data || ''); } catch (e) { console.log('[driftzone_vehicless] screenshot callback error', e); }
    }
});

exports('requestScreenshot', (options, cb) => {
    const realOptions = (typeof cb === 'function') ? (options || {}) : { encoding: 'png' };
    const realCb = (typeof cb === 'function') ? cb : options;

    if (typeof realCb !== 'function') return;

    realOptions.encoding = realOptions.encoding || 'png';
    realOptions.quality = realOptions.quality || 0.95;
    realOptions.resultURL = null;
    realOptions.targetField = null;
    realOptions.targetURL = `http://${GetCurrentResourceName()}/screenshot_created`;
    realOptions.correlation = registerCorrelation(realCb);

    SendNuiMessage(JSON.stringify({ request: realOptions }));
});
