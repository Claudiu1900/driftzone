'use strict';

const inventoryRoot = document.getElementById('inventoryRoot');
const selectorRoot = document.getElementById('selectorRoot');
const addItemRoot = document.getElementById('addItemRoot');
const itemsRoot = document.getElementById('itemsRoot');
const addClothesRoot = document.getElementById('addClothesRoot');
const clothesItemsRoot = document.getElementById('clothesItemsRoot');
const clothingShell = document.getElementById('clothingShell');
const clothingSlotsEl = document.getElementById('clothingSlots');
const grid = document.getElementById('grid');
const moneyShell = document.getElementById('moneyShell');
const moneyPanel = document.getElementById('moneyPanel');
const quickShell = document.getElementById('quickShell');
const quickBar = document.getElementById('quickBar');
const droppedPanel = document.getElementById('droppedPanel');
const droppedList = document.getElementById('droppedList');
const contextMenu = document.getElementById('contextMenu');
const contextName = document.getElementById('contextName');
const ctxUse = document.getElementById('ctxUse');
const ctxGive = document.getElementById('ctxGive');
const ctxDrop = document.getElementById('ctxDrop');
const amountModal = document.getElementById('amountModal');
const amountRange = document.getElementById('amountRange');
const amountInput = document.getElementById('amountInput');
const amountTitle = document.getElementById('amountTitle');
const amountMax = document.getElementById('amountMax');

const itemId = document.getElementById('itemId');
const itemName = document.getElementById('itemName');
const itemImage = document.getElementById('itemImage');
const itemTradable = document.getElementById('itemTradable');
const itemStackable = document.getElementById('itemStackable');
const itemUsable = document.getElementById('itemUsable');
const itemGiveable = document.getElementById('itemGiveable');
const itemMaxStack = document.getElementById('itemMaxStack');
const itemIsGradient = document.getElementById('itemIsGradient');
const itemGradientId = document.getElementById('itemGradientId');
const imagePreview = document.getElementById('imagePreview');
const previewImg = document.getElementById('previewImg');
const addStatus = document.getElementById('addStatus');
const clothesCategory = document.getElementById('clothesCategory');
const clothesDrawable = document.getElementById('clothesDrawable');
const clothesTexture = document.getElementById('clothesTexture');
const clothesItemId = document.getElementById('clothesItemId');
const clothesItemName = document.getElementById('clothesItemName');
const clothesItemImage = document.getElementById('clothesItemImage');
const clothesTradable = document.getElementById('clothesTradable');
const clothesStackable = document.getElementById('clothesStackable');
const clothesUsable = document.getElementById('clothesUsable');
const clothesGiveable = document.getElementById('clothesGiveable');
const clothesMaxStack = document.getElementById('clothesMaxStack');
const clothesImagePreview = document.getElementById('clothesImagePreview');
const clothesPreviewImg = document.getElementById('clothesPreviewImg');
const clothesStatus = document.getElementById('clothesStatus');

const itemsSearch = document.getElementById('itemsSearch');
const itemsList = document.getElementById('itemsList');
const itemsStatus = document.getElementById('itemsStatus');
const adminOriginalItemId = document.getElementById('adminOriginalItemId');
const adminItemId = document.getElementById('adminItemId');
const adminItemName = document.getElementById('adminItemName');
const adminItemImage = document.getElementById('adminItemImage');
const adminItemTradable = document.getElementById('adminItemTradable');
const adminItemStackable = document.getElementById('adminItemStackable');
const adminItemUsable = document.getElementById('adminItemUsable');
const adminItemGiveable = document.getElementById('adminItemGiveable');
const adminItemMaxStack = document.getElementById('adminItemMaxStack');
const adminItemIsGradient = document.getElementById('adminItemIsGradient');
const adminItemGradientId = document.getElementById('adminItemGradientId');
const adminImagePreview = document.getElementById('adminImagePreview');
const adminPreviewImg = document.getElementById('adminPreviewImg');
const clothesItemsFilter = document.getElementById('clothesItemsFilter');
const clothesItemsSearch = document.getElementById('clothesItemsSearch');
const clothesItemsList = document.getElementById('clothesItemsList');
const clothesItemsStatus = document.getElementById('clothesItemsStatus');
const adminOriginalClothesId = document.getElementById('adminOriginalClothesId');
const adminClothesItemId = document.getElementById('adminClothesItemId');
const adminClothesItemName = document.getElementById('adminClothesItemName');
const adminClothesCategory = document.getElementById('adminClothesCategory');
const adminClothesDrawable = document.getElementById('adminClothesDrawable');
const adminClothesTexture = document.getElementById('adminClothesTexture');
const adminClothesImage = document.getElementById('adminClothesImage');
const adminClothesTradable = document.getElementById('adminClothesTradable');
const adminClothesStackable = document.getElementById('adminClothesStackable');
const adminClothesUsable = document.getElementById('adminClothesUsable');
const adminClothesGiveable = document.getElementById('adminClothesGiveable');
const adminClothesMaxStack = document.getElementById('adminClothesMaxStack');
const adminClothesImagePreview = document.getElementById('adminClothesImagePreview');
const adminClothesPreviewImg = document.getElementById('adminClothesPreviewImg');

