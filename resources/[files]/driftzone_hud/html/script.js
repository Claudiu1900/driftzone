'use strict';

const root = document.getElementById('hudRoot');
const dateTimeValue = document.getElementById('dateTimeValue');
const timeValue = document.getElementById('timeValue');
const idValue = document.getElementById('idValue');
const onlineValue = document.getElementById('onlineValue');
const cashValue = document.getElementById('cashValue');
const logo = document.getElementById('logo');

let hudVisible = true;
let currentId = 0;
let currentOnline = 0;
let currentCash = 0;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function pad(value) {
    return String(value).padStart(2, '0');
}

function formatMoney(value) {
    const number = Number(value || 0);

    return '$' + number.toLocaleString('en-US');
}

function updateClock() {
    const date = new Date();

    const day = pad(date.getDate());
    const month = pad(date.getMonth() + 1);
    const year = date.getFullYear();
    const hour = pad(date.getHours());
    const minute = pad(date.getMinutes());

    dateTimeValue.textContent = `${day}/${month}/${year} ${hour}:${minute}`;
    timeValue.textContent = `${hour}:${minute}`;
}

function setVisible(state) {
    hudVisible = state === true;

    if (hudVisible) {
        root.classList.remove('hidden');
    } else {
        root.classList.add('hidden');
    }
}

function update(data) {
    const payload = data || {};

    if (payload.mainColor) {
        document.documentElement.style.setProperty('--main', payload.mainColor);
    }

    if (payload.logo) {
        logo.src = payload.logo;
    }

    currentId = Number(payload.id || 0);
    currentOnline = Number(payload.online || 0);
    currentCash = Number(payload.cash || 0);

    idValue.textContent = currentId > 0 ? `#${currentId}` : '#0';
    onlineValue.textContent = String(currentOnline);
    cashValue.textContent = formatMoney(currentCash);

    setVisible(payload.visible !== false);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'update') {
        update(data.data || {});
    }

    if (data.action === 'visible') {
        setVisible(data.visible === true);
    }
});

setInterval(updateClock, 1000);
updateClock();

setTimeout(() => {
    nui('ready');
}, 100);