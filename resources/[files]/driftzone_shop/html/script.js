'use strict';

const root = document.getElementById('root');
const coinValue = document.getElementById('coinValue');
const categoriesEl = document.getElementById('categories');
const productsEl = document.getElementById('products');
const categoryTitle = document.getElementById('categoryTitle');
const categorySubtitle = document.getElementById('categorySubtitle');

let shop = { categories: [], items: [] };
let activeCategory = 'cash';
let buying = false;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function esc(v) {
    return String(v || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function money(v) {
    return Number(v || 0).toLocaleString('en-US');
}

function imagePath(name) {
    if (!name) return '';
    return `images/${name}`;
}

function catIcon(icon) {
    if (icon === 'cash') return '💵';
    if (icon === 'vehicle') return '🚗';
    if (icon === 'garage') return '⌂';
    return '▣';
}

function currentItems() {
    return (shop.items || []).filter(item => String(item.category) === String(activeCategory));
}

function renderStats() {
    coinValue.textContent = money(shop.dzcoins || 0);
}

function renderCategories() {
    const cats = Array.isArray(shop.categories) ? shop.categories : [];

    categoriesEl.innerHTML = cats.map(cat => `
        <div class="category ${String(cat.id) === String(activeCategory) ? 'active' : ''}" onclick="setCategory('${esc(cat.id)}')">
            <div class="cat-icon">${catIcon(cat.icon)}</div>
            <div class="cat-text">
                <b>${esc(cat.label)}</b>
                <span>${esc(cat.subtitle)}</span>
            </div>
        </div>
    `).join('');

    const active = cats.find(cat => String(cat.id) === String(activeCategory));
    categoryTitle.textContent = active ? active.label : 'CASH';
    categorySubtitle.textContent = active ? active.subtitle : 'Cumpără bani cu DZ Coins';
}

function renderProducts() {
    const items = currentItems();

    productsEl.innerHTML = items.map(item => {
        const isBuy = item.purchasable === true;
        const price = isBuy
            ? `<div class="price"><span>${money(item.price)}</span><span class="dz-mini">DZ</span></div>`
            : `<div class="price disabled">COMING SOON</div>`;
        const button = isBuy ? 'PURCHASE' : 'COMING SOON';

        return `
            <article class="product">
                <img class="product-image" src="${imagePath(item.image)}" onerror="this.style.display='none'">
                <div class="product-body">
                    <div class="tag">${esc(item.tag || 'ITEM')}</div>
                    <h3>${esc(item.title)}</h3>
                    <div class="short">${esc(item.short)}</div>
                    <div class="desc">${esc(item.description)}</div>
                    <div class="bottom">
                        ${price}
                        <button class="buy-btn ${isBuy ? '' : 'disabled'}" onclick="${isBuy ? `buyItem('${esc(item.id)}')` : ''}">${button}</button>
                    </div>
                </div>
            </article>
        `;
    }).join('');
}

function setCategory(id) {
    activeCategory = id;
    renderCategories();
    renderProducts();
}

function getItem(id) {
    return (shop.items || []).find(item => String(item.id) === String(id));
}

function buyItem(id) {
    const item = getItem(id);
    if (!item || item.purchasable !== true || buying) return;

    buying = true;
    nui('purchase', { id });

    setTimeout(() => {
        buying = false;
    }, 1200);
}

function openShop(data) {
    shop = data || {};
    if (!Array.isArray(shop.categories)) shop.categories = [];
    if (!Array.isArray(shop.items)) shop.items = [];

    if (!shop.categories.some(cat => String(cat.id) === String(activeCategory))) {
        activeCategory = shop.categories.length ? shop.categories[0].id : 'cash';
    }

    renderStats();
    renderCategories();
    renderProducts();

    root.classList.remove('hidden');
}

function updateShop(data) {
    shop = data || shop;
    if (!Array.isArray(shop.categories)) shop.categories = [];
    if (!Array.isArray(shop.items)) shop.items = [];

    renderStats();
    renderCategories();
    renderProducts();
}

function closeShop() {
    root.classList.add('hidden');
    nui('close');
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') openShop(msg.payload || {});
    if (msg.action === 'update') updateShop(msg.payload || {});
    if (msg.action === 'close') root.classList.add('hidden');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closeShop();
    }
});

window.setCategory = setCategory;
window.buyItem = buyItem;
window.closeShop = closeShop;

setTimeout(() => nui('ready'), 80);