let slots = 49;
let inventory = {};
let moneySlots = {};
let quickSlots = {};
let clothingSlots = {};
let clothingCategories = [];
let adminClothesItems = [];
let selectedAdminClothesId = null;
let dropped = [];
let adminItems = [];
let selectedAdminItemId = null;
let selectedSlot = null;
let selectorActive = false;
let pendingGive = null;
let amountAction = null;
let drag = null;
let dragGhost = null;
let ghostX = 0;
let ghostY = 0;
let rafPending = false;
let lastHoverEl = null;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function show(el) { if (el) el.classList.remove('hidden'); }
function hide(el) { if (el) el.classList.add('hidden'); }
function esc(value) {
    return String(value ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}
function amountText(v) { return Number(v || 0).toLocaleString('en-US'); }
function bool(v) { return v === true || Number(v) === 1 || String(v).toLowerCase() === 'true'; }
const DEFAULT_CLOTHING_CATEGORIES = [
    { key: 'hat', label: 'Hat', icon: 'hat.svg' },
    { key: 'glasses', label: 'Glasses', icon: 'glasses.svg' },
    { key: 'mask', label: 'Mask', icon: 'mask.svg' },
    { key: 'accessories', label: 'Accessories', icon: 'accessories.svg' },
    { key: 'jacket', label: 'Jacket', icon: 'jacket.svg' },
    { key: 'top', label: 'Top', icon: 'top.svg' },
    { key: 'torso', label: 'Torso', icon: 'torso.svg' },
    { key: 'vest', label: 'Vest', icon: 'vest.svg' },
    { key: 'bag', label: 'Bag', icon: 'bag.svg' },
    { key: 'pants', label: 'Pants', icon: 'pants.svg' },
    { key: 'shoes', label: 'Shoes', icon: 'shoes.svg' },
    { key: 'watches', label: 'Watches', icon: 'watches.svg' },
    { key: 'bracelets', label: 'Bracelets', icon: 'bracelets.svg' }
];
function isClothingItem(item) { return item && bool(item.is_clothing); }
function normalizeCategoryKey(key) { return String(key || '').toLowerCase().trim(); }
function getCategoryLabel(key) {
    const cat = (clothingCategories.length ? clothingCategories : DEFAULT_CLOTHING_CATEGORIES).find((entry) => entry.key === key);
    return cat ? cat.label : key;
}
function populateCategorySelect(selectEl, selected = '') {
    if (!selectEl) return;
    const cats = clothingCategories.length ? clothingCategories : DEFAULT_CLOTHING_CATEGORIES;
    selectEl.innerHTML = cats.map((cat) => `<option value="${esc(cat.key)}">${esc(cat.label || cat.key)}</option>`).join('');
    if (selected) selectEl.value = selected;
}
function populateFilterSelect() {
    if (!clothesItemsFilter) return;
    const cats = clothingCategories.length ? clothingCategories : DEFAULT_CLOTHING_CATEGORIES;
    clothesItemsFilter.innerHTML = '<option value="all">All categories</option>' + cats.map((cat) => `<option value="${esc(cat.key)}">${esc(cat.label || cat.key)}</option>`).join('');
}
function isMoneySlotKey(slot) {
    const key = String(slot ?? '');
    return key === 'money' || key === 'dirtymoney';
}
function isCurrencyItem(item) {
    const id = String(item?.item_id || '');
    return item && (bool(item.special_currency) || bool(item.is_currency) || id === 'money' || id === 'dirtymoney');
}
function getItemBySlot(slot) {
    const key = String(slot ?? '');
    if (isMoneySlotKey(key)) return moneySlots[key] || null;
    return inventory[Number(slot || 0)] || null;
}
function isStackableMany(item) { return item && bool(item.stackable) && Number(item.amount || 0) > 1; }
function clampAmount(value, max) {
    const m = Math.max(1, Math.floor(Number(max || 1)));
    const n = Math.floor(Number(value || 1));
    return Math.min(m, Math.max(1, Number.isFinite(n) ? n : 1));
}

function closeUi() { nui('close'); closeLocal(); }
function closeLocal() {
    hide(inventoryRoot);
    hide(selectorRoot);
    hide(addItemRoot);
    hide(itemsRoot);
    hide(addClothesRoot);
    hide(clothesItemsRoot);
    hide(addClothesRoot);
    hide(clothesItemsRoot);
    hide(contextMenu);
    hide(amountModal);
    hide(moneyShell);
    selectedSlot = null;
    selectorActive = false;
    pendingGive = null;
    amountAction = null;
    cancelDrag();
}

function itemInitial(name) {
    const text = String(name || '?').trim();
    return text ? text[0].toUpperCase() : '?';
}

function itemVisual(item) {
    const image = item && item.image ? String(item.image) : '';
    const name = item && item.item_name ? String(item.item_name) : String(item?.item_id || '?');
    const fallbackText = esc(itemInitial(name));
    const img = image ? `<img class="item-img" src="${esc(image)}" draggable="false" onerror="this.style.display='none';this.nextElementSibling.classList.remove('hidden')"><div class="item-fallback hidden">${fallbackText}</div>` : `<div class="item-fallback">${fallbackText}</div>`;
    const amount = Number(item?.amount || 0) > 1 ? `<div class="amount">${amountText(item.amount)}</div>` : '';
    return `<div class="item-box">${img}${amount}</div>`;
}

function renderInventory() {
    const html = [];
    for (let i = 1; i <= slots; i++) {
        const item = inventory[i];
        html.push(`<div class="slot${selectedSlot === i ? ' selected' : ''}" data-slot="${i}">${item ? itemVisual(item) : ''}</div>`);
    }
    grid.innerHTML = html.join('');
}

function renderMoneySlots() {
    const order = ['money', 'dirtymoney'];
    const html = [];
    for (const key of order) {
        const item = moneySlots[key];
        if (!item || Number(item.amount || 0) <= 0) continue;
        html.push(`<div class="money-slot${selectedSlot === key ? ' selected' : ''}" data-money-slot="${key}" title="${esc(item.item_name || item.item_id || key)}">${itemVisual(item)}</div>`);
    }
    if (html.length <= 0) {
        moneyPanel.innerHTML = '';
        hide(moneyShell);
        return;
    }
    moneyPanel.innerHTML = html.join('');
    show(moneyShell);
}

function quickEmptySvg(index) {
    const safe = esc(index);
    return `<div class="quick-empty" aria-hidden="true"><svg viewBox="0 0 118 94" xmlns="http://www.w3.org/2000/svg"><rect x="1" y="1" width="116" height="92" rx="10" fill="rgba(255,255,255,0.025)" stroke="rgba(255,255,255,0.12)"/><path d="M18 74 C30 54, 40 66, 52 46 S82 26, 100 43" fill="none" stroke="rgba(4,199,247,0.28)" stroke-width="3" stroke-linecap="round"/><circle cx="95" cy="23" r="5" fill="rgba(4,199,247,0.32)"/><text x="59" y="59" text-anchor="middle" font-size="42" font-weight="900" fill="rgba(255,255,255,0.24)" font-family="Arial, sans-serif">${safe}</text></svg></div>`;
}

function getQuickSlotIndex(index) {
    return Number(quickSlots[String(index)] || quickSlots[Number(index)] || 0) || 0;
}

function getQuickItem(index) {
    const slotIndex = getQuickSlotIndex(index);
    const item = slotIndex > 0 ? inventory[slotIndex] : null;
    return item && bool(item.usable) ? { slotIndex, item } : null;
}

function renderQuickSlots() {
    const html = [];
    for (let i = 1; i <= 5; i++) {
        const quick = getQuickItem(i);
        const selected = quick && selectedSlot === quick.slotIndex;
        html.push(`<div class="quick-slot${quick ? ' filled' : ''}${selected ? ' selected' : ''}" data-quick="${i}" title="Quick ${i}">${quick ? itemVisual(quick.item) : quickEmptySvg(i)}</div>`);
    }
    quickBar.innerHTML = html.join('');
}


function clothingEmptySvg(cat) {
    const icon = esc(cat.icon || `${cat.key}.svg`);
    const label = esc(cat.label || cat.key);
    return `<div class="clothing-empty"><img src="icons/${icon}" draggable="false" onerror="this.style.display='none'"><span>${label}</span></div>`;
}

function renderClothingSlots() {
    if (!clothingSlotsEl) return;
    const cats = clothingCategories.length ? clothingCategories : DEFAULT_CLOTHING_CATEGORIES;
    clothingSlotsEl.innerHTML = cats.map((cat) => {
        const key = normalizeCategoryKey(cat.key);
        const item = clothingSlots[key];
        return `<div class="clothing-slot cat-${esc(key)}${item ? ' filled' : ''}" data-clothing="${esc(key)}" title="${esc(cat.label || key)}">${item ? itemVisual(item) : clothingEmptySvg(cat)}</div>`;
    }).join('');
}

function renderAllSlots() {
    renderMoneySlots();
    renderInventory();
    renderQuickSlots();
    renderClothingSlots();
}

function beginDragFromMoneySlot(e, slotEl) {
    const slot = String(slotEl.dataset.moneySlot || '');
    const item = getItemBySlot(slot);
    if (!item) return;
    selectedSlot = slot;
    hide(contextMenu);
    hide(amountModal);
    drag = {
        type: 'currency',
        slot,
        item,
        startX: e.clientX,
        startY: e.clientY,
        active: false,
        clickBlocked: false
    };
    e.preventDefault();
}

function beginDragFromQuickSlot(e, quickEl) {
    const quickIndex = Number(quickEl.dataset.quick || 0);
    const quick = getQuickItem(quickIndex);
    if (!quick) return;
    selectedSlot = quick.slotIndex;
    hide(contextMenu);
    hide(amountModal);
    drag = {
        type: 'quick',
        quickIndex,
        slot: quick.slotIndex,
        item: quick.item,
        startX: e.clientX,
        startY: e.clientY,
        active: false,
        clickBlocked: false
    };
    e.preventDefault();
}


function beginDragFromClothingSlot(e, clothingEl) {
    const category = normalizeCategoryKey(clothingEl.dataset.clothing || '');
    const item = clothingSlots[category];
    if (!item) return;
    selectedSlot = null;
    hide(contextMenu);
    hide(amountModal);
    drag = {
        type: 'clothing',
        category,
        item,
        startX: e.clientX,
        startY: e.clientY,
        active: false,
        clickBlocked: false
    };
    e.preventDefault();
}

function renderDropped() {
    if (!Array.isArray(dropped) || dropped.length <= 0) {
        hide(droppedPanel);
        droppedList.innerHTML = '';
        return;
    }
    show(droppedPanel);
    const html = [];
    for (const d of dropped) {
        const entries = Array.isArray(d.items) ? d.items : [];
        for (let i = 0; i < entries.length; i++) {
            const item = entries[i];
            if (!item) continue;
            html.push(`<div class="drop-item" data-drop="${esc(d.id)}" data-index="${i + 1}">${itemVisual(item)}</div>`);
        }
    }
    droppedList.innerHTML = html.join('');
}

function createGhost(html) {
    destroyGhost();
    dragGhost = document.createElement('div');
    dragGhost.className = 'drag-ghost';
    dragGhost.innerHTML = html || '';
    document.body.appendChild(dragGhost);
}

function destroyGhost() {
    if (dragGhost && dragGhost.parentNode) dragGhost.parentNode.removeChild(dragGhost);
    dragGhost = null;
}

function scheduleGhostMove(x, y) {
    ghostX = x;
    ghostY = y;
    if (rafPending) return;
    rafPending = true;
    requestAnimationFrame(() => {
        rafPending = false;
        if (dragGhost) dragGhost.style.transform = `translate3d(${ghostX - 41}px, ${ghostY - 41}px, 0) scale(1.04)`;
    });
}

function setHover(el) {
    if (lastHoverEl === el) return;
    if (lastHoverEl) lastHoverEl.classList.remove('drag-over');
    lastHoverEl = el;
    if (lastHoverEl) lastHoverEl.classList.add('drag-over');
}

function cancelDrag() {
    if (lastHoverEl) lastHoverEl.classList.remove('drag-over');
    lastHoverEl = null;
    drag = null;
    destroyGhost();
}

function beginDragFromSlot(e, slotEl) {
    const slot = Number(slotEl.dataset.slot || 0);
    const item = getItemBySlot(slot);
    if (!item) return;
    selectedSlot = slot;
    hide(contextMenu);
    hide(amountModal);
    drag = {
        type: 'inventory',
        slot,
        item,
        startX: e.clientX,
        startY: e.clientY,
        active: false,
        clickBlocked: false
    };
    e.preventDefault();
}

function beginDragFromDrop(e, dropEl) {
    hide(contextMenu);
    hide(amountModal);
    drag = {
        type: 'drop',
        dropId: dropEl.dataset.drop,
        index: Number(dropEl.dataset.index || 0),
        html: dropEl.innerHTML,
        startX: e.clientX,
        startY: e.clientY,
        active: false,
        clickBlocked: false
    };
    e.preventDefault();
}

function updateDrag(e) {
    if (!drag) return;
    const dx = e.clientX - drag.startX;
    const dy = e.clientY - drag.startY;
    if (!drag.active && Math.sqrt(dx * dx + dy * dy) > 5) {
        drag.active = true;
        drag.clickBlocked = true;
        createGhost(drag.item ? itemVisual(drag.item) : drag.html);
        document.body.classList.add('is-dragging');
    }
    if (!drag.active) return;
    scheduleGhostMove(e.clientX, e.clientY);
    const target = document.elementFromPoint(e.clientX, e.clientY);
    const slot = target ? target.closest('.slot') : null;
    const quick = target ? target.closest('.quick-slot') : null;
    const clothing = target ? target.closest('.clothing-slot') : null;
    const panel = target ? target.closest('.dropped-panel') : null;
    if (drag.type === 'currency') {
        setHover(panel || null);
    } else if ((drag.type === 'inventory' || drag.type === 'quick') && quick && drag.item && bool(drag.item.usable)) {
        setHover(quick);
    } else if (drag.type === 'inventory' && clothing && isClothingItem(drag.item) && normalizeCategoryKey(drag.item.clothes_category) === normalizeCategoryKey(clothing.dataset.clothing || '')) {
        setHover(clothing);
    } else if (drag.type === 'clothing' && slot) {
        setHover(slot);
    } else {
        setHover(slot || (panel && drag.type === 'inventory' ? panel : null));
    }
}

function finishDrag(e) {
    if (!drag) return;
    document.body.classList.remove('is-dragging');
    const wasActive = drag.active;
    const current = drag;
    if (lastHoverEl) lastHoverEl.classList.remove('drag-over');
    lastHoverEl = null;
    destroyGhost();
    drag = null;
    if (!wasActive) return;

    const target = document.elementFromPoint(e.clientX, e.clientY);
    const slotEl = target ? target.closest('.slot') : null;
    const quickEl = target ? target.closest('.quick-slot') : null;
    const clothingEl = target ? target.closest('.clothing-slot') : null;
    const droppedEl = target ? target.closest('.dropped-panel') : null;

    if (quickEl && (current.type === 'inventory' || current.type === 'quick')) {
        const quickIndex = Number(quickEl.dataset.quick || 0);
        if (quickIndex >= 1 && quickIndex <= 5 && current.item && bool(current.item.usable)) {
            nui('setQuickSlot', { index: quickIndex, slot: current.slot });
        }
        return;
    }

    if (clothingEl && current.type === 'inventory') {
        const category = normalizeCategoryKey(clothingEl.dataset.clothing || '');
        if (current.item && isClothingItem(current.item) && normalizeCategoryKey(current.item.clothes_category) === category) {
            nui('equipClothingSlot', { category, slot: current.slot });
        }
        return;
    }

    if (current.type === 'clothing') {
        if (slotEl) {
            nui('unequipClothingSlot', { category: current.category, to: Number(slotEl.dataset.slot || 0) });
        }
        return;
    }

    if (current.type === 'quick') {
        nui('setQuickSlot', { index: current.quickIndex, slot: 0 });
        return;
    }

    if (current.type === 'currency') {
        if (slotEl || quickEl) return;
        selectedSlot = current.slot;
        const item = getItemBySlot(current.slot);
        if (isStackableMany(item)) openAmountModal('drop', current.slot, item);
        else nui('dropItem', { slot: current.slot, amount: 1 });
        return;
    }

    if (slotEl) {
        const to = Number(slotEl.dataset.slot || 0);
        if (to > 0) {
            if (current.type === 'inventory' && current.slot !== to) {
                nui('move', { from: current.slot, to });
            } else if (current.type === 'drop') {
                nui('pickupDrop', { dropId: current.dropId, index: current.index, to });
            }
        }
        return;
    }

    if (droppedEl && current.type === 'inventory') {
        selectedSlot = current.slot;
        const item = getItemBySlot(current.slot);
        if (isStackableMany(item)) openAmountModal('drop', current.slot, item);
        else nui('dropItem', { slot: current.slot, amount: 1 });
        return;
    }

    // Drag & drop in afara inventarului = arunca itemul pe jos.
    if (current.type === 'inventory') {
        selectedSlot = current.slot;
        const item = getItemBySlot(current.slot);
        if (isStackableMany(item)) openAmountModal('drop', current.slot, item);
        else nui('dropItem', { slot: current.slot, amount: 1 });
        return;
    }
}

function openContextMenu(x, y, item) {
    contextName.textContent = item.item_name || item.item_id || 'Item';
    ctxUse.style.display = bool(item.usable) ? 'block' : 'none';
    ctxGive.style.display = bool(item.giveable) ? 'block' : 'none';
    ctxDrop.style.display = 'block';
    contextMenu.style.left = `${Math.min(x, window.innerWidth - 190)}px`;
    contextMenu.style.top = `${Math.min(y, window.innerHeight - 170)}px`;
    show(contextMenu);
}

function openAmountModal(action, slot, item) {
    const max = Math.max(1, Math.floor(Number(item?.amount || 1)));
    amountAction = { action, slot, max };
    amountTitle.textContent = action === 'give' ? 'GIVE AMOUNT' : 'DROP AMOUNT';
    amountMax.textContent = `MAX ${amountText(max)}`;
    amountRange.min = '1';
    amountRange.max = String(max);
    amountRange.value = '1';
    amountInput.min = '1';
    amountInput.max = String(max);
    amountInput.value = '1';
    hide(contextMenu);
    show(amountModal);
    setTimeout(() => amountInput.focus(), 40);
}

function syncAmountFromRange() { amountInput.value = amountRange.value; }
function syncAmountFromInput() {
    if (!amountAction) return;
    const value = clampAmount(amountInput.value, amountAction.max);
    amountInput.value = String(value);
    amountRange.value = String(value);
}
function setAmountMin() { if (!amountAction) return; amountInput.value = '1'; amountRange.value = '1'; }
function setAmountMax() { if (!amountAction) return; amountInput.value = String(amountAction.max); amountRange.value = String(amountAction.max); }
function cancelAmount() { amountAction = null; hide(amountModal); }
function confirmAmount() {
    if (!amountAction) return;
    const amount = clampAmount(amountInput.value, amountAction.max);
    const slot = amountAction.slot;
    const action = amountAction.action;
    amountAction = null;
    hide(amountModal);
    if (action === 'drop') nui('dropItem', { slot, amount });
    if (action === 'give') startGiveSelectWithAmount(slot, amount);
}

function useSelected() {
    if (!selectedSlot) return;
    nui('useItem', { slot: selectedSlot });
    hide(contextMenu);
}

function startGiveSelectWithAmount(slot, amount) {
    pendingGive = { slot, amount };
    hide(contextMenu);
    hide(amountModal);
    hide(inventoryRoot);
    selectorActive = true;
    show(selectorRoot);
    nui('startGiveSelector', pendingGive);
}

function startGiveSelect() {
    if (!selectedSlot) return;
    const item = getItemBySlot(selectedSlot);
    if (!item || !bool(item.giveable)) return;
    if (isStackableMany(item)) return openAmountModal('give', selectedSlot, item);
    startGiveSelectWithAmount(selectedSlot, 1);
}

function dropSelected() {
    if (!selectedSlot) return;
    const item = getItemBySlot(selectedSlot);
    if (!item) return;
    if (isStackableMany(item)) return openAmountModal('drop', selectedSlot, item);
    nui('dropItem', { slot: selectedSlot, amount: 1 });
    hide(contextMenu);
}

function openInventory(data = {}) {
    slots = Number(data.slots || 49);
    inventory = {};
    moneySlots = {};
    quickSlots = {};
    clothingSlots = {};
    clothingCategories = Array.isArray(data.clothingCategories) ? data.clothingCategories : DEFAULT_CLOTHING_CATEGORIES;
    dropped = Array.isArray(data.dropped) ? data.dropped : [];
    const inv = data.inventory || {};
    const currency = data.moneyItems || data.currencyItems || {};
    const quick = data.quickSlots || {};
    const clothes = data.clothesSlots || {};
    if (Array.isArray(inv)) inv.forEach((item, idx) => { if (item) inventory[idx + 1] = item; });
    else Object.keys(inv).forEach((key) => { if (inv[key]) inventory[Number(key)] = inv[key]; });
    if (Array.isArray(currency)) currency.forEach((item) => { if (item && item.item_id) moneySlots[String(item.item_id)] = item; });
    else Object.keys(currency).forEach((key) => { if (currency[key]) moneySlots[String(key)] = currency[key]; });
    if (Array.isArray(quick)) quick.forEach((slot, idx) => { if (Number(slot || 0) > 0) quickSlots[String(idx + 1)] = Number(slot); });
    else Object.keys(quick).forEach((key) => { if (Number(quick[key] || 0) > 0) quickSlots[String(key)] = Number(quick[key]); });
    Object.keys(clothes).forEach((key) => { if (clothes[key]) clothingSlots[normalizeCategoryKey(key)] = clothes[key]; });
    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    selectedSlot = null;
    hide(selectorRoot);
    hide(addItemRoot);
    hide(itemsRoot);
    hide(addClothesRoot);
    hide(clothesItemsRoot);
    hide(addClothesRoot);
    hide(clothesItemsRoot);
    hide(contextMenu);
    hide(amountModal);
    show(inventoryRoot);
    renderAllSlots();
    renderDropped();
}

function updateDropped(data = {}) {
    dropped = Array.isArray(data.dropped) ? data.dropped : [];
    if (!inventoryRoot.classList.contains('hidden')) renderDropped();
}

function openSelector() { hide(inventoryRoot); hide(addItemRoot); hide(itemsRoot); hide(addClothesRoot); hide(clothesItemsRoot); selectorActive = true; show(selectorRoot); }
function closeSelector() { selectorActive = false; hide(selectorRoot); }

function openAddItem() {
    hide(inventoryRoot);
    hide(selectorRoot);
    hide(itemsRoot);
    hide(addClothesRoot);
    hide(clothesItemsRoot);
    selectorActive = false;
    show(addItemRoot);
    itemId.value = '';
    itemName.value = '';
    itemImage.value = '';
    itemTradable.value = '1';
    itemStackable.value = '1';
    itemUsable.value = '0';
    itemGiveable.value = '1';
    itemMaxStack.value = '100';
    if (itemIsGradient) itemIsGradient.value = '0';
    if (itemGradientId) itemGradientId.value = '0';
    hide(imagePreview);
    addStatus.textContent = 'Completează itemul.';
    addStatus.className = 'add-status';
    setTimeout(() => itemId.focus(), 80);
}

function previewImage() {
    const url = String(itemImage.value || '').trim();
    if (!url) { hide(imagePreview); previewImg.src = ''; return; }
    previewImg.src = url;
    show(imagePreview);
}


function syncGradientItemId() {
    if (!itemIsGradient || !itemGradientId || !itemId) return;
    if (Number(itemIsGradient.value || 0) !== 1) return;
    const gid = Math.max(0, Math.floor(Number(itemGradientId.value || 0)));
    if (gid > 0) itemId.value = `${gid}_gradient`;
}

function toggleGradientItem() {
    if (!itemIsGradient) return;
    const enabled = Number(itemIsGradient.value || 0) === 1;
    if (enabled) {
        itemUsable.value = '1';
        itemGiveable.value = '1';
        itemStackable.value = '1';
        if (!itemGradientId.value || Number(itemGradientId.value) <= 0) itemGradientId.value = '1';
        syncGradientItemId();
        if (!itemName.value.trim()) itemName.value = `Gradient ${itemGradientId.value}`;
    }
}

function submitAddItem() {
    if (addStatus) {
        addStatus.textContent = 'Se salveaza itemul...';
        addStatus.className = 'add-status';
    }

    const isGradient = Number(itemIsGradient ? itemIsGradient.value || 0 : 0);
    const gradientId = Math.max(0, Math.floor(Number(itemGradientId ? itemGradientId.value || 0 : 0)));

    if (isGradient === 1) {
        if (gradientId <= 0) {
            if (addStatus) {
                addStatus.textContent = 'Pune Gradient ID mai mare decat 0.';
                addStatus.className = 'add-status error';
            }
            return;
        }
        itemId.value = `${gradientId}_gradient`;
        itemUsable.value = '1';
        itemGiveable.value = '1';
        itemStackable.value = '1';
        itemMaxStack.value = '1';
        if (!itemName.value.trim()) itemName.value = `Gradient ${gradientId}`;
    }

    nui('submitAddItem', {
        item_id: itemId.value.trim(),
        item_name: itemName.value.trim(),
        image: itemImage.value.trim(),
        tradable: Number(itemTradable.value || 1),
        stackable: Number(itemStackable.value || 1),
        usable: Number(itemUsable.value || 0),
        giveable: Number(itemGiveable.value || 1),
        max_stack: Number(itemMaxStack.value || 100),
        is_gradient: isGradient,
        gradient_id: gradientId
    });
}


function adminBoolValue(value, fallback = 0) {
    if (value === true) return '1';
    if (value === false) return '0';
    const n = Number(value);
    return Number.isFinite(n) ? (n === 1 ? '1' : '0') : String(fallback);
}

function openItemsPanel(data = {}) {
    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    adminItems = Array.isArray(data.items) ? data.items : [];
    selectedAdminItemId = data.selected || (adminItems[0] ? String(adminItems[0].item_id || '') : null);
    hide(inventoryRoot);
    hide(selectorRoot);
    hide(addItemRoot);
    hide(addClothesRoot);
    hide(clothesItemsRoot);
    hide(contextMenu);
    hide(amountModal);
    selectorActive = false;
    show(itemsRoot);
    if (itemsSearch) itemsSearch.value = '';
    renderAdminItemsList();
    if (selectedAdminItemId) selectAdminItem(selectedAdminItemId);
    else clearAdminEditor();
}

function renderAdminItemsList() {
    if (!itemsList) return;
    const q = String(itemsSearch?.value || '').trim().toLowerCase();
    const filtered = adminItems.filter((item) => {
        const hay = `${item.item_id || ''} ${item.item_name || ''}`.toLowerCase();
        return !q || hay.includes(q);
    });

    if (filtered.length <= 0) {
        itemsList.innerHTML = '<div class="items-empty">Nu exista iteme.</div>';
        return;
    }

    itemsList.innerHTML = filtered.map((item) => {
        const id = String(item.item_id || '');
        const active = id === selectedAdminItemId ? ' active' : '';
        const usable = bool(item.usable) ? 'USABLE' : 'NO USE';
        return `<button class="items-row${active}" data-item-id="${esc(id)}"><span>${esc(item.item_name || id)}</span><small>${esc(id)} · ${usable}</small></button>`;
    }).join('');
}

function clearAdminEditor() {
    if (!adminItemId) return;
    adminOriginalItemId.value = '';
    adminItemId.value = '';
    adminItemName.value = '';
    adminItemImage.value = '';
    adminItemTradable.value = '1';
    adminItemStackable.value = '1';
    adminItemUsable.value = '0';
    adminItemGiveable.value = '1';
    adminItemMaxStack.value = '100';
    adminItemIsGradient.value = '0';
    adminItemGradientId.value = '0';
    hide(adminImagePreview);
    if (itemsStatus) {
        itemsStatus.textContent = 'Selecteaza un item din lista.';
        itemsStatus.className = 'add-status';
    }
}

function selectAdminItem(itemIdValue) {
    const id = String(itemIdValue || '');
    const item = adminItems.find((entry) => String(entry.item_id || '') === id);
    if (!item) return clearAdminEditor();

    selectedAdminItemId = id;
    adminOriginalItemId.value = id;
    adminItemId.value = id;
    adminItemName.value = String(item.item_name || id);
    adminItemImage.value = String(item.image || '');
    adminItemTradable.value = adminBoolValue(item.tradable, 1);
    adminItemStackable.value = adminBoolValue(item.stackable, 1);
    adminItemUsable.value = adminBoolValue(item.usable, 0);
    adminItemGiveable.value = adminBoolValue(item.giveable, 1);
    adminItemMaxStack.value = String(Math.max(1, Math.floor(Number(item.max_stack || 100))));
    adminItemIsGradient.value = adminBoolValue(item.is_gradient, 0);
    adminItemGradientId.value = String(Math.max(0, Math.floor(Number(item.gradient_id || 0))));
    previewAdminImage();
    if (itemsStatus) {
        itemsStatus.textContent = `Editezi: ${item.item_name || id}`;
        itemsStatus.className = 'add-status';
    }
    renderAdminItemsList();
}

function previewAdminImage() {
    const url = String(adminItemImage?.value || '').trim();
    if (!url) { hide(adminImagePreview); if (adminPreviewImg) adminPreviewImg.src = ''; return; }
    adminPreviewImg.src = url;
    show(adminImagePreview);
}

function syncAdminGradientItemId() {
    if (!adminItemIsGradient || !adminItemGradientId) return;
    if (Number(adminItemIsGradient.value || 0) !== 1) return;
    const gid = Math.max(0, Math.floor(Number(adminItemGradientId.value || 0)));
    if (gid > 0 && !adminOriginalItemId.value) adminItemId.value = `${gid}_gradient`;
}

function toggleAdminGradientItem() {
    if (!adminItemIsGradient) return;
    const enabled = Number(adminItemIsGradient.value || 0) === 1;
    if (enabled) {
        adminItemUsable.value = '1';
        adminItemGiveable.value = '1';
        adminItemStackable.value = '1';
        if (!adminItemGradientId.value || Number(adminItemGradientId.value) <= 0) adminItemGradientId.value = '1';
        syncAdminGradientItemId();
        if (!adminItemName.value.trim()) adminItemName.value = `Gradient ${adminItemGradientId.value}`;
    }
}

function submitAdminItem() {
    if (!adminOriginalItemId.value) {
        if (itemsStatus) {
            itemsStatus.textContent = 'Selecteaza un item inainte sa salvezi.';
            itemsStatus.className = 'add-status error';
        }
        return;
    }

    const isGradient = Number(adminItemIsGradient ? adminItemIsGradient.value || 0 : 0);
    const gradientId = Math.max(0, Math.floor(Number(adminItemGradientId ? adminItemGradientId.value || 0 : 0)));
    if (isGradient === 1) {
        if (gradientId <= 0) {
            itemsStatus.textContent = 'Pune Gradient ID mai mare decat 0.';
            itemsStatus.className = 'add-status error';
            return;
        }
        adminItemUsable.value = '1';
        adminItemGiveable.value = '1';
        adminItemStackable.value = '1';
        if (!adminItemName.value.trim()) adminItemName.value = `Gradient ${gradientId}`;
    }

    if (itemsStatus) {
        itemsStatus.textContent = 'Se salveaza modificarile...';
        itemsStatus.className = 'add-status';
    }

    nui('submitAdminItem', {
        original_id: adminOriginalItemId.value.trim(),
        item_id: adminItemId.value.trim(),
        item_name: adminItemName.value.trim(),
        image: adminItemImage.value.trim(),
        tradable: Number(adminItemTradable.value || 1),
        stackable: Number(adminItemStackable.value || 1),
        usable: Number(adminItemUsable.value || 0),
        giveable: Number(adminItemGiveable.value || 1),
        max_stack: Number(adminItemMaxStack.value || 100),
        is_gradient: isGradient,
        gradient_id: gradientId
    });
}

function handleItemsResult(msg = {}) {
    if (Array.isArray(msg.items)) adminItems = msg.items;
    const selected = msg.itemId || selectedAdminItemId;
    renderAdminItemsList();
    if (selected) selectAdminItem(selected);
    if (itemsStatus) {
        itemsStatus.textContent = msg.message || '';
        itemsStatus.className = `add-status ${msg.ok ? 'success' : 'error'}`;
    }
}


function openAddClothesPanel(data = {}) {
    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    clothingCategories = Array.isArray(data.categories) ? data.categories : DEFAULT_CLOTHING_CATEGORIES;
    hide(inventoryRoot); hide(selectorRoot); hide(addItemRoot); hide(itemsRoot); hide(clothesItemsRoot);
    selectorActive = false;
    populateCategorySelect(clothesCategory);
    show(addClothesRoot);
    if (clothesDrawable) clothesDrawable.value = '0';
    if (clothesTexture) clothesTexture.value = '0';
    if (clothesItemId) clothesItemId.value = '';
    if (clothesItemName) clothesItemName.value = '';
    if (clothesItemImage) clothesItemImage.value = '';
    if (clothesTradable) clothesTradable.value = '1';
    if (clothesStackable) clothesStackable.value = '0';
    if (clothesUsable) clothesUsable.value = '1';
    if (clothesGiveable) clothesGiveable.value = '1';
    if (clothesMaxStack) clothesMaxStack.value = '1';
    hide(clothesImagePreview);
    clothesStatus.textContent = 'Completează haina.';
    clothesStatus.className = 'add-status';
    setTimeout(() => clothesItemId && clothesItemId.focus(), 80);
}

function previewClothesImage() {
    const url = String(clothesItemImage?.value || '').trim();
    if (!url) { hide(clothesImagePreview); if (clothesPreviewImg) clothesPreviewImg.src = ''; return; }
    clothesPreviewImg.src = url;
    show(clothesImagePreview);
}

function submitAddClothes() {
    if (clothesStatus) { clothesStatus.textContent = 'Se salveaza haina...'; clothesStatus.className = 'add-status'; }
    nui('submitAddClothes', {
        category_key: clothesCategory.value,
        drawable: Number(clothesDrawable.value || 0),
        texture: Number(clothesTexture.value || 0),
        item_id: clothesItemId.value.trim(),
        item_name: clothesItemName.value.trim(),
        image: clothesItemImage.value.trim(),
        tradable: Number(clothesTradable.value || 1),
        stackable: Number(clothesStackable.value || 0),
        usable: Number(clothesUsable.value || 1),
        giveable: Number(clothesGiveable.value || 1),
        max_stack: Number(clothesMaxStack.value || 1)
    });
}

function openClothesItemsPanel(data = {}) {
    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    clothingCategories = Array.isArray(data.categories) ? data.categories : DEFAULT_CLOTHING_CATEGORIES;
    adminClothesItems = Array.isArray(data.items) ? data.items : [];
    selectedAdminClothesId = data.selected || (adminClothesItems[0] ? String(adminClothesItems[0].item_id || '') : null);
    hide(inventoryRoot); hide(selectorRoot); hide(addItemRoot); hide(itemsRoot); hide(addClothesRoot); hide(contextMenu); hide(amountModal);
    selectorActive = false;
    show(clothesItemsRoot);
    populateFilterSelect();
    populateCategorySelect(adminClothesCategory);
    if (clothesItemsSearch) clothesItemsSearch.value = '';
    renderAdminClothesList();
    if (selectedAdminClothesId) selectAdminClothesItem(selectedAdminClothesId);
    else clearAdminClothesEditor();
}

function renderAdminClothesList() {
    if (!clothesItemsList) return;
    const q = String(clothesItemsSearch?.value || '').trim().toLowerCase();
    const filter = String(clothesItemsFilter?.value || 'all');
    const filtered = adminClothesItems.filter((item) => {
        const hay = `${item.item_id || ''} ${item.item_name || ''} ${item.category_key || ''}`.toLowerCase();
        const categoryOk = filter === 'all' || String(item.category_key || '') === filter;
        return categoryOk && (!q || hay.includes(q));
    });
    if (filtered.length <= 0) { clothesItemsList.innerHTML = '<div class="items-empty">Nu exista haine.</div>'; return; }
    clothesItemsList.innerHTML = filtered.map((item) => {
        const id = String(item.item_id || '');
        const active = id === selectedAdminClothesId ? ' active' : '';
        return `<button class="clothes-row items-row${active}" data-clothes-id="${esc(id)}"><span>${esc(item.item_name || id)}</span><small>${esc(getCategoryLabel(item.category_key))} · drawable ${esc(item.drawable)}</small></button>`;
    }).join('');
}

function clearAdminClothesEditor() {
    if (!adminClothesItemId) return;
    adminOriginalClothesId.value = '';
    adminClothesItemId.value = '';
    adminClothesItemName.value = '';
    populateCategorySelect(adminClothesCategory);
    adminClothesDrawable.value = '0';
    adminClothesTexture.value = '0';
    adminClothesImage.value = '';
    adminClothesTradable.value = '1';
    adminClothesStackable.value = '0';
    adminClothesUsable.value = '1';
    adminClothesGiveable.value = '1';
    adminClothesMaxStack.value = '1';
    hide(adminClothesImagePreview);
    clothesItemsStatus.textContent = 'Selecteaza o haina din lista.';
    clothesItemsStatus.className = 'add-status';
}

function selectAdminClothesItem(itemIdValue) {
    const id = String(itemIdValue || '');
    const item = adminClothesItems.find((entry) => String(entry.item_id || '') === id);
    if (!item) return clearAdminClothesEditor();
    selectedAdminClothesId = id;
    adminOriginalClothesId.value = id;
    adminClothesItemId.value = id;
    adminClothesItemName.value = String(item.item_name || id);
    populateCategorySelect(adminClothesCategory, String(item.category_key || 'jacket'));
    adminClothesDrawable.value = String(Number(item.drawable || 0));
    adminClothesTexture.value = String(Number(item.texture || 0));
    adminClothesImage.value = String(item.image || '');
    adminClothesTradable.value = adminBoolValue(item.tradable, 1);
    adminClothesStackable.value = adminBoolValue(item.stackable, 0);
    adminClothesUsable.value = adminBoolValue(item.usable, 1);
    adminClothesGiveable.value = adminBoolValue(item.giveable, 1);
    adminClothesMaxStack.value = String(Math.max(1, Math.floor(Number(item.max_stack || 1))));
    previewAdminClothesImage();
    clothesItemsStatus.textContent = `Editezi: ${item.item_name || id}`;
    clothesItemsStatus.className = 'add-status';
    renderAdminClothesList();
}

function previewAdminClothesImage() {
    const url = String(adminClothesImage?.value || '').trim();
    if (!url) { hide(adminClothesImagePreview); if (adminClothesPreviewImg) adminClothesPreviewImg.src = ''; return; }
    adminClothesPreviewImg.src = url;
    show(adminClothesImagePreview);
}

function submitAdminClothesItem() {
    if (!adminOriginalClothesId.value) {
        clothesItemsStatus.textContent = 'Selecteaza o haina inainte sa salvezi.';
        clothesItemsStatus.className = 'add-status error';
        return;
    }
    clothesItemsStatus.textContent = 'Se salveaza modificarile...';
    clothesItemsStatus.className = 'add-status';
    nui('submitAdminClothesItem', {
        original_id: adminOriginalClothesId.value.trim(),
        item_id: adminClothesItemId.value.trim(),
        item_name: adminClothesItemName.value.trim(),
        category_key: adminClothesCategory.value,
        drawable: Number(adminClothesDrawable.value || 0),
        texture: Number(adminClothesTexture.value || 0),
        image: adminClothesImage.value.trim(),
        tradable: Number(adminClothesTradable.value || 1),
        stackable: Number(adminClothesStackable.value || 0),
        usable: Number(adminClothesUsable.value || 1),
        giveable: Number(adminClothesGiveable.value || 1),
        max_stack: Number(adminClothesMaxStack.value || 1)
    });
}

function handleClothesItemsResult(msg = {}) {
    if (Array.isArray(msg.items)) adminClothesItems = msg.items;
    const selected = msg.itemId || selectedAdminClothesId;
    renderAdminClothesList();
    if (selected) selectAdminClothesItem(selected);
    if (clothesItemsStatus) {
        clothesItemsStatus.textContent = msg.message || '';
        clothesItemsStatus.className = `add-status ${msg.ok ? 'success' : 'error'}`;
    }
}

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'openInventory') openInventory(msg.data || {});
    if (msg.action === 'updateDropped') updateDropped(msg.data || {});
    if (msg.action === 'openSelector') openSelector();
    if (msg.action === 'closeSelector') closeSelector();
    if (msg.action === 'closeAll') closeLocal();
    if (msg.action === 'openAddItem') openAddItem(msg.data || {});
    if (msg.action === 'openItems') openItemsPanel(msg.data || {});
    if (msg.action === 'openAddClothes') openAddClothesPanel(msg.data || {});
    if (msg.action === 'openClothesItems') openClothesItemsPanel(msg.data || {});
    if (msg.action === 'itemsResult') handleItemsResult(msg);
    if (msg.action === 'clothesItemsResult') handleClothesItemsResult(msg);
    if (msg.action === 'addItemResult') {
        addStatus.textContent = msg.message || '';
        addStatus.className = `add-status ${msg.ok ? 'success' : 'error'}`;
    }
    if (msg.action === 'clothesResult') {
        clothesStatus.textContent = msg.message || '';
        clothesStatus.className = `add-status ${msg.ok ? 'success' : 'error'}`;
    }
});

