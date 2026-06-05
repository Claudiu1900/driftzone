'use strict';

const root = document.getElementById('speedometer');
const speedValue = document.getElementById('speedValue');
const gearValue = document.getElementById('gearValue');
const speedArc = document.getElementById('speedArc');

const ARC_LENGTH = 289;
const MAX_SPEED = 320;

let targetSpeed = 0;
let renderedSpeed = 0;
let targetRpm = 0;
let renderedRpm = 0;
let currentGear = 'N';
let raf = null;
let visible = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function bump(el) {
    el.classList.remove('bump');
    void el.offsetWidth;
    el.classList.add('bump');

    setTimeout(() => el.classList.remove('bump'), 150);
}

function setArc(progress) {
    progress = clamp(progress, 0, 1);
    speedArc.style.strokeDashoffset = String(ARC_LENGTH - (ARC_LENGTH * progress));
}

function animate() {
    const speedDiff = targetSpeed - renderedSpeed;

    if (Math.abs(speedDiff) < 0.2) {
        renderedSpeed = targetSpeed;
    } else {
        renderedSpeed += speedDiff * 0.20;
    }

    const rpmDiff = targetRpm - renderedRpm;

    if (Math.abs(rpmDiff) < 0.004) {
        renderedRpm = targetRpm;
    } else {
        renderedRpm += rpmDiff * 0.22;
    }

    const shown = Math.round(renderedSpeed);
    speedValue.textContent = String(shown);

    // Arc-ul combina viteza + rpm ca sa semene cu turometrul din poza,
    // dar viteza ramane numarul principal.
    const speedProgress = clamp(shown / MAX_SPEED, 0, 1);
    const arcProgress = clamp((speedProgress * 0.72) + (renderedRpm * 0.28), 0, 1);
    setArc(arcProgress);

    root.classList.toggle('hot', arcProgress >= 0.82);

    raf = requestAnimationFrame(animate);
}

function show() {
    if (visible) return;

    visible = true;
    root.classList.remove('hidden');

    if (!raf) {
        raf = requestAnimationFrame(animate);
    }
}

function hide() {
    visible = false;
    root.classList.add('hidden');

    targetSpeed = 0;
    renderedSpeed = 0;
    targetRpm = 0;
    renderedRpm = 0;
    currentGear = 'N';

    speedValue.textContent = '0';
    gearValue.textContent = 'N';
    setArc(0);
    root.classList.remove('hot');

    if (raf) {
        cancelAnimationFrame(raf);
        raf = null;
    }
}

function update(speed, gear, rpm) {
    const nextSpeed = clamp(Number(speed || 0), 0, 999);
    const nextGear = String(gear || 'N');
    const nextRpm = clamp(Number(rpm || 0), 0, 1);

    if (Math.abs(nextSpeed - targetSpeed) >= 7) {
        bump(speedValue);
    }

    targetSpeed = nextSpeed;
    targetRpm = nextRpm;

    if (nextGear !== currentGear) {
        currentGear = nextGear;
        gearValue.textContent = currentGear;
        bump(gearValue);
    }
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'show') {
        show();
    }

    if (data.action === 'hide') {
        hide();
    }

    if (data.action === 'update') {
        update(data.speed, data.gear, data.rpm);
    }
});

hide();

setTimeout(() => nui('ready'), 80);
