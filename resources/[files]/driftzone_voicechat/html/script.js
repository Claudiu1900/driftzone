'use strict';

const volumeBox = document.getElementById('volumeBox');
const volumeSlider = document.getElementById('volumeSlider');
const volumeText = document.getElementById('volumeText');
const micBox = document.getElementById('micBox');
const micIcon = document.getElementById('micIcon');

let lastVolume = Number(localStorage.getItem('driftzone_voice_volume') || 100);
let talking = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function clampVolume(value) {
    value = Number(value || 0);

    if (value < 0) return 0;
    if (value > 100) return 100;

    return Math.round(value);
}

function setMainColor(color) {
    if (color) {
        document.documentElement.style.setProperty('--main', color);
    }
}

function setVolumeUi(value, saveLocal = true) {
    value = clampVolume(value);

    lastVolume = value;
    volumeSlider.value = value;
    volumeText.textContent = value;
    volumeSlider.style.setProperty('--progress', `${value}%`);

    if (saveLocal) {
        localStorage.setItem('driftzone_voice_volume', String(value));
    }
}

function setTalkingUi(state) {
    talking = state === true;

    micBox.classList.toggle('talking', talking);
    micBox.classList.toggle('muted', !talking);
    micIcon.src = talking ? 'images/mic_on.svg' : 'images/mic_off.svg';
}

volumeSlider.addEventListener('input', () => {
    const value = clampVolume(volumeSlider.value);
    setVolumeUi(value, true);
    nui('setVolume', { volume: value });
});

volumeSlider.addEventListener('change', () => {
    const value = clampVolume(volumeSlider.value);
    setVolumeUi(value, true);
    nui('setVolume', { volume: value });
    nui('closeFocus');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        nui('closeFocus');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.mainColor) setMainColor(data.mainColor);

    if (data.action === 'setup') {
        const saved = localStorage.getItem('driftzone_voice_volume');
        const volume = saved !== null ? Number(saved) : Number(data.volume || 100);

        setVolumeUi(volume, true);
        setTalkingUi(data.talking === true);

        // Trimite inapoi volumul salvat din localStorage catre Lua, ca slider-ul sa functioneze dupa restart.
        nui('setVolume', { volume: clampVolume(volume) });
    }

    if (data.action === 'state') {
        setTalkingUi(data.talking === true);

        if (typeof data.volume !== 'undefined') {
            const saved = localStorage.getItem('driftzone_voice_volume');
            setVolumeUi(saved !== null ? Number(saved) : data.volume, true);
        }
    }

    if (data.action === 'volume') {
        setVolumeUi(data.volume || lastVolume || 100, true);
    }
});

setVolumeUi(lastVolume, true);
setTalkingUi(false);

setTimeout(() => nui('ready'), 80);