grid.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    const slot = e.target.closest('.slot');
    if (!slot) return;
    beginDragFromSlot(e, slot);
});

moneyPanel.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    const slot = e.target.closest('.money-slot');
    if (!slot) return;
    beginDragFromMoneySlot(e, slot);
});

quickBar.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    const slot = e.target.closest('.quick-slot');
    if (!slot) return;
    beginDragFromQuickSlot(e, slot);
});


clothingSlotsEl.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    const slot = e.target.closest('.clothing-slot');
    if (!slot) return;
    beginDragFromClothingSlot(e, slot);
});

droppedList.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    const drop = e.target.closest('.drop-item');
    if (!drop) return;
    beginDragFromDrop(e, drop);
});

grid.addEventListener('click', (e) => {
    if (drag && drag.clickBlocked) return;
    const slotEl = e.target.closest('.slot');
    if (!slotEl) return;
    const index = Number(slotEl.dataset.slot || 0);
    selectedSlot = inventory[index] ? index : null;
    hide(contextMenu);
    renderAllSlots();
});

moneyPanel.addEventListener('click', (e) => {
    if (drag && drag.clickBlocked) return;
    const slotEl = e.target.closest('.money-slot');
    if (!slotEl) return;
    const key = String(slotEl.dataset.moneySlot || '');
    selectedSlot = moneySlots[key] ? key : null;
    hide(contextMenu);
    renderAllSlots();
});

