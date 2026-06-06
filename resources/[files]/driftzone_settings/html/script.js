'use strict';

const overlay = document.getElementById('overlay');
const list = document.getElementById('settingsList');
const categoryList = document.getElementById('categoryList');

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

function iconFor(category) {
    const icons = {
        Interface: `<svg viewBox="0 0 24 24"><path d="M4 5h16v11H4zM8 21h8M10 16l-1 5M14 16l1 5" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
        Overhead: `<svg viewBox="0 0 24 24"><path d="M12 4a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM4 21a8 8 0 0 1 16 0M5 5l2 2M19 5l-2 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`,
        Vehicle: `<svg viewBox="0 0 24 24"><path d="M5 14l2-6h10l2 6M6 14h12v5H6zM8 19v2M16 19v2M7 14l-2 2M17 14l2 2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
        Voice: `<svg viewBox="0 0 24 24"><path d="M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3zM5 11a7 7 0 0 0 14 0M12 18v3M9 21h6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`
    };

    return icons[category] || `<svg viewBox="0 0 24 24"><path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM4 12h2M18 12h2M12 4v2M12 18v2" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>`;
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
            <button class="nav-item ${active}" onclick="setCategory('${escapeHtml(category)}')">
                ${category === 'All' ? iconFor('Other') : iconFor(category)}
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

function renderList() {
    const visible = activeCategory === 'All'
        ? toggles
        : toggles.filter((item) => (item.category || 'Other') === activeCategory);

    list.innerHTML = visible.map((item) => {
        const enabled = values[item.id] === true;
        const state = enabled ? 'on' : 'off';

        return `
            <div class="setting-card">
                <div class="setting-left">
                    <div class="setting-icon">${iconFor(item.category)}</div>
                    <div>
                        <h2>${escapeHtml(item.title)}</h2>
                        <p>${escapeHtml(item.description)}</p>
                        <span class="tag">${escapeHtml(item.category || 'Other')}</span>
                    </div>
                </div>

                <button class="toggle ${state}" onclick="toggleSetting('${escapeHtml(item.id)}')">
                    <span class="toggle-text off-text">OFF</span>
                    <span class="toggle-knob"></span>
                    <span class="toggle-text on-text">ON</span>
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
