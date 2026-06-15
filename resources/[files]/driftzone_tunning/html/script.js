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
const wheelBack = document.getElementById('wheelBack');

let data = {};
let activeMainKey = null;
let activeCategory = null;
let cart = [];
let previewTimer = null;
let queuedPreview = null;
let wheelGroupOpen = false;

const classicColors = [
    ['Black', 0, '#050505'], ['White', 111, '#f2f2f2'], ['Red', 27, '#c90000'],
    ['Blue', 64, '#0055ff'], ['Yellow', 88, '#ffd500'], ['Green', 55, '#00a651'],
    ['Orange', 38, '#ff7b00'], ['Purple', 71, '#7d00ff'], ['Pink', 135, '#ff4ccf'],
    ['Cyan', 140, '#04c7f7'], ['Chrome', 120, '#c7c7c7'], ['Gold', 99, '#d4af37']
];

const windowTints = [
    ['None', 0], ['Pure Black', 1], ['Dark Smoke', 2], ['Light Smoke', 3],
    ['Stock', 4], ['Limo', 5], ['Green', 6]
];

const xenonColors = [
    ['White', 0, '#ffffff'], ['Blue', 1, '#006eff'], ['Electric Blue', 2, '#00aaff'],
    ['Mint Green', 3, '#00ff9d'], ['Lime', 4, '#bfff00'], ['Yellow', 5, '#ffe600'],
    ['Golden', 6, '#ffbf00'], ['Orange', 7, '#ff7300'], ['Red', 8, '#ff0000'],
    ['Pony Pink', 9, '#ff66cc'], ['Hot Pink', 10, '#ff1493'], ['Purple', 11, '#8a2be2']
];

const quickColors = [
    ['White', '#ffffff'], ['Black', '#050505'], ['Red', '#ff0000'], ['Blue', '#006eff'],
    ['Cyan', '#04c7f7'], ['Green', '#00ff6a'], ['Yellow', '#ffe600'], ['Orange', '#ff7300'],
    ['Purple', '#8a2be2'], ['Pink', '#ff1493']
];

const iconMap = {
    colors: 'colors',
    'gradient preview': 'gradient',
    body: 'body',
    performance: 'performance',
    wheels: 'wheels',
    interior: 'interior',
    visual: 'visual',
    lights: 'lights',
    'engine bay': 'engine',
    extra: 'extras'
};

function nui(name, payload = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload)
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

function money(value) {
    const n = Number(value || 0);
    try { return '$' + n.toLocaleString('ro-RO'); } catch (e) { return '$' + n; }
}

function getCategories() {
    return Array.isArray(data.categories) ? data.categories : [];
}

function getWheelCategories() {
    return getCategories().filter((cat) => cat && cat.type === 'wheel' && Number(cat.wheelType) !== 10 && cat.key !== 'wheels_openwheel');
}

function getCategory(key) {
    return getCategories().find((cat) => cat && cat.key === key) || null;
}

function getMainCategories() {
    const main = getCategories().filter((cat) => cat && cat.type !== 'wheel');
    const wheelCats = getWheelCategories();

    if (wheelCats.length > 0) {
        const count = wheelCats.reduce((sum, cat) => sum + Number(cat.count || 0), 0);
        main.push({ key: '__wheels', label: 'Wheels', type: 'wheelGroup', group: 'Wheels', count, children: wheelCats });
    }

    return main;
}

function getIcon(cat) {
    const group = String((cat && cat.group) || (cat && cat.type) || '').toLowerCase();
    return iconMap[group] || 'visual';
}

function getPrice(key) {
    if (key === '__wheels') return 0;
    const base = Number(data.vehiclePrice || 0);
    const percent = Number((data.pricePercent || {})[key] || 1);
    return Math.max(1, Math.ceil(base * percent / 100));
}

function optionPriceText(cat) {
    if (!cat || cat.previewOnly || cat.type === 'gradientPreview') return 'PREVIEW';
    return money(getPrice(cat.key));
}