quickBar.addEventListener('click', (e) => {
    if (drag && drag.clickBlocked) return;
    const slotEl = e.target.closest('.quick-slot');
    if (!slotEl) return;
    const quickIndex = Number(slotEl.dataset.quick || 0);
    const quick = getQuickItem(quickIndex);
    selectedSlot = quick ? quick.slotIndex : null;
    hide(contextMenu);
    renderAllSlots();
});

grid.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    const slotEl = e.target.closest('.slot');
    if (!slotEl) return;
    const index = Number(slotEl.dataset.slot || 0);
    const item = inventory[index];
    if (!item) return;
    selectedSlot = index;
    renderAllSlots();
    openContextMenu(e.clientX, e.clientY, item);
});

moneyPanel.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    const slotEl = e.target.closest('.money-slot');
    if (!slotEl) return;
    const key = String(slotEl.dataset.moneySlot || '');
    const item = moneySlots[key];
    if (!item) return;
    selectedSlot = key;
    renderAllSlots();
    openContextMenu(e.clientX, e.clientY, item);
});

if (itemsList) {
    itemsList.addEventListener('click', (e) => {
        const row = e.target.closest('.items-row');
        if (!row) return;
        selectAdminItem(row.dataset.itemId || '');
    });
}


if (clothesItemsList) {
    clothesItemsList.addEventListener('click', (e) => {
        const row = e.target.closest('.clothes-row');
        if (!row) return;
        selectAdminClothesItem(row.dataset.clothesId || '');
    });
}

