'use strict';

const root = document.getElementById('root');
const codeInput = document.getElementById('codeInput');
const redeemBtn = document.getElementById('redeemBtn');
const result = document.getElementById('result');

let locked = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function cleanCode(value) {
    return String(value || '').replace(/[^\w-]/g, '').slice(0, 64);
}

function showResult(success, message) {
    result.textContent = String(message || '');
    result.classList.remove('hidden', 'success', 'error');
    result.classList.add(success ? 'success' : 'error');
}

function clearResult() {
    result.textContent = '';
    result.classList.add('hidden');
    result.classList.remove('success', 'error');
}

function closeUi() {
    root.classList.add('hidden');
    nui('close');
}

function redeemCode() {
    if (locked) return;

    const code = cleanCode(codeInput.value);

    if (!code) {
        showResult(false, 'Scrie un cod valid.');
        return;
    }

    locked = true;
    redeemBtn.classList.add('locked');
    redeemBtn.textContent = 'CHECKING...';

    nui('redeem', { code });

    setTimeout(() => {
        locked = false;
        redeemBtn.classList.remove('locked');
        redeemBtn.textContent = 'REDEEM';
    }, 1600);
}

codeInput.addEventListener('input', () => {
    const clean = cleanCode(codeInput.value);
    if (codeInput.value !== clean) {
        codeInput.value = clean;
    }
});

codeInput.addEventListener('paste', (event) => {
    event.preventDefault();
});

codeInput.addEventListener('drop', (event) => {
    event.preventDefault();
});

codeInput.addEventListener('contextmenu', (event) => {
    event.preventDefault();
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closeUi();
        return;
    }

    if (event.key === 'Enter' && !root.classList.contains('hidden')) {
        redeemCode();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'show') {
        root.classList.remove('hidden');
        clearResult();
        codeInput.value = '';
        setTimeout(() => codeInput.focus(), 80);
    }

    if (data.action === 'hide') {
        root.classList.add('hidden');
    }

    if (data.action === 'result') {
        showResult(data.success === true, data.message || '');
        locked = false;
        redeemBtn.classList.remove('locked');
        redeemBtn.textContent = 'REDEEM';

        if (data.success === true) {
            codeInput.value = '';
        }
    }
});

window.closeUi = closeUi;
window.redeemCode = redeemCode;

setTimeout(() => nui('ready'), 80);
