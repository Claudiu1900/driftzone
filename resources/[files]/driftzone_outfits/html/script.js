const root = document.getElementById('root');
const outfitsGrid = document.getElementById('outfitsGrid');
const emptyState = document.getElementById('emptyState');

let outfits = [];
let cooldownUntil = 0;
let cooldownTimer = null;
let lastCooldownText = '';

const FALLBACK_IMAGE = 'https://i.imgur.com/8QfQZQp.png';

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function getImage(value) {
    const image = String(value || '').trim();
    return image.length > 5 ? image : FALLBACK_IMAGE;
}

function isCooldown() {
    return Number(cooldownUntil || 0) > Date.now();
}

function updateButtons() {
    const onCooldown = isCooldown();
    const seconds = Math.max(0, Math.ceil((cooldownUntil - Date.now()) / 1000));
    const nextText = onCooldown ? `COOLDOWN ${seconds}s` : 'WEAR';

    if (lastCooldownText === nextText) return;

    lastCooldownText = nextText;

    document.querySelectorAll('.wear-btn').forEach((button) => {
        button.classList.toggle('disabled', onCooldown);
        button.disabled = onCooldown;
        button.textContent = nextText;
    });
}

function startCooldownTimer() {
    stopCooldownTimer();

    if (isCooldown()) {
        cooldownTimer = setInterval(updateButtons, 500);
    }

    updateButtons();
}

function stopCooldownTimer() {
    if (!cooldownTimer) return;

    clearInterval(cooldownTimer);
    cooldownTimer = null;
}

function render() {
    if (!Array.isArray(outfits) || outfits.length === 0) {
        outfitsGrid.innerHTML = '';
        emptyState.classList.remove('hidden');
        return;
    }

    emptyState.classList.add('hidden');

    const html = [];

    for (let i = 0; i < outfits.length; i++) {
        const outfit = outfits[i];
        const id = Number(outfit.id || 0);
        const name = escapeHtml(outfit.name || 'Outfit');
        const image = escapeHtml(getImage(outfit.image));

        html.push(`
            <div class="outfit-card">
                <div class="image-wrap">
                    <img class="outfit-image" src="${image}" onerror="this.src='${FALLBACK_IMAGE}'" loading="lazy">
                    <div class="image-overlay"></div>
                </div>

                <div class="outfit-body">
                    <div class="outfit-name">${name}</div>
                    <div class="outfit-sub">Mask • Hat • Jacket • Torso • Top • Pants • Shoes • Insignia • Glasses</div>
                    <button class="wear-btn" type="button" onclick="wearOutfit(${id})">WEAR</button>
                </div>
            </div>
        `);
    }

    outfitsGrid.innerHTML = html.join('');
    lastCooldownText = '';
    updateButtons();
}

function open(payload) {
    const data = payload || {};

    outfits = Array.isArray(data.outfits) ? data.outfits : [];
    cooldownUntil = Number(data.cooldownUntil || cooldownUntil || 0);

    root.classList.remove('hidden');
    render();
    startCooldownTimer();
}

function close() {
    root.classList.add('hidden');
    stopCooldownTimer();
}

function setCooldown(value) {
    cooldownUntil = Number(value || 0);
    startCooldownTimer();
}

function wearOutfit(id) {
    if (isCooldown()) {
        updateButtons();
        return;
    }

    const outfitId = Number(id || 0);

    if (outfitId <= 0) return;

    nui('wear', { id: outfitId });
}

function closeMenu() {
    nui('close');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') open(data.payload || {});
    if (data.action === 'close') close();
    if (data.action === 'setCooldown') setCooldown(data.cooldownUntil || 0);
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeMenu();
});

window.driftOutfits = {
    open,
    close,
    setCooldown
};

setTimeout(() => nui('ready'), 100);
