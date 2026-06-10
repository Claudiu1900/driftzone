'use strict';

const inventoryRoot = document.getElementById('inventoryRoot');
const selectorRoot = document.getElementById('selectorRoot');
const addItemRoot = document.getElementById('addItemRoot');
const grid = document.getElementById('grid');
const droppedPanel = document.getElementById('droppedPanel');
const droppedList = document.getElementById('droppedList');
const contextMenu = document.getElementById('contextMenu');
const contextName = document.getElementById('contextName');
const ctxUse = document.getElementById('ctxUse');
const ctxGive = document.getElementById('ctxGive');
const ctxDrop = document.getElementById('ctxDrop');

const itemId = document.getElementById('itemId');
const itemName = document.getElementById('itemName');
const itemImage = document.getElementById('itemImage');
const itemTradable = document.getElementById('itemTradable');
const itemStackable = document.getElementById('itemStackable');
const itemUsable = document.getElementById('itemUsable');
const itemGiveable = document.getElementById('itemGiveable');
const itemMaxStack = document.getElementById('itemMaxStack');
const imagePreview = document.getElementById('imagePreview');
const previewImg = document.getElementById('previewImg');
const addStatus = document.getElementById('addStatus');

let slots = 49;
let inventory = {};
let dropped = [];
let dragged = null;
let selectedSlot = null;
let selectorActive = false;
let pendingGive = null;

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

function closeUi() { nui('close'); closeLocal(); }
function closeLocal() {
    hide(inventoryRoot);
    hide(selectorRoot);
    hide(addItemRoot);
    hide(contextMenu);
    selectedSlot = null;
    dragged = null;
    selectorActive = false;
    pendingGive = null;
}

function itemInitial(name) {
    const text = String(name || '?').trim();
    return text ? text[0].toUpperCase() : '?';
}

function itemVisual(item) {
    const image = item && item.image ? String(item.image) : '';
    const name = item && item.item_name ? String(item.item_name) : String(item?.item_id || '?');
    const fallback = `<div class="item-fallback">${esc(itemInitial(name))}</div>`;
    const img = image ? `<img class="item-img" src="${esc(image)}" draggable="false" onerror="this.outerHTML='${fallback.replace(/'/g, "\\'")}'">` : fallback;
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
    bindSlots();
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
            html.push(`<div class="drop-item" draggable="true" data-drop="${esc(d.id)}" data-index="${i + 1}">${itemVisual(item)}</div>`);
        }
    }
    droppedList.innerHTML = html.join('');
    bindDrops();
}

function bindSlots() {
    document.querySelectorAll('.slot').forEach((slot) => {
        const index = Number(slot.dataset.slot);

        slot.addEventListener('dragstart', (e) => {
            const item = inventory[index];
            if (!item) { e.preventDefault(); return; }
            dragged = { type: 'inventory', slot: index };
            e.dataTransfer.effectAllowed = 'move';
        });

        slot.addEventListener('dragover', (e) => {
            e.preventDefault();
            slot.classList.add('drag-over');
        });

        slot.addEventListener('dragleave', () => slot.classList.remove('drag-over'));

        slot.addEventListener('drop', (e) => {
            e.preventDefault();
            slot.classList.remove('drag-over');
            if (!dragged) return;
            if (dragged.type === 'inventory' && dragged.slot !== index) {
                nui('move', { from: dragged.slot, to: index });
            }
            if (dragged.type === 'drop') {
                nui('pickupDrop', { dropId: dragged.dropId, index: dragged.index, to: index });
            }
            dragged = null;
        });

        slot.addEventListener('click', () => {
            selectedSlot = inventory[index] ? index : null;
            hide(contextMenu);
            renderInventory();
        });

        slot.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            const item = inventory[index];
            if (!item) return;
            selectedSlot = index;
            renderInventory();
            openContextMenu(e.clientX, e.clientY, item);
        });
    });
}

