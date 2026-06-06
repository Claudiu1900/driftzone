'use strict';

const volumeBox = document.getElementById('volumeBox');
const volumeSlider = document.getElementById('volumeSlider');
const volumeText = document.getElementById('volumeText');
const micBox = document.getElementById('micBox');
const micIcon = document.getElementById('micIcon');
const focusHint = document.getElementById('focusHint');

const savedRaw = localStorage.getItem('driftzone_voice_volume');

let lastVolume = savedRaw === null ? 100 : clampVolume(Number(savedRaw));
let talking = false;
let hasFocus = false;
let volumeVisible = true;
let micVisible = true;
let sendTimer = null;
let pendingVolume = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function clampVolume(value) {
    value = Number(value);

    if (!Number.isFinite(value)) return 100;
    if (value < 0) return 0;
    if (value > 100) return 100;

    return Math.round(value);
}

function queueSendVolume(value) {
    pendingVolume = clampVolume(value);

    if (sendTimer) return;

    sendTimer = setTimeout(() => {
        const valueToSend = pendingVolume;
        pendingVolume = null;
        sendTimer = null;
        nui('setVolume', { volume: valueToSend });
    }, 35);
}

function setMainColor(color) {
    if (color) {
        document.documentElement.style.setProperty('--main', color);
    }
}

function setVolumeUi(value, saveLocal = true) {
    value = clampVolume(value);

    lastVolume = value;
    volumeSlider.value = String(value);
    volumeText.textContent = String(value);
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

function setFocusUi(state) {
    hasFocus = state === true;

    volumeBox.classList.toggle('focused', hasFocus);
    focusHint.classList.toggle('hidden', !hasFocus);
}

function setVisibilityUi(showVolume, showMicIcon) {
    volumeVisible = showVolume !== false;
    micVisible = showMicIcon !== false;

    volumeBox.classList.toggle('hidden', !volumeVisible);
    micBox.classList.toggle('hidden', !micVisible);

    if (!volumeVisible) {
        setFocusUi(false);
    }
}

volumeSlider.addEventListener('input', () => {
    const value = clampVolume(volumeSlider.value);

    setVolumeUi(value, true);
    queueSendVolume(value);
});

volumeSlider.addEventListener('change', () => {
    const value = clampVolume(volumeSlider.value);

    setVolumeUi(value, true);
    nui('setVolume', { volume: value });
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' || event.code === 'Backquote' || event.key === '`') {
        nui('closeFocus');
        setFocusUi(false);
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.mainColor) setMainColor(data.mainColor);

    if (data.action === 'setup') {
        const saved = localStorage.getItem('driftzone_voice_volume');
        const volume = saved === null ? clampVolume(data.volume) : clampVolume(Number(saved));

        setVolumeUi(volume, true);
        setTalkingUi(data.talking === true);
        setVisibilityUi(data.showVolume !== false, data.showMicIcon !== false);
        setFocusUi(data.focus === true);

        nui('setVolume', { volume: value });
    }

    if (data.action === 'state') {
        setTalkingUi(data.talking === true);

        if (typeof data.showVolume !== 'undefined' || typeof data.showMicIcon !== 'undefined') {
            setVisibilityUi(data.showVolume !== false, data.showMicIcon !== false);
        }

        if (typeof data.volume !== 'undefined') {
            const saved = localStorage.getItem('driftzone_voice_volume');
            const volume = saved === null ? clampVolume(data.volume) : clampVolume(Number(saved));

            setVolumeUi(volume, true);
        }

        if (typeof data.focus !== 'undefined') {
            setFocusUi(data.focus === true);
        }
    }

    if (data.action === 'volume') {
        const volume = typeof data.volume === 'undefined' ? lastVolume : data.volume;

        setVolumeUi(volume, true);

        if (typeof data.focus !== 'undefined') {
            setFocusUi(data.focus === true);
        }
    }

    if (data.action === 'visibility') {
        setVisibilityUi(data.showVolume !== false, data.showMicIcon !== false);

        if (typeof data.focus !== 'undefined') {
            setFocusUi(data.focus === true);
        }

        if (typeof data.volume !== 'undefined') {
            setVolumeUi(data.volume, true);
        }
    }

    if (data.action === 'focus') {
        setFocusUi(data.focus === true);

        if (typeof data.volume !== 'undefined') {
            setVolumeUi(data.volume, true);
        }
    }
});

setVolumeUi(lastVolume, true);
setTalkingUi(false);
setVisibilityUi(true, true);
setFocusUi(false);

setTimeout(() => nui('ready'), 80);
