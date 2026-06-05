'use strict';

const counterEl = document.getElementById('counter');
const ticketCountEl = document.getElementById('ticketCount');

const overlayEl = document.getElementById('overlay');
const userPanelEl = document.getElementById('userPanel');
const adminPanelEl = document.getElementById('adminPanel');

const ticketTitleEl = document.getElementById('ticketTitle');
const ticketSubjectEl = document.getElementById('ticketSubject');
const userErrorEl = document.getElementById('userError');

const ticketsListEl = document.getElementById('ticketsList');

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
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

    if (number > 0) {
        counterEl.classList.remove('hidden');
    } else {
        counterEl.classList.add('hidden');
    }
}

function openUser() {
    overlayEl.classList.remove('hidden');
    userPanelEl.classList.remove('hidden');
    adminPanelEl.classList.add('hidden');

    userErrorEl.textContent = '';
    ticketTitleEl.value = '';
    ticketSubjectEl.value = '';

    setTimeout(() => {
        if (document.activeElement) {
            document.activeElement.blur();
        }
    }, 50);
}

function renderTickets(tickets) {
    if (!Array.isArray(tickets) || tickets.length === 0) {
        ticketsListEl.innerHTML = `<div class="empty">Nu exista tickete active momentan.</div>`;
        return;
    }

    ticketsListEl.innerHTML = tickets.map((ticket) => {
        const id = Number(ticket.id || 0);

        return `
            <div class="ticket-card">
                <div class="ticket-top">
                    <div>
                        <div class="ticket-title">#${id} — ${escapeHtml(ticket.title)}</div>
                        <div class="ticket-meta">${escapeHtml(ticket.playerName)} (${Number(ticket.playerUid || 0)})</div>
                    </div>
                    <div class="ticket-meta">${escapeHtml(ticket.createdAt || '')}</div>
                </div>

                <div class="ticket-subject">${escapeHtml(ticket.subject)}</div>

                <div class="ticket-actions">
                    <button class="action-btn accept" onclick="acceptTicket(${id})">Accept</button>
                    <button class="action-btn teleport" onclick="teleportTicket(${id})">Teleport</button>
                    <button class="action-btn delete" onclick="deleteTicket(${id})">Delete</button>
                </div>
            </div>
        `;
    }).join('');
}

function openAdmin(tickets) {
    overlayEl.classList.remove('hidden');
    adminPanelEl.classList.remove('hidden');
    userPanelEl.classList.add('hidden');

    renderTickets(tickets || []);

    setTimeout(() => {
        if (document.activeElement) {
            document.activeElement.blur();
        }
    }, 50);
}

function closeAll() {
    overlayEl.classList.add('hidden');
    userPanelEl.classList.add('hidden');
    adminPanelEl.classList.add('hidden');

    nui('close');
}

function createTicket() {
    const title = ticketTitleEl.value.trim();
    const subject = ticketSubjectEl.value.trim();

    userErrorEl.textContent = '';

    if (!title) {
        userErrorEl.textContent = 'Titlul este obligatoriu!';
        return;
    }

    if (!subject) {
        userErrorEl.textContent = 'Subiectul este obligatoriu!';
        return;
    }

    nui('create', {
        title,
        subject
    });
}

function acceptTicket(id) {
    nui('accept', { id: Number(id) });
}

function deleteTicket(id) {
    nui('delete', { id: Number(id) });
}

function teleportTicket(id) {
    nui('teleport', { id: Number(id) });
}

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        closeAll();
    }
});

window.driftTickets = {
    setCount,
    openUser,
    openAdmin,
    closeAll
};

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'setCount') {
        setCount(data.count || 0);
    }

    if (data.action === 'openUser') {
        openUser();
    }

    if (data.action === 'openAdmin') {
        openAdmin(data.tickets || []);
    }

    if (data.action === 'close') {
        overlayEl.classList.add('hidden');
        userPanelEl.classList.add('hidden');
        adminPanelEl.classList.add('hidden');
    }
});

setTimeout(() => {
    nui('ready');
}, 50);