quickBar.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    const slotEl = e.target.closest('.quick-slot');
    if (!slotEl) return;
    const quickIndex = Number(slotEl.dataset.quick || 0);
    const quick = getQuickItem(quickIndex);
    if (!quick) return;
    selectedSlot = quick.slotIndex;
    renderAllSlots();
    openContextMenu(e.clientX, e.clientY, quick.item);
});

document.addEventListener('mousemove', (e) => {
    if (selectorActive) nui('selectorMove', { x: e.clientX / window.innerWidth, y: e.clientY / window.innerHeight });
    updateDrag(e);
});

document.addEventListener('mouseup', finishDrag);

document.addEventListener('mousedown', (e) => {
    if (selectorActive && e.button === 0) nui('selectorClick', {});
    if (!contextMenu.classList.contains('hidden') && !contextMenu.contains(e.target)) hide(contextMenu);
    if (!amountModal.classList.contains('hidden') && !amountModal.contains(e.target) && !contextMenu.contains(e.target)) cancelAmount();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeUi();

    const typing = e.target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName);
    if (!typing && !inventoryRoot.classList.contains('hidden') && /^[1-5]$/.test(e.key)) {
        nui('useQuickSlot', { index: Number(e.key) });
    }
});

window.syncAmountFromRange = syncAmountFromRange;
window.syncAmountFromInput = syncAmountFromInput;
window.setAmountMin = setAmountMin;
window.setAmountMax = setAmountMax;
window.cancelAmount = cancelAmount;
window.confirmAmount = confirmAmount;
window.useSelected = useSelected;
window.startGiveSelect = startGiveSelect;
window.dropSelected = dropSelected;
window.closeUi = closeUi;
window.previewImage = previewImage;
window.submitAddItem = submitAddItem;
window.renderAdminItemsList = renderAdminItemsList;
window.previewAdminImage = previewAdminImage;
window.submitAdminItem = submitAdminItem;
window.syncAdminGradientItemId = syncAdminGradientItemId;
window.toggleAdminGradientItem = toggleAdminGradientItem;
window.syncGradientItemId = syncGradientItemId;
window.toggleGradientItem = toggleGradientItem;
window.previewClothesImage = previewClothesImage;
window.submitAddClothes = submitAddClothes;
window.renderAdminClothesList = renderAdminClothesList;
window.previewAdminClothesImage = previewAdminClothesImage;
window.submitAdminClothesItem = submitAdminClothesItem;