function open(payload) {
    data = payload || {};
    cart = [];
    activeMainKey = null;
    activeCategory = null;
    wheelGroupOpen = false;
    root.classList.remove('hidden');
    root.classList.remove('camera-mode');

    const plate = data.vehiclePlate ? ` • ${data.vehiclePlate}` : '';
    vehicleInfo.textContent = `${data.vehicleName || 'Vehicle'}${plate}`;
    moneyEl.textContent = money(data.playerMoney || data.cash || 0);

    renderCategories();
    renderCart();
    wheelBack.classList.add('hidden');
    selectedTitle.textContent = 'Selectează o categorie';
    optionsEl.innerHTML = '<div class="empty-state">Alege o categorie din stânga.</div>';
}

function close() {
    root.classList.add('hidden');
    data = {};
    cart = [];
    activeMainKey = null;
    activeCategory = null;
    wheelGroupOpen = false;
    optionsEl.innerHTML = '';
}

function renderCategories() {
    const cats = getMainCategories();

    categoriesEl.innerHTML = cats.map((cat) => {
        const active = activeMainKey === cat.key;
        const meta = cat.type === 'wheelGroup'
            ? `${getWheelCategories().length} categorii`
            : (cat.type === 'mod' ? `${cat.count || 0} opțiuni` : String(cat.group || cat.type || 'Tuning'));
        const price = cat.type === 'wheelGroup' ? 'Wheels' : optionPriceText(cat);

        return `
            <button class="cat ${active ? 'active' : ''}" type="button" data-category="${escapeHtml(cat.key)}">
                <img src="icons/${getIcon(cat)}.svg" draggable="false" alt="">
                <div class="cat-text">
                    <b>${escapeHtml(cat.label)}</b>
                    <span>${escapeHtml(meta)}</span>
                </div>
                <small>${escapeHtml(price)}</small>
            </button>
        `;
    }).join('');
}

function selectCategory(key) {
    if (key === '__wheels') {
        activeMainKey = '__wheels';
        activeCategory = { key: '__wheels', label: 'Wheels', type: 'wheelGroup', group: 'Wheels' };
        wheelGroupOpen = true;
        renderCategories();
        renderWheelCategories();
        return;
    }

    activeMainKey = key;
    activeCategory = getCategory(key);
    wheelGroupOpen = false;
    renderCategories();
    renderOptions();
}

function selectWheelCategory(key) {
    activeMainKey = '__wheels';
    activeCategory = getCategory(key);
    wheelGroupOpen = false;
    renderCategories();
    renderOptions();
}

function renderOptions() {
    if (!activeCategory) return;

    wheelBack.classList.toggle('hidden', activeMainKey !== '__wheels' || activeCategory.key === '__wheels');
    selectedTitle.textContent = `${activeCategory.label} • ${optionPriceText(activeCategory)}`;

    if (activeCategory.type === 'color') renderColorOptions();
    else if (activeCategory.type === 'classicColor') renderClassicColorOptions();
    else if (activeCategory.type === 'windowTint') renderWindowTintOptions();
    else if (activeCategory.type === 'xenonColor') renderXenonOptions();
    else if (activeCategory.type === 'toggle' || activeCategory.type === 'extra') renderToggleOptions();
    else if (activeCategory.type === 'gradientPreview') renderGradientPreviewOptions();
    else renderModOptions();
}

function renderWheelCategories() {
    wheelBack.classList.add('hidden');
    selectedTitle.textContent = 'Wheels • alege tipul de jante';
    const wheelCats = getWheelCategories();

    if (wheelCats.length <= 0) {
        optionsEl.innerHTML = '<div class="empty-state">Mașina nu are categorii de roți disponibile.</div>';
        return;
    }

    optionsEl.innerHTML = wheelCats.map((cat) => `
        <button class="option wheel-type" type="button" data-wheel-category="${escapeHtml(cat.key)}">
            <img src="icons/wheels.svg" draggable="false" alt="">
            <b>${escapeHtml(cat.label.replace(/^Wheels\s*/i, ''))}</b>
            <span>${Number(cat.count || 0)} opțiuni • ${money(getPrice(cat.key))}</span>
        </button>
    `).join('');
}

function sendPreview(key, value, variantLabel) {
    nui('preview', { key, value, variantLabel });
}

function schedulePreview(key, value, variantLabel) {
    queuedPreview = { key, value, variantLabel };
    if (previewTimer) return;

    previewTimer = setTimeout(() => {
        const payload = queuedPreview;
        queuedPreview = null;
        previewTimer = null;
        if (payload) sendPreview(payload.key, payload.value, payload.variantLabel);
    }, 25);
}

