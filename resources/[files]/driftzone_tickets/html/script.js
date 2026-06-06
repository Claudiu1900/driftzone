'use strict';

const $ = (id) => document.getElementById(id);

const counterEl = $('counter');
const ticketCountEl = $('ticketCount');
const adminTicketCountEl = $('adminTicketCount');
const overlayEl = $('overlay');
const userPanelEl = $('userPanel');
const adminPanelEl = $('adminPanel');
const ticketTitleEl = $('ticketTitle');
const ticketSubjectEl = $('ticketSubject');
const userErrorEl = $('userError');
const ticketsListEl = $('ticketsList');
const ticketSearchEl = $('ticketSearch');

let cachedTickets = [];
let acceptLocks = new Set();
let lastMode = 'player';

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

function safeNumber(value) {
    return Number(value || 0) || 0;
}

function setCount(count) {
    const number = safeNumber(count);

    ticketCountEl.textContent = String(number);
    adminTicketCountEl.textContent = String(number);

    counterEl.classList.toggle('hidden', number <= 0);
}

function setMode(mode) {
    lastMode = mode === 'admin' ? 'admin' : 'player';
}

function closeLocal() {
    overlayEl.classList.add('hidden');
    userPanelEl.classList.add('hidden');
    adminPanelEl.classList.add('hidden');
    acceptLocks.clear();
}

function closeAll() {
    closeLocal();
    nui('close');
}

function openUser() {
    setMode('player');
    cachedTickets = [];
    acceptLocks.clear();

    overlayEl.classList.remove('hidden');
    userPanelEl.classList.remove('hidden');
    adminPanelEl.classList.add('hidden');

    userErrorEl.textContent = '';
    ticketTitleEl.value = '';
    ticketSubjectEl.value = '';

    requestAnimationFrame(() => ticketTitleEl.focus());
}

function ticketIcon() {
    return `
        <svg viewBox="0 0 24 24" class="card-svg">
            <path d="M5 7a3 3 0 0 1 3-3h9a2 2 0 0 1 2 2v4a2.5 2.5 0 0 0 0 5v3a2 2 0 0 1-2 2H8a3 3 0 0 1-3-3v-2a2.5 2.5 0 0 0 0-5V7z" fill="none" stroke="currentColor" stroke-width="1.8"/>
            <path d="M10 8h5M10 12h4M10 16h5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
        </svg>
    `;
}

