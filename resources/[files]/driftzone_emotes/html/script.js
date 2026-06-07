'use strict';

const root = document.getElementById('root');
const closeBtn = document.getElementById('closeBtn');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const categoryBar = document.getElementById('categoryBar');
const searchInput = document.getElementById('searchInput');
const emoteGrid = document.getElementById('emoteGrid');
const countText = document.getElementById('countText');

let categories = [];
let emotes = [];
let activeCategory = 'general';
let search = '';
let renderTimer = null;

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
    const map = {
        favorites: '★',
        general: '✦',
        dance: '♪',
        actions: '◆',
        sitting: '◖',
        walks: '⌁'
    };
    return map[category] || '✧';
}

function setMainColor(color) {
    if (color) document.documentElement.style.setProperty('--main', color);
}

function open(data) {
    setMainColor(data.mainColor);
    titleEl.textContent = data.title || 'DriftZone Emotes';
    subtitleEl.textContent = data.subtitle || '';
    searchInput.placeholder = data.searchPlaceholder || 'Cauta emote...';

    categories = Array.isArray(data.categories) ? data.categories : [];
    emotes = Array.isArray(data.emotes) ? data.emotes : [];
    activeCategory = categories[0]?.id || 'general';
    search = '';
    searchInput.value = '';

    renderCategories();
    render();

    root.classList.remove('hidden');
    setTimeout(() => searchInput.focus(), 80);
}

function close() {
    root.classList.add('hidden');
    nui('close');
}

function renderCategories() {
    categoryBar.innerHTML = categories.map((cat) => {
        const active = cat.id === activeCategory ? 'active' : '';
        return `
            <button class="cat ${active}" data-category="${escapeHtml(cat.id)}">
                <span>${iconFor(cat.id)}</span>
                <b>${escapeHtml(cat.label || cat.id)}</b>
            </button>
        `;
    }).join('');

    categoryBar.querySelectorAll('.cat').forEach((btn) => {
        btn.addEventListener('click', () => {
            activeCategory = btn.dataset.category;
            renderCategories();
            render();
        });
    });
}

function filteredEmotes() {
    const query = search.trim().toLowerCase();

    return emotes.filter((emote) => {
        const inCategory = activeCategory === 'favorites'
            ? emote.favorite === true
            : emote.category === activeCategory;

        if (!inCategory) return false;
        if (!query) return true;

        return [emote.name, emote.label, emote.description]
            .join(' ')
            .toLowerCase()
            .includes(query);
    });
}

function render() {
    const list = filteredEmotes();
    countText.textContent = `${list.length} emotes`;

    if (list.length === 0) {
        emoteGrid.innerHTML = `
            <div class="empty">
                <b>Niciun emote gasit</b>
                <span>Schimba categoria sau cautarea.</span>
            </div>
        `;
        return;
    }

    emoteGrid.innerHTML = list.map((emote) => {
        const fav = emote.favorite ? 'active' : '';
        return `
            <article class="card" data-name="${escapeHtml(emote.name)}">
                <button class="fav ${fav}" data-fav="${escapeHtml(emote.name)}">★</button>
                <div class="card-icon">${iconFor(emote.category)}</div>
                <div class="card-body">
                    <h2>${escapeHtml(emote.label || emote.name)}</h2>
                    <p>${escapeHtml(emote.description || '')}</p>
                    <code>/e ${escapeHtml(emote.name)}</code>
                </div>
                <button class="play" data-play="${escapeHtml(emote.name)}">Play</button>
            </article>
        `;
    }).join('');

    emoteGrid.querySelectorAll('[data-play]').forEach((btn) => {
        btn.addEventListener('click', (event) => {
            event.stopPropagation();
            nui('play', { name: btn.dataset.play });
        });
    });

    emoteGrid.querySelectorAll('[data-fav]').forEach((btn) => {
        btn.addEventListener('click', (event) => {
            event.stopPropagation();
            nui('toggleFavorite', { name: btn.dataset.fav });
        });
    });

    emoteGrid.querySelectorAll('.card').forEach((card) => {
        card.addEventListener('dblclick', () => {
            nui('play', { name: card.dataset.name });
        });
    });
}

function queueRender() {
    if (renderTimer) clearTimeout(renderTimer);
    renderTimer = setTimeout(render, 40);
}

closeBtn.addEventListener('click', close);
searchInput.addEventListener('input', () => {
    search = searchInput.value || '';
    queueRender();
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') close();
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') open(data);
    if (data.action === 'close') root.classList.add('hidden');
    if (data.action === 'favorites') {
        emotes = Array.isArray(data.emotes) ? data.emotes : emotes;
        render();
    }
});

setTimeout(() => nui('ready'), 80);