function preview(key, value) {
    const cat = getCategory(key) || activeCategory;
    if (!cat) return;

    const variantLabel = valueToText(key, value);

    if (cat.previewOnly === true || cat.type === 'gradientPreview') {
        schedulePreview(key, value, variantLabel);
        return;
    }

    const existing = cart.find((item) => item.key === key);
    if (existing) {
        existing.value = value;
        existing.price = getPrice(key);
        existing.variantLabel = variantLabel;
    } else {
        cart.push({ key, label: cat.label, value, variantLabel, price: getPrice(key) });
    }

    renderCart();
    schedulePreview(key, value, variantLabel);
}

function renderColorOptions() {
    const quick = quickColors.map(([name, hex]) => `
        <button class="option color-swatch" type="button" data-preview-key="${activeCategory.key}" data-value-kind="string" data-value="${hex}">
            <i style="background:${hex}"></i><b>${escapeHtml(name)}</b>
        </button>
    `).join('');

    optionsEl.innerHTML = `
        <div class="option custom-color">
            <input id="customPicker" type="color" value="#04c7f7">
            <input id="customHex" type="text" value="#04c7f7" maxlength="7">
            <button id="customApply" type="button">APPLY</button>
        </div>
        ${quick}
    `;

    setTimeout(() => {
        const picker = document.getElementById('customPicker');
        const hex = document.getElementById('customHex');
        const apply = document.getElementById('customApply');
        if (!picker || !hex || !apply) return;

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
        apply.addEventListener('click', () => preview(activeCategory.key, hex.value || '#04c7f7'));
    }, 20);
}

function renderClassicColorOptions() {
    optionsEl.innerHTML = classicColors.map(([name, id, hex]) => `
        <button class="option color-swatch wide" type="button" data-preview-key="${activeCategory.key}" data-value-kind="number" data-value="${id}">
            <i style="background:${hex}"></i><b>${escapeHtml(name)}</b><span>${money(getPrice(activeCategory.key))}</span>
        </button>
    `).join('');
}

function renderWindowTintOptions() {
    optionsEl.innerHTML = windowTints.map(([name, id]) => `
        <button class="option" type="button" data-preview-key="${activeCategory.key}" data-value-kind="number" data-value="${id}">
            <b>${escapeHtml(name)}</b><span>${money(getPrice(activeCategory.key))}</span>
        </button>
    `).join('');
}

function renderXenonOptions() {
    optionsEl.innerHTML = xenonColors.map(([name, id, hex]) => `
        <button class="option color-swatch wide" type="button" data-preview-key="${activeCategory.key}" data-value-kind="number" data-value="${id}">
            <i style="background:${hex}"></i><b>${escapeHtml(name)}</b><span>${money(getPrice(activeCategory.key))}</span>
        </button>
    `).join('');
}

function renderToggleOptions() {
    optionsEl.innerHTML = `
        <button class="option" type="button" data-preview-key="${activeCategory.key}" data-value-kind="boolean" data-value="true">
            <b>Enabled</b><span>${money(getPrice(activeCategory.key))}</span>
        </button>
        <button class="option" type="button" data-preview-key="${activeCategory.key}" data-value-kind="boolean" data-value="false">
            <b>Disabled</b><span>${money(getPrice(activeCategory.key))}</span>
        </button>
    `;
}

function renderGradientPreviewOptions() {
    const opts = Array.isArray(activeCategory.options) ? activeCategory.options : [];
    if (opts.length <= 0) {
        optionsEl.innerHTML = '<div class="empty-state">Nu există gradient preview pentru mașina asta.</div>';
        return;
    }

    optionsEl.innerHTML = opts.map((item) => `
        <button class="option gradient-option" type="button" data-preview-key="${activeCategory.key}" data-value-kind="number" data-value="${Number(item.value || item.id || 0)}">
            <img src="icons/gradient.svg" draggable="false" alt="">
            <b>${escapeHtml(item.label || ('Gradient ' + (item.value || item.id || '')))}</b>
            <span>Preview only</span>
        </button>
    `).join('');
}

