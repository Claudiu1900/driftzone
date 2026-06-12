'use strict';

const root = document.getElementById('root');
const vehicleInfo = document.getElementById('vehicleInfo');
const categoriesEl = document.getElementById('categories');
const optionsEl = document.getElementById('options');
const selectedTitle = document.getElementById('selectedTitle');
const moneyEl = document.getElementById('money');
const cartCount = document.getElementById('cartCount');
const cartItems = document.getElementById('cartItems');
const totalPrice = document.getElementById('totalPrice');

let data = {};
let activeCategory = null;
let cart = [];
let previewTimer = null;
let queuedPreview = null;

const classicColors = [
    ['Black', 0, '#050505'],
    ['White', 111, '#f2f2f2'],
    ['Red', 27, '#c90000'],
    ['Blue', 64, '#0055ff'],
    ['Yellow', 88, '#ffd500'],
    ['Green', 55, '#00a651'],
    ['Orange', 38, '#ff7b00'],
    ['Purple', 71, '#7d00ff'],
    ['Pink', 135, '#ff4ccf'],
    ['Cyan', 140, '#00d9ff'],
    ['Chrome', 120, '#c7c7c7'],
    ['Gold', 99, '#d4af37']
];

const windowTints = [
    ['None', 0],
    ['Pure Black', 1],
    ['Dark Smoke', 2],
    ['Light Smoke', 3],
    ['Stock', 4],
    ['Limo', 5],
    ['Green', 6]
];

const xenonColors = [
    ['White', 0, '#ffffff'],
    ['Blue', 1, '#006eff'],
    ['Electric Blue', 2, '#00aaff'],
    ['Mint Green', 3, '#00ff9d'],
    ['Lime', 4, '#bfff00'],
    ['Yellow', 5, '#ffe600'],
    ['Golden', 6, '#ffbf00'],
    ['Orange', 7, '#ff7300'],
    ['Red', 8, '#ff0000'],
    ['Pony Pink', 9, '#ff66cc'],
    ['Hot Pink', 10, '#ff1493'],
    ['Purple', 11, '#8a2be2']
];

const quickColors = [
    ['White', '#ffffff'],
    ['Black', '#050505'],
    ['Red', '#ff0000'],
    ['Blue', '#006eff'],
    ['Cyan', '#04c7f7'],
    ['Green', '#00ff6a'],
    ['Yellow', '#ffe600'],
    ['Orange', '#ff7300'],
    ['Purple', '#8a2be2'],
    ['Pink', '#ff1493']
];

function nui(name, payload = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload)
    }).catch(() => {});
}

function money(value) {
    const n = Number(value || 0);

    try {
        return '$' + n.toLocaleString('ro-RO');
    } catch (e) {
        return '$' + n;
    }
}

