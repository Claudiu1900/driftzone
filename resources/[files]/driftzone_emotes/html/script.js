'use strict';
const root = document.getElementById('root');
const grid = document.getElementById('grid');
const categoriesEl = document.getElementById('categories');
const searchInput = document.getElementById('searchInput');
const countEl = document.getElementById('count');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
let emotes = [];
let activeCategory = 'All';

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});
}
function escapeHtml(value) {
    return String(value || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#039;');
}
function categories() {
    const set = new Set(['All']);
    for (const e of emotes) set.add(e.category || 'Other');
    return [...set];
}
function renderCategories() {
    categoriesEl.innerHTML = categories().map((cat) => `<button class="${cat === activeCategory ? 'active' : ''}" onclick="setCategory('${escapeHtml(cat)}')">${escapeHtml(cat)}</button>`).join('');
}
function render() {
    const q = String(searchInput.value || '').toLowerCase().trim();
    let list = emotes.filter((e) => activeCategory === 'All' || (e.category || 'Other') === activeCategory);
    if (q) {
        list = list.filter((e) => `${e.id || ''} ${e.label || ''} ${e.category || ''} ${e.dict || ''}`.toLowerCase().includes(q));
    }
    countEl.textContent = String(list.length);
    if (!list.length) {
        grid.innerHTML = `<div class="empty">Nu am gasit niciun emote.</div>`;
        return;
    }
    grid.innerHTML = list.map((e) => `<button class="card" onclick="playEmote('${escapeHtml(e.id)}')"><div class="shine"></div><div class="cardTop"><span>${escapeHtml(e.category || 'Emote')}</span><b>/e ${escapeHtml(e.id || '')}</b></div><h2>${escapeHtml(e.label || e.id)}</h2><p>${escapeHtml(e.dict || '')}</p></button>`).join('');
}
function setCategory(cat) { activeCategory = cat; renderCategories(); render(); }
function playEmote(id) { nui('play', { id }); }
function open(data = {}) {
    if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
    if (data.title) titleEl.textContent = String(data.title);
    if (data.subtitle) subtitleEl.textContent = String(data.subtitle);
    emotes = Array.isArray(data.emotes) ? data.emotes : emotes;
    activeCategory = 'All';
    renderCategories();
    render();
    root.classList.remove('hidden');
    setTimeout(() => searchInput.focus(), 60);
}
function closeMenu() { root.classList.add('hidden'); nui('close'); }
document.addEventListener('keydown', (event) => { if (event.key === 'Escape') closeMenu(); });
window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'setup') {
        emotes = Array.isArray(data.emotes) ? data.emotes : [];
        if (data.mainColor) document.documentElement.style.setProperty('--main', data.mainColor);
        if (data.title) titleEl.textContent = String(data.title);
        if (data.subtitle) subtitleEl.textContent = String(data.subtitle);
        renderCategories();
        render();
    }
    if (data.action === 'open') open(data);
    if (data.action === 'close') root.classList.add('hidden');
});
window.setCategory = setCategory;
window.playEmote = playEmote;
window.closeMenu = closeMenu;
setTimeout(() => nui('ready'), 80);