function renderModOptions() {
    const opts = Array.isArray(activeCategory.options) ? activeCategory.options : [];
    if (opts.length > 0) {
        optionsEl.innerHTML = opts.map((item) => `
            <button class="option" type="button" data-preview-key="${activeCategory.key}" data-value-kind="number" data-value="${Number(item.value)}">
                <b>${escapeHtml(item.label || valueToText(activeCategory.key, item.value))}</b>
                <span>${money(getPrice(activeCategory.key))}</span>
            </button>
        `).join('');
        return;
    }

    const count = Number(activeCategory.count || 0);
    let html = `
        <button class="option" type="button" data-preview-key="${activeCategory.key}" data-value-kind="number" data-value="-1">
            <b>Stock</b><span>${money(getPrice(activeCategory.key))}</span>
        </button>
    `;

    for (let i = 0; i < count; i++) {
        html += `
            <button class="option" type="button" data-preview-key="${activeCategory.key}" data-value-kind="number" data-value="${i}">
                <b>${escapeHtml(activeCategory.label)} ${i + 1}</b><span>${money(getPrice(activeCategory.key))}</span>
            </button>
        `;
    }
    optionsEl.innerHTML = html;
}

function readValue(el) {
    const kind = el.dataset.valueKind || 'number';
    const raw = el.dataset.value;
    if (kind === 'boolean') return raw === 'true';
    if (kind === 'string') return String(raw || '');
    return Number(raw);
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
    if (cat.type === 'gradientPreview') {
        const opts = Array.isArray(cat.options) ? cat.options : [];
        const found = opts.find((item) => Number(item.value || item.id || 0) === Number(value));
        return found ? (found.label || ('Gradient ' + value)) : ('Gradient ' + value);
    }
    if (cat.type === 'mod' || cat.type === 'wheel') {
        const opts = Array.isArray(cat.options) ? cat.options : [];
        const found = opts.find((item) => Number(item.value) === Number(value));
        if (found) return found.label || String(value);
        return Number(value) === -1 ? 'Stock' : `${cat.label} ${Number(value) + 1}`;
    }
    return String(value);
}

function setCart(items) {
    if (!Array.isArray(items)) return;
    cart = items.map((item) => ({ ...item, variantLabel: item.variantLabel || valueToText(item.key, item.value) }));
    renderCart();
}

function removeCartItem(key) {
    key = String(key || '');
    cart = cart.filter((item) => item.key !== key);
    renderCart();
    nui('remove', { key });
}

function renderCart() {
    cartCount.textContent = `${cart.length} item${cart.length === 1 ? '' : 'e'}`;
    const total = cart.reduce((sum, item) => sum + Number(item.price || 0), 0);
    totalPrice.textContent = money(total);

    if (cart.length === 0) {
        cartItems.innerHTML = `
            <div class="cart-empty">
                <b>Nicio modificare</b>
                <span>Selectează tuning-uri din meniu.</span>
            </div>
        `;
        return;
    }

    cartItems.innerHTML = cart.map((item) => `
        <div class="cart-item">
            <div>
                <b>${escapeHtml(item.label)}</b>
                <small>${escapeHtml(item.variantLabel || valueToText(item.key, item.value))}</small>
                <span>${money(item.price)}</span>
            </div>
            <button class="cart-remove" type="button" data-remove="${escapeHtml(item.key)}">×</button>
        </div>
    `).join('');
}

function pay() { nui('buy'); }
function closeMenu() { nui('close'); }

categoriesEl.addEventListener('click', (event) => {
    const el = event.target.closest('[data-category]');
    if (!el) return;
    selectCategory(el.dataset.category);
});

optionsEl.addEventListener('click', (event) => {
    const wheel = event.target.closest('[data-wheel-category]');
    if (wheel) {
        selectWheelCategory(wheel.dataset.wheelCategory);
        return;
    }

    const opt = event.target.closest('[data-preview-key]');
    if (!opt) return;
    preview(opt.dataset.previewKey, readValue(opt));
});

cartItems.addEventListener('click', (event) => {
    const el = event.target.closest('[data-remove]');
    if (!el) return;
    removeCartItem(el.dataset.remove);
});

wheelBack.addEventListener('click', () => selectCategory('__wheels'));

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') nui('close');
    if (event.key === '`' || event.code === 'Backquote') nui('toggleCamera');
});

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') open(msg.data || {});
    if (msg.action === 'close') close();
    if (msg.action === 'cart') setCart(msg.items || []);
    if (msg.action === 'camera') root.classList.toggle('camera-mode', msg.enabled === true);
});

window.driftTunning = { open, close, setCart };
setTimeout(() => nui('ready'), 50);
