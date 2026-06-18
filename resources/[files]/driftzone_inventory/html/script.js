'use strict';

const inventoryRoot = document.getElementById('inventoryRoot');
const selectorRoot = document.getElementById('selectorRoot');
const addItemRoot = document.getElementById('addItemRoot');
const grid = document.getElementById('grid');
const moneyPanel = document.getElementById('moneyPanel');
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

let slots = 49;
let inventory = {};
let moneySlots = {};
let dropped = [];
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
    hide(contextMenu);
    hide(amountModal);
    hide(moneyPanel);
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
        hide(moneyPanel);
        return;
    }
    moneyPanel.innerHTML = html.join('');
    show(moneyPanel);
}

function renderAllSlots() {
    renderMoneySlots();
    renderInventory();
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
        createGhost(drag.type === 'inventory' ? itemVisual(drag.item) : drag.html);
        document.body.classList.add('is-dragging');
    }
    if (!drag.active) return;
    scheduleGhostMove(e.clientX, e.clientY);
    const target = document.elementFromPoint(e.clientX, e.clientY);
    const slot = target ? target.closest('.slot') : null;
    const panel = target ? target.closest('.dropped-panel') : null;
    if (drag.type === 'currency') {
        setHover(panel || null);
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
    const droppedEl = target ? target.closest('.dropped-panel') : null;

    if (current.type === 'currency') {
        if (slotEl) return;
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
    const currency = isCurrencyItem(item);
    ctxUse.style.display = (!currency && bool(item.usable)) ? 'block' : 'none';
    ctxGive.style.display = (!currency && bool(item.giveable)) ? 'block' : 'none';
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
    if (!item || isCurrencyItem(item)) return;
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
    dropped = Array.isArray(data.dropped) ? data.dropped : [];
    const inv = data.inventory || {};
    const currency = data.moneyItems || data.currencyItems || {};
    if (Array.isArray(inv)) inv.forEach((item, idx) => { if (item) inventory[idx + 1] = item; });
    else Object.keys(inv).forEach((key) => { if (inv[key]) inventory[Number(key)] = inv[key]; });
    if (Array.isArray(currency)) currency.forEach((item) => { if (item && item.item_id) moneySlots[String(item.item_id)] = item; });
    else Object.keys(currency).forEach((key) => { if (currency[key]) moneySlots[String(key)] = currency[key]; });
    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    selectedSlot = null;
    hide(selectorRoot);
    hide(addItemRoot);
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

function openSelector() { hide(inventoryRoot); hide(addItemRoot); selectorActive = true; show(selectorRoot); }
function closeSelector() { selectorActive = false; hide(selectorRoot); }

function openAddItem() {
    hide(inventoryRoot);
    hide(selectorRoot);
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

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'openInventory') openInventory(msg.data || {});
    if (msg.action === 'updateDropped') updateDropped(msg.data || {});
    if (msg.action === 'openSelector') openSelector();
    if (msg.action === 'closeSelector') closeSelector();
    if (msg.action === 'closeAll') closeLocal();
    if (msg.action === 'openAddItem') openAddItem(msg.data || {});
    if (msg.action === 'addItemResult') {
        addStatus.textContent = msg.message || '';
        addStatus.className = `add-status ${msg.ok ? 'success' : 'error'}`;
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
window.syncGradientItemId = syncGradientItemId;
window.toggleGradientItem = toggleGradientItem;
