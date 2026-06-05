'use strict';

function nuiFetch(data) {
    try {
        fetch(`https://${GetParentResourceName()}/setCursor`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).catch(() => {});
    } catch (e) {}
}

setTimeout(() => nuiFetch({ show: true }), 300);

const cursor = document.getElementById('custom-cursor');
const circle = document.querySelector('.progress-ring__circle');
const text = document.getElementById('progressText');
const mini = document.getElementById('progressMini');
const bar = document.getElementById('loadingBarFill');
const music = document.getElementById('music');
const volumeSlider = document.getElementById('volumeSlider');
const volumePercent = document.getElementById('volumePercent');
const loadingStatus = document.getElementById('loadingStatus');
const tipText = document.getElementById('tipText');

const radius = 80;
const circumference = 2 * Math.PI * radius;

let lastPercent = 0;
let musicStarted = false;

const tips = [
    'Respecta ceilalti jucatori si condu curat pe zonele de drift.',
    'Foloseste masina potrivita pentru fiecare traseu si ajusteaza handling-ul.',
    'Pastreaza distanta in tandem drift si evita contactele inutile.',
    'Adminii pot verifica rapid situatiile daca raportezi corect problema.',
    'Exploreaza showroom-ul si testeaza masinile inainte sa cumperi.'
];

circle.style.strokeDasharray = circumference;
circle.style.strokeDashoffset = circumference;

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function setProgress(percent) {
    const safePercent = clamp(Math.floor(Number(percent) || 0), 0, 100);

    if (safePercent < lastPercent) return;

    lastPercent = safePercent;

    const offset = circumference - (safePercent / 100) * circumference;

    circle.style.strokeDashoffset = offset;
    text.innerText = `${safePercent}%`;
    mini.innerText = `${safePercent} / 100`;
    bar.style.width = `${safePercent}%`;

    if (safePercent < 20) {
        loadingStatus.innerText = 'Se conecteaza la server...';
    } else if (safePercent < 45) {
        loadingStatus.innerText = 'Se descarca resursele...';
    } else if (safePercent < 75) {
        loadingStatus.innerText = 'Se incarca interfata...';
    } else if (safePercent < 100) {
        loadingStatus.innerText = 'Aproape gata...';
    } else {
        loadingStatus.innerText = 'Intrare pe DriftZone...';
    }
}

function tryStartMusic() {
    if (!music || musicStarted) return;

    music.volume = Number(volumeSlider.value || 30) / 100;

    music.play()
        .then(() => {
            musicStarted = true;
        })
        .catch(() => {});
}

document.addEventListener('mousemove', (event) => {
    if (!cursor) return;

    cursor.style.left = `${event.clientX}px`;
    cursor.style.top = `${event.clientY}px`;
});

document.addEventListener('click', tryStartMusic);
document.addEventListener('keydown', tryStartMusic);

[300, 800, 1500, 2500, 4000].forEach((ms) => {
    setTimeout(tryStartMusic, ms);
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.eventName === 'loadProgress') {
        setProgress((Number(data.loadFraction) || 0) * 100);
    }

    if (data.type === 'loadProgress') {
        setProgress(Number(data.percent) || 0);
    }
});

music.volume = 0.3;
volumePercent.innerText = '30%';

volumeSlider.addEventListener('input', () => {
    const volume = Number(volumeSlider.value || 0);

    music.volume = volume / 100;
    volumePercent.innerText = `${volume}%`;
});

let tipIndex = 0;

setInterval(() => {
    tipIndex = (tipIndex + 1) % tips.length;
    tipText.innerText = tips[tipIndex];
}, 6500);

window.addEventListener('beforeunload', () => {
    nuiFetch({ show: false });
});

if (!window.invokeNative) {
    let fake = 0;

    const demo = setInterval(() => {
        fake += 1;
        setProgress(fake);

        if (fake >= 100) {
            clearInterval(demo);
        }
    }, 85);
}