function renderTickets(tickets) {
    const list = Array.isArray(tickets) ? tickets : [];
    const query = (ticketSearchEl?.value || '').trim().toLowerCase();
    const filtered = query
        ? list.filter((ticket) => [
            ticket.id,
            ticket.title,
            ticket.subject,
            ticket.playerName,
            ticket.playerUid,
            ticket.createdAt
        ].join(' ').toLowerCase().includes(query))
        : list;

    adminTicketCountEl.textContent = String(list.length);

    if (filtered.length === 0) {
        ticketsListEl.innerHTML = `
            <div class="empty">
                <div class="empty-orb"></div>
                <svg viewBox="0 0 64 64">
                    <path d="M14 20h36a4 4 0 0 1 4 4v6a6 6 0 0 0 0 12v6a4 4 0 0 1-4 4H14a4 4 0 0 1-4-4v-6a6 6 0 0 0 0-12v-6a4 4 0 0 1 4-4z" fill="none" stroke="currentColor" stroke-width="3"/>
                    <path d="M24 32h16" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>
                </svg>
                <b>Nu exista tickete active</b>
                <span>Queue-ul este curat momentan.</span>
            </div>
        `;
        return;
    }

    ticketsListEl.innerHTML = filtered.map((ticket) => {
        const id = safeNumber(ticket.id);
        const locked = acceptLocks.has(id);
        const title = escapeHtml(ticket.title || 'Ticket');
        const subject = escapeHtml(ticket.subject || 'Fara descriere');
        const player = escapeHtml(ticket.playerName || 'Unknown');
        const uid = safeNumber(ticket.playerUid);
        const createdAt = escapeHtml(ticket.createdAt || 'now');

        return `
            <article class="ticket-card">
                <div class="ticket-bg"></div>
                <div class="ticket-top">
                    <div class="ticket-identity">
                        <div class="ticket-icon">${ticketIcon()}</div>
                        <div>
                            <div class="ticket-title">#${id} · ${title}</div>
                            <div class="ticket-meta">${player} · UID ${uid}</div>
                        </div>
                    </div>
                    <div class="ticket-time">${createdAt}</div>
                </div>

                <div class="ticket-subject">${subject}</div>

                <div class="ticket-actions">
                    <button class="action-btn accept" ${locked ? 'disabled' : ''} onclick="acceptTicket(${id})">
                        <svg viewBox="0 0 24 24"><path d="M5 12l4 4L19 6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>
                        <span>${locked ? 'Processing' : 'Accept'}</span>
                    </button>
                    <button class="action-btn teleport" onclick="teleportTicket(${id})">
                        <svg viewBox="0 0 24 24"><path d="M12 21s7-5.2 7-12a7 7 0 0 0-14 0c0 6.8 7 12 7 12z" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 12.2a3 3 0 1 0 0-6 3 3 0 0 0 0 6z" fill="none" stroke="currentColor" stroke-width="2"/></svg>
                        <span>Teleport</span>
                    </button>
                    <button class="action-btn delete" onclick="deleteTicket(${id})">
                        <svg viewBox="0 0 24 24"><path d="M6 7h12M10 11v6M14 11v6M9 7l1-3h4l1 3M8 7l1 13h6l1-13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
                        <span>Delete</span>
                    </button>
                </div>
            </article>
        `;
    }).join('');
}

function openAdmin(tickets) {
    setMode('admin');
    cachedTickets = Array.isArray(tickets) ? tickets : [];
    acceptLocks.clear();

    overlayEl.classList.remove('hidden');
    adminPanelEl.classList.remove('hidden');
    userPanelEl.classList.add('hidden');

    if (ticketSearchEl) ticketSearchEl.value = '';
    renderTickets(cachedTickets);

    requestAnimationFrame(() => ticketSearchEl?.focus());
}

function createTicket() {
    const title = (ticketTitleEl.value || '').trim();
    const subject = (ticketSubjectEl.value || '').trim();

    userErrorEl.textContent = '';

    if (!title) {
        userErrorEl.textContent = 'Titlul este obligatoriu.';
        ticketTitleEl.focus();
        return;
    }

    if (!subject) {
        userErrorEl.textContent = 'Subiectul este obligatoriu.';
        ticketSubjectEl.focus();
        return;
    }

    nui('create', { title, subject });
}

function acceptTicket(id) {
    id = safeNumber(id);
    if (!id || acceptLocks.has(id)) return;

    acceptLocks.add(id);
    renderTickets(cachedTickets);
    nui('accept', { id });
}

function deleteTicket(id) {
    nui('delete', { id: safeNumber(id) });
}

function teleportTicket(id) {
    nui('teleport', { id: safeNumber(id) });
}

if (ticketSearchEl) {
    ticketSearchEl.addEventListener('input', () => renderTickets(cachedTickets));
}

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeAll();
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'setCount') setCount(data.count || 0);
    if (data.action === 'openUser') openUser();
    if (data.action === 'openAdmin') openAdmin(data.tickets || []);
    if (data.action === 'close') closeLocal();
});

window.closeAll = closeAll;
window.createTicket = createTicket;
window.acceptTicket = acceptTicket;
window.deleteTicket = deleteTicket;
window.teleportTicket = teleportTicket;

window.driftTickets = {
    setCount,
    openUser,
    openAdmin,
    closeAll,
    closeLocal
};

setTimeout(() => nui('ready'), 50);
