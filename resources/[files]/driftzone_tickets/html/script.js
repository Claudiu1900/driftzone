'use strict';

const counterEl = document.getElementById('counter');
const ticketCountEl = document.getElementById('ticketCount');
const sideTicketCountEl = document.getElementById('sideTicketCount');
const adminTicketCountEl = document.getElementById('adminTicketCount');

const overlayEl = document.getElementById('overlay');
const userPanelEl = document.getElementById('userPanel');
const adminPanelEl = document.getElementById('adminPanel');

const ticketTitleEl = document.getElementById('ticketTitle');
const ticketSubjectEl = document.getElementById('ticketSubject');
const userErrorEl = document.getElementById('userError');
const ticketsListEl = document.getElementById('ticketsList');
const ticketSearchEl = document.getElementById('ticketSearch');

let cachedTickets = [];
let acceptLocks = new Set();

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

function setCount(count) {
    const number = Number(count || 0);

    ticketCountEl.textContent = String(number);
    sideTicketCountEl.textContent = String(number);
    adminTicketCountEl.textContent = String(number);

    if (number > 0) counterEl.classList.remove('hidden');
    else counterEl.classList.add('hidden');
}

function openUser() {
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
        ? list.filter((ticket) => {
            const haystack = [
                ticket.id,
                ticket.title,
                ticket.subject,
                ticket.playerName,
                ticket.playerUid,
                ticket.createdAt
            ].join(' ').toLowerCase();

            return haystack.includes(query);
        })
        : list;

    adminTicketCountEl.textContent = String(list.length);

    if (filtered.length === 0) {
        ticketsListEl.innerHTML = `
            <div class="empty">
                <svg viewBox="0 0 64 64">
                    <path d="M14 20h36a4 4 0 0 1 4 4v6a6 6 0 0 0 0 12v6a4 4 0 0 1-4 4H14a4 4 0 0 1-4-4v-6a6 6 0 0 0 0-12v-6a4 4 0 0 1 4-4z" fill="none" stroke="currentColor" stroke-width="3"/>
                    <path d="M24 32h16" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>
                </svg>
                <b>Nu exista tickete active</b>
                <span>Lista este goală momentan.</span>
            </div>
        `;
        return;
    }

    ticketsListEl.innerHTML = filtered.map((ticket) => {
        const id = Number(ticket.id || 0);
        const locked = acceptLocks.has(id);

        return `
            <div class="ticket-card">
                <div class="ticket-glow"></div>

                <div class="ticket-top">
                    <div class="ticket-identity">
                        <div class="ticket-icon">${ticketIcon()}</div>
                        <div>
                            <div class="ticket-title">#${id} — ${escapeHtml(ticket.title)}</div>
                            <div class="ticket-meta">${escapeHtml(ticket.playerName)} · UID ${Number(ticket.playerUid || 0)}</div>
                        </div>
                    </div>
                    <div class="ticket-time">${escapeHtml(ticket.createdAt || '')}</div>
                </div>

                <div class="ticket-subject">${escapeHtml(ticket.subject)}</div>

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
            </div>
        `;
    }).join('');
}

function filterTickets() {
    renderTickets(cachedTickets);
}

function openAdmin(tickets) {
    cachedTickets = Array.isArray(tickets) ? tickets : [];

    overlayEl.classList.remove('hidden');
    adminPanelEl.classList.remove('hidden');
    userPanelEl.classList.add('hidden');

    if (ticketSearchEl) ticketSearchEl.value = '';
    renderTickets(cachedTickets);

    setTimeout(() => {
        if (document.activeElement) document.activeElement.blur();
    }, 50);
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

function createTicket() {
    const title = ticketTitleEl.value.trim();
    const subject = ticketSubjectEl.value.trim();

    userErrorEl.textContent = '';

    if (!title) {
        userErrorEl.textContent = 'Titlul este obligatoriu.';
        return;
    }

    if (!subject) {
        userErrorEl.textContent = 'Subiectul este obligatoriu.';
        return;
    }

    nui('create', { title, subject });
}

function acceptTicket(id) {
    id = Number(id || 0);
    if (!id || acceptLocks.has(id)) return;

    acceptLocks.add(id);
    renderTickets(cachedTickets);

    nui('accept', { id });

    setTimeout(() => {
        acceptLocks.delete(id);
        renderTickets(cachedTickets);
    }, 2500);
}

function deleteTicket(id) {
    nui('delete', { id: Number(id) });
}

function teleportTicket(id) {
    nui('teleport', { id: Number(id) });
}

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeAll();
});

window.driftTickets = {
    setCount,
    openUser,
    openAdmin,
    closeAll,
    closeLocal
};

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'setCount') setCount(data.count || 0);
    if (data.action === 'openUser') openUser();
    if (data.action === 'openAdmin') openAdmin(data.tickets || []);
    if (data.action === 'close') closeLocal();
});

setTimeout(() => nui('ready'), 50);