function bindDrops() {
    document.querySelectorAll('.drop-item').forEach((el) => {
        el.addEventListener('dragstart', (e) => {
            dragged = { type: 'drop', dropId: el.dataset.drop, index: Number(el.dataset.index || 0) };
            e.dataTransfer.effectAllowed = 'move';
        });
    });

    droppedPanel.addEventListener('dragover', (e) => {
        e.preventDefault();
        droppedPanel.classList.add('drag-over');
    });
    droppedPanel.addEventListener('dragleave', () => droppedPanel.classList.remove('drag-over'));
    droppedPanel.addEventListener('drop', (e) => {
        e.preventDefault();
        droppedPanel.classList.remove('drag-over');
        if (dragged && dragged.type === 'inventory') {
            nui('dropItem', { slot: dragged.slot, amount: 1 });
        }
        dragged = null;
    });
}

function openContextMenu(x, y, item) {
    contextName.textContent = item.item_name || item.item_id || 'Item';
    ctxUse.style.display = item.usable ? 'block' : 'none';
    ctxGive.style.display = item.giveable ? 'block' : 'none';
    ctxDrop.style.display = 'block';

    contextMenu.style.left = `${Math.min(x, window.innerWidth - 190)}px`;
    contextMenu.style.top = `${Math.min(y, window.innerHeight - 170)}px`;
    show(contextMenu);
}

function useSelected() {
    if (!selectedSlot) return;
    nui('useItem', { slot: selectedSlot });
    hide(contextMenu);
}

function startGiveSelect() {
    if (!selectedSlot || !inventory[selectedSlot]) return;
    pendingGive = { slot: selectedSlot, amount: 1 };
    hide(contextMenu);
    hide(inventoryRoot);
    selectorActive = true;
    show(selectorRoot);
    nui('startGiveSelector', pendingGive);
}

function dropSelected() {
    if (!selectedSlot || !inventory[selectedSlot]) return;
    nui('dropItem', { slot: selectedSlot, amount: 1 });
    hide(contextMenu);
}

function openInventory(data = {}) {
    slots = Number(data.slots || 49);
    inventory = {};
    dropped = Array.isArray(data.dropped) ? data.dropped : [];

    const inv = data.inventory || {};
    if (Array.isArray(inv)) inv.forEach((item, idx) => { if (item) inventory[idx + 1] = item; });
    else Object.keys(inv).forEach((key) => { if (inv[key]) inventory[Number(key)] = inv[key]; });

    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    selectedSlot = null;
    hide(selectorRoot);
    hide(addItemRoot);
    show(inventoryRoot);
    renderInventory();
    renderDropped();
}

function updateDropped(data = {}) {
    dropped = Array.isArray(data.dropped) ? data.dropped : [];
    if (!inventoryRoot.classList.contains('hidden')) renderDropped();
}

function openSelector() {
    hide(inventoryRoot);
    hide(addItemRoot);
    selectorActive = true;
    show(selectorRoot);
}

function closeSelector() {
    selectorActive = false;
    hide(selectorRoot);
}

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

function submitAddItem() {
    const payload = {
        item_id: itemId.value.trim(),
        item_name: itemName.value.trim(),
        image: itemImage.value.trim(),
        tradable: Number(itemTradable.value || 1),
        stackable: Number(itemStackable.value || 1),
        usable: Number(itemUsable.value || 0),
        giveable: Number(itemGiveable.value || 1),
        max_stack: Number(itemMaxStack.value || 100)
    };
    nui('submitAddItem', payload);
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

document.addEventListener('mousemove', (e) => {
    if (selectorActive) nui('selectorMove', { x: e.clientX / window.innerWidth, y: e.clientY / window.innerHeight });
});

document.addEventListener('mousedown', (e) => {
    if (selectorActive && e.button === 0) nui('selectorClick', {});
    if (!contextMenu.classList.contains('hidden') && !contextMenu.contains(e.target)) hide(contextMenu);
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeUi();
});