function escapeHtml(value) {
    return String(value || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function getCategory(key) {
    const categories = Array.isArray(data.categories) ? data.categories : [];
    return categories.find((cat) => cat.key === key) || null;
}

function getPrice(key) {
    const base = Number(data.vehiclePrice || 0);
    const percent = Number((data.pricePercent || {})[key] || 1);

    return Math.max(1, Math.ceil(base * percent / 100));
}

function open(payload) {
    data = payload || {};
    cart = [];
    activeCategory = null;

    root.classList.remove('hidden');
    vehicleInfo.textContent = `${data.vehicleName || 'Vehicle'} • ${data.vehiclePlate || ''}`;
    moneyEl.textContent = money(data.playerMoney || data.cash || 0);

    renderCategories();
    renderCart();

    selectedTitle.textContent = 'Selecteaza o categorie';
    optionsEl.innerHTML = '';
}

function close() {
    root.classList.add('hidden');
    data = {};
    cart = [];
    activeCategory = null;
}

function setCart(items) {
    if (!Array.isArray(items)) return;

    cart = items.map((item) => ({
        ...item,
        variantLabel: item.variantLabel || valueToText(item.key, item.value)
    }));

    renderCart();
}

function setCameraMode() {
    // Intentionat gol: camera libera nu mai afiseaza UI in partea de sus.
}

function renderCategories() {
    const categories = Array.isArray(data.categories) ? data.categories : [];

    categoriesEl.innerHTML = categories.map((cat) => `
        <div class="cat ${activeCategory && activeCategory.key === cat.key ? 'active' : ''}" onclick="selectCategory('${cat.key}')">
            <div>
                <div class="cat-name">${escapeHtml(cat.label)}</div>
                <div class="cat-meta">${(cat.type === 'mod' || cat.type === 'wheel') ? `${cat.count} optiuni` : cat.type}</div>
            </div>
            <div class="cat-meta">${money(getPrice(cat.key))}</div>
        </div>
    `).join('');
}

function selectCategory(key) {
    const categories = Array.isArray(data.categories) ? data.categories : [];
    activeCategory = categories.find((cat) => cat.key === key) || null;

    renderCategories();
    renderOptions();
}

function renderOptions() {
    if (!activeCategory) return;

    selectedTitle.textContent = `${activeCategory.label} • ${money(getPrice(activeCategory.key))}`;

    if (activeCategory.type === 'color') renderColorOptions();
    else if (activeCategory.type === 'classicColor') renderClassicColorOptions();
    else if (activeCategory.type === 'windowTint') renderWindowTintOptions();
    else if (activeCategory.type === 'xenonColor') renderXenonOptions();
    else if (activeCategory.type === 'toggle' || activeCategory.type === 'extra') renderToggleOptions();
    else renderModOptions();
}

function renderColorOptions() {
    const quick = quickColors.map(([name, hex]) => `
        <div class="option color-option" title="${escapeHtml(name)}" onclick="preview('${activeCategory.key}', '${hex}')">
            <div class="color-dot" style="background:${hex}"></div>
        </div>
    `).join('');

    optionsEl.innerHTML = `
        <div class="option custom-color">
            <input id="customPicker" type="color" value="#04c7f7">
            <input id="customHex" type="text" value="#04c7f7">
            <button onclick="applyCustomColor()">Apply</button>
        </div>
        ${quick}
    `;

    setTimeout(() => {
        const picker = document.getElementById('customPicker');
        const hex = document.getElementById('customHex');

        if (!picker || !hex) return;

        picker.addEventListener('input', () => {
            hex.value = picker.value;
            preview(activeCategory.key, picker.value);
        });

        hex.addEventListener('change', () => {
            if (/^#[0-9A-Fa-f]{6}$/.test(hex.value)) {
                picker.value = hex.value;
                preview(activeCategory.key, hex.value);
            }
        });
    }, 20);
}

function applyCustomColor() {
    const hex = document.getElementById('customHex');
    preview(activeCategory.key, hex ? hex.value : '#04c7f7');
}

function renderClassicColorOptions() {
    optionsEl.innerHTML = classicColors.map(([name, id, hex]) => `
        <div class="option color-option wide" onclick="preview('${activeCategory.key}', ${id})">
            <div class="color-dot" style="background:${hex}"></div>
            <span>${escapeHtml(name)}</span>
        </div>
    `).join('');
}

function renderWindowTintOptions() {
    optionsEl.innerHTML = windowTints.map(([name, id]) => `
        <div class="option" onclick="preview('${activeCategory.key}', ${id})">
            <b>${escapeHtml(name)}</b>
            <span>${money(getPrice(activeCategory.key))}</span>
        </div>
    `).join('');
}

function renderXenonOptions() {
    optionsEl.innerHTML = xenonColors.map(([name, id, hex]) => `
        <div class="option color-option wide" onclick="preview('${activeCategory.key}', ${id})">
            <div class="color-dot" style="background:${hex}"></div>
            <span>${escapeHtml(name)}</span>
        </div>
    `).join('');
}

function renderToggleOptions() {
    optionsEl.innerHTML = `
        <div class="option" onclick="preview('${activeCategory.key}', true)">
            <b>Enabled</b>
            <span>${money(getPrice(activeCategory.key))}</span>
        </div>
        <div class="option" onclick="preview('${activeCategory.key}', false)">
            <b>Disabled</b>
            <span>${money(getPrice(activeCategory.key))}</span>
        </div>
    `;
}

function renderModOptions() {
    const count = Number(activeCategory.count || 0);
    let html = `
        <div class="option" onclick="preview('${activeCategory.key}', -1)">
            <b>Stock</b>
            <span>${money(getPrice(activeCategory.key))}</span>
        </div>
    `;

    for (let i = 0; i < count; i++) {
        html += `
            <div class="option" onclick="preview('${activeCategory.key}', ${i})">
                <b>${escapeHtml(activeCategory.label)} ${i + 1}</b>
                <span>${money(getPrice(activeCategory.key))}</span>
            </div>
        `;
    }

    optionsEl.innerHTML = html;
}

function findNameById(list, value) {
    const found = list.find((item) => Number(item[1]) === Number(value));
    return found ? found[0] : String(value);
}

function valueToText(key, value) {
    const cat = getCategory(key) || activeCategory;

    if (!cat) return String(value);

    if (cat.type === 'color') {
        if (typeof value === 'string') return value.toUpperCase();
        if (value && typeof value === 'object') return `RGB(${value.r || 0}, ${value.g || 0}, ${value.b || 0})`;
        return 'Custom Color';
    }

    if (cat.type === 'classicColor') return findNameById(classicColors, value);
    if (cat.type === 'windowTint') return findNameById(windowTints, value);
    if (cat.type === 'xenonColor') return findNameById(xenonColors, value);
    if (cat.type === 'toggle' || cat.type === 'extra') return value === true ? 'Enabled' : 'Disabled';
    if (cat.type === 'mod' || cat.type === 'wheel') return Number(value) === -1 ? 'Stock' : `${cat.label} ${Number(value) + 1}`;

    return String(value);
}

function sendPreview(key, value, variantLabel) {
    nui('preview', {
        key,
        value,
        variantLabel
    });
}

function preview(key, value) {
    if (!activeCategory) return;

    const variantLabel = valueToText(key, value);
    const existing = cart.find((item) => item.key === key);

    if (existing) {
        existing.value = value;
        existing.price = getPrice(key);
        existing.variantLabel = variantLabel;
    } else {
        cart.push({
            key,
            label: activeCategory.label,
            value,
            variantLabel,
            price: getPrice(key)
        });
    }

    renderCart();

    queuedPreview = { key, value, variantLabel };

    if (previewTimer) return;

    previewTimer = setTimeout(() => {
        const payload = queuedPreview;
        queuedPreview = null;
        previewTimer = null;

        if (payload) {
            sendPreview(payload.key, payload.value, payload.variantLabel);
        }
    }, 25);
}

function removeCartItem(key) {
    key = String(key || '');

    cart = cart.filter((item) => item.key !== key);
    renderCart();

    nui('remove', { key });
}

function renderCart() {
    cartCount.textContent = `${cart.length} items`;

    const total = cart.reduce((sum, item) => sum + Number(item.price || 0), 0);
    totalPrice.textContent = money(total);

    if (cart.length === 0) {
        cartItems.innerHTML = `
            <div class="cart-empty">
                <b>Nicio modificare</b>
                <span>Selecteaza tuning-uri din lista.</span>
            </div>
        `;
        return;
    }

    cartItems.innerHTML = cart.map((item) => `
        <div class="cart-item">
            <div class="cart-item-main">
                <b>${escapeHtml(item.label)}</b>
                <small>${escapeHtml(item.variantLabel || valueToText(item.key, item.value))}</small>
                <span>${money(item.price)}</span>
            </div>
            <button class="cart-remove" onclick="removeCartItem('${escapeHtml(item.key)}')">×</button>
        </div>
    `).join('');
}

function pay() {
    nui('buy');
}

function closeMenu() {
    nui('close');
}

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') nui('close');
    if (event.key === '`' || event.code === 'Backquote') nui('toggleCamera');
});

window.addEventListener('message', (event) => {
    const msg = event.data || {};

    if (msg.action === 'open') open(msg.data || {});
    if (msg.action === 'close') close();
    if (msg.action === 'cart') setCart(msg.items || []);
    if (msg.action === 'camera') setCameraMode(msg.enabled === true);
});

window.driftTunning = {
    open,
    close,
    setCart
};

setTimeout(() => nui('ready'), 50);
