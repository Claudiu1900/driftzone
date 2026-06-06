'use strict';

const overlay = document.getElementById('overlay');
const list = document.getElementById('settingsList');
const categoryList = document.getElementById('categoryList');
const enabledCount = document.getElementById('enabledCount');
const disabledCount = document.getElementById('disabledCount');
const totalCount = document.getElementById('totalCount');

let toggles = [];
let values = {};
let activeCategory = 'All';
let mainColor = '#04c7f7';

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

function iconFor(id, category) {
    const icons = {
        hud: `<svg viewBox="0 0 24 24"><path d="M4 5h16v14H4zM8 9h5M8 13h8M8 17h3" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
        radar: `<svg viewBox="0 0 24 24"><path d="M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 12l5-3M12 3v3M12 18v3M3 12h3M18 12h3" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
        overhead_others: `<svg viewBox="0 0 24 24"><path d="M8 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM16.5 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM2 21a6 6 0 0 1 12 0M13.5 18a5 5 0 0 1 8.5 3" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
        overhead_self: `<svg viewBox="0 0 24 24"><path d="M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0M12 14v4M10 16h4" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`
    };

    return icons[id] || `<svg viewBox="0 0 24 24"><path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM4 12h2M18 12h2M12 4v2M12 18v2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`;
}

function categories() {
    const set = new Set(['All']);

    toggles.forEach((item) => set.add(item.category || 'Other'));

    return Array.from(set);
}

function renderCategories() {
    categoryList.innerHTML = categories().map((category) => {
        const active = category === activeCategory ? 'active' : '';

        return `
            <button class="navItem ${active}" onclick="setCategory('${escapeHtml(category)}')">
                <span>${escapeHtml(category)}</span>
            </button>
        `;
    }).join('');
}

function setCategory(category) {
    activeCategory = category;
    renderCategories();
    renderList();
}

function updateStats() {
    const total = toggles.length;
    const enabled = toggles.filter((item) => values[item.id] === true).length;
    const disabled = total - enabled;

    enabledCount.textContent = String(enabled);
    disabledCount.textContent = String(disabled);
    totalCount.textContent = String(total);
}

function renderList() {
    const visible = activeCategory === 'All'
        ? toggles
        : toggles.filter((item) => (item.category || 'Other') === activeCategory);

    updateStats();

    list.innerHTML = visible.map((item) => {
        const enabled = values[item.id] === true;
        const state = enabled ? 'on' : 'off';

        return `
            <div class="settingCard ${state}">
                <div class="left">
                    <div class="icon">${iconFor(item.id, item.category)}</div>
                    <div>
                        <div class="topline">${escapeHtml(item.category || 'Other')}</div>
                        <h2>${escapeHtml(item.title)}</h2>
                        <p>${escapeHtml(item.description)}</p>
                    </div>
                </div>

                <button class="toggle ${state}" onclick="toggleSetting('${escapeHtml(item.id)}')">
                    <span class="text offText">OFF</span>
                    <span class="knob"></span>
                    <span class="text onText">ON</span>
                </button>
            </div>
        `;
    }).join('');
}

function toggleSetting(id) {
    values[id] = values[id] !== true;
    renderList();
    nui('toggle', { id, value: values[id] === true });
}

function resetSettings() {
    nui('reset');
}

function open(data = {}) {
    mainColor = data.mainColor || mainColor;
    document.documentElement.style.setProperty('--main', mainColor);

    toggles = Array.isArray(data.toggles) ? data.toggles : toggles;
    values = data.values || values;

    activeCategory = 'All';
    renderCategories();
    renderList();

    overlay.classList.remove('hidden');
}

function closeSettings() {
    overlay.classList.add('hidden');
    nui('close');
}

function updateValues(nextValues) {
    values = nextValues || values;
    renderList();
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'init') {
        mainColor = data.mainColor || mainColor;
        document.documentElement.style.setProperty('--main', mainColor);
        toggles = Array.isArray(data.toggles) ? data.toggles : [];
        values = data.values || {};
        renderCategories();
        renderList();
    }

    if (data.action === 'open') open(data);
    if (data.action === 'values') updateValues(data.values || {});
    if (data.action === 'close') overlay.classList.add('hidden');
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeSettings();
});

window.setCategory = setCategory;
window.toggleSetting = toggleSetting;
window.resetSettings = resetSettings;
window.closeSettings = closeSettings;

setTimeout(() => nui('ready'), 50);
