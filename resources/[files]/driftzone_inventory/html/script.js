'use strict';

const inventoryRoot = document.getElementById('inventoryRoot');
const addItemRoot = document.getElementById('addItemRoot');
const grid = document.getElementById('grid');
const tooltip = document.getElementById('tooltip');
const contextMenu = document.getElementById('contextMenu');
const givePanel = document.getElementById('givePanel');
const targetName = document.getElementById('targetName');
const giveAmount = document.getElementById('giveAmount');
const modeText = document.getElementById('modeText');

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
let currentMode = 'normal';
let currentTarget = null;
let draggedSlot = null;
let selectedSlot = null;
let lastMouse = { x: 0, y: 0 };

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

function closeUi() { nui('close'); closeLocal(); }
function closeLocal() {
    hide(inventoryRoot); hide(addItemRoot); hide(tooltip); hide(contextMenu); selectedSlot = null; draggedSlot = null;
}

function itemInitial(name) {
    const text = String(name || '?').trim();
    return text ? text[0].toUpperCase() : '?';
}

function renderInventory() {
    const html = [];
    for (let i = 1; i <= slots; i++) {
        const item = inventory[i];
        const selected = selectedSlot === i ? ' selected' : '';
        html.push(`<div class="slot${selected}" data-slot="${i}" draggable="${item ? 'true' : 'false'}">
            <div class="slot-index">${String(i).padStart(2, '0')}</div>
            ${item ? renderItem(item) : ''}
        </div>`);
    }
    grid.innerHTML = html.join('');
    bindSlots();
}

function renderItem(item) {
    const img = item.image ? `<img class="item-img" src="${esc(item.image)}" onerror="this.outerHTML='<div class=&quot;item-fallback&quot;>${esc(itemInitial(item.item_name))}</div>'">` : `<div class="item-fallback">${esc(itemInitial(item.item_name))}</div>`;
    const amount = Number(item.amount || 0) > 1 ? `<div class="amount">${Number(item.amount).toLocaleString('en-US')}</div>` : '';
    return `${img}${amount}`;
}

function bindSlots() {
    document.querySelectorAll('.slot').forEach((slot) => {
        const index = Number(slot.dataset.slot);

        slot.addEventListener('dragstart', (e) => {
            if (!inventory[index]) { e.preventDefault(); return; }
            draggedSlot = index;
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
            const to = index;
            if (draggedSlot && draggedSlot !== to) nui('move', { from: draggedSlot, to });
            draggedSlot = null;
        });

        slot.addEventListener('mouseenter', () => showTooltip(index));
        slot.addEventListener('mouseleave', () => hide(tooltip));
        slot.addEventListener('mousemove', (e) => {
            lastMouse = { x: e.clientX, y: e.clientY };
            moveTooltip(e.clientX, e.clientY);
        });

        slot.addEventListener('click', () => {
            selectedSlot = inventory[index] ? index : null;
            hide(contextMenu);
            renderInventory();
        });

        slot.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            if (!inventory[index]) return;
            selectedSlot = index;
            renderInventory();
            openContextMenu(e.clientX, e.clientY);
        });
    });
}

function showTooltip(slot) {
    const item = inventory[slot];
    if (!item) return;
    tooltip.innerHTML = `${esc(item.item_name || item.item_id)}<small>${esc(item.item_id)}${item.amount > 1 ? ' • x' + item.amount : ''}</small>`;
    show(tooltip);
    moveTooltip(lastMouse.x, lastMouse.y);
}

function moveTooltip(x, y) {
    tooltip.style.left = `${x + 14}px`;
    tooltip.style.top = `${y + 14}px`;
}

function openContextMenu(x, y) {
    contextMenu.style.left = `${x}px`;
    contextMenu.style.top = `${y}px`;
    const item = inventory[selectedSlot];
    const buttons = contextMenu.querySelectorAll('button');
    if (buttons[0]) buttons[0].style.display = item && item.usable ? 'block' : 'none';
    if (buttons[1]) buttons[1].style.display = currentMode === 'give' && item && item.giveable && item.tradable ? 'block' : 'none';
    show(contextMenu);
}

function useSelected() {
    if (!selectedSlot) return;
    nui('useItem', { slot: selectedSlot });
    hide(contextMenu);
}

function selectForGive() {
    hide(contextMenu);
    if (!selectedSlot || currentMode !== 'give') return;
    giveAmount.focus();
}

function sendGive() {
    if (!selectedSlot || !inventory[selectedSlot]) return;
    const amount = Math.max(1, Math.floor(Number(giveAmount.value || 1)));
    nui('giveItem', { slot: selectedSlot, amount });
}

function openInventory(data = {}) {
    slots = Number(data.slots || 49);
    currentMode = data.mode || 'normal';
    currentTarget = data.target || null;
    inventory = {};

    const inv = data.inventory || {};
    if (Array.isArray(inv)) {
        inv.forEach((item, idx) => { if (item) inventory[idx + 1] = item; });
    } else {
        Object.keys(inv).forEach((key) => { if (inv[key]) inventory[Number(key)] = inv[key]; });
    }

    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    modeText.textContent = currentMode === 'give' && currentTarget ? `Give către ${currentTarget.name || 'Player'}` : '49 slots';

    if (currentMode === 'give' && currentTarget) {
        targetName.textContent = currentTarget.name || 'Player';
        giveAmount.value = '1';
        show(givePanel);
    } else {
        hide(givePanel);
    }

    hide(addItemRoot);
    show(inventoryRoot);
    renderInventory();
}

function openAddItem(data = {}) {
    document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');
    hide(inventoryRoot);
    show(addItemRoot);
    itemId.value = '';
    itemName.value = '';
    itemImage.value = '';
    itemTradable.value = '1';
    itemStackable.value = '1';
    itemUsable.value = '0';
    itemGiveable.value = '1';
    itemMaxStack.value = '100';
    addStatus.textContent = 'Completează itemul.';
    addStatus.className = 'add-status';
    hide(imagePreview);
    setTimeout(() => itemId.focus(), 80);
}

function previewImage() {
    const url = String(itemImage.value || '').trim();
    if (!url || !/^https?:\/\//i.test(url)) {
        hide(imagePreview);
        previewImg.src = '';
        return;
    }
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
    addStatus.textContent = 'Se salvează...';
    addStatus.className = 'add-status';
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openInventory') openInventory(data.data || {});
    if (data.action === 'openAddItem') openAddItem(data.data || {});
    if (data.action === 'closeAll') closeLocal();
    if (data.action === 'addItemResult') {
        addStatus.textContent = data.message || (data.ok ? 'Salvat.' : 'Eroare.');
        addStatus.className = data.ok ? 'add-status success' : 'add-status error';
    }
});

document.addEventListener('click', (e) => {
    if (!contextMenu.contains(e.target)) hide(contextMenu);
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeUi();
});
