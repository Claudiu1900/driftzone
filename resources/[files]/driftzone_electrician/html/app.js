const app = document.getElementById('app');
const repairOverlay = document.getElementById('repair');
const content = document.getElementById('content');
const tabs = document.getElementById('tabs');
const closeButton = document.getElementById('closeButton');

let state = { profile: null, shift: null };
let config = { cleanBonus: 0, levels: {}, vehicleEnabled: true };
let currentView = 'company';
let isRepairing = false;

const post = async (name, payload = {}) => {
    try {
        const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload)
        });
        return await response.json();
    } catch (_) {
        return { ok: false };
    }
};

const money = value => new Intl.NumberFormat('ro-RO').format(Number(value || 0));
const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

function getLevelConfig(level) {
    if (Array.isArray(config.levels)) {
        return config.levels[level - 1] || config.levels[level];
    }
    return config.levels?.[level] || config.levels?.[String(level)];
}

function levelProgress(profile) {
    const current = getLevelConfig(Number(profile.level || 1));
    const next = getLevelConfig(Number(profile.level || 1) + 1);
    if (!next) return 100;

    const base = Number(current?.minXp || 0);
    const needed = Number(next.minXp || base + 1) - base;
    return clamp(((Number(profile.xp || 0) - base) / needed) * 100, 0, 100);
}

function button(label, action, type = 'primary', disabled = false) {
    return `<button class="btn btn-${type}" data-action="${action}" ${disabled ? 'disabled' : ''}>${label}</button>`;
}

function renderCompany() {
    const profile = state.profile;
    const shift = state.shift;

    if (!profile) {
        return '<div class="empty"><div><div class="symbol">⚡</div><p>Se incarca profilul...</p></div></div>';
    }

    const progress = levelProgress(profile);
    const employment = profile.employed
        ? '<span class="badge live">● ANGAJAT ACTIV</span>'
        : '<span class="badge">NEANGAJAT</span>';

    let controls = '';
    if (!profile.employed) {
        controls = `${button('Angajeaza-te', 'hire')} ${button('Informatii job', 'info', 'ghost')}`;
    } else if (!shift) {
        controls = `${button('Incepe munca', 'startShift')} ${button('Demisioneaza', 'resign', 'danger')}`;
    } else {
        controls = `${button('Deschide tableta', 'openTablet', 'secondary')} ${button('Incheie tura', 'endShift', 'danger', shift.hasTools)}`;
    }

    return `
        <div class="hero">
            <article class="card">
                ${employment}
                <h1 style="margin-top:16px">Mentine orasul <span class="accent">sub tensiune</span>.</h1>
                <p>Preiei interventii de la dispecerat, folosesti duba si echipamentul companiei, repari instalatiile si castigi experienta pentru promovare.</p>
                <div class="actions">${controls}</div>
            </article>
            <article class="card">
                <h2>${profile.levelName}</h2>
                <p>Multiplicator plata: <strong class="accent">×${Number(profile.multiplier || 1).toFixed(2)}</strong></p>
                <div class="level-row"><span>${profile.xp} XP</span><span>${profile.nextLevelXp ? `${profile.nextLevelXp} XP` : 'Nivel maxim'}</span></div>
                <div class="progress"><span style="width:${progress}%"></span></div>
            </article>
        </div>

        ${profile.pendingPay > 0 ? `<div class="notice">Ai o plata restanta de $${money(profile.pendingPay)}. Sistemul va incerca automat sa o livreze.</div>` : ''}

        <div class="stats">
            <div class="stat"><span>Interventii totale</span><strong>${profile.totalJobs}</strong></div>
            <div class="stat"><span>Castiguri totale</span><strong>$${money(profile.totalEarned)}</strong></div>
            <div class="stat"><span>Ture finalizate</span><strong>${profile.shiftsCompleted}</strong></div>
            <div class="stat"><span>Ture perfecte</span><strong>${profile.cleanShifts}</strong></div>
        </div>

        <article class="card" id="jobInfo">
            <h2>Cum functioneaza jobul</h2>
            <div class="info-grid">
                <div class="info-item"><strong>1. Pregatirea</strong><span>Incepi tura, primesti uniforma si duba, apoi ridici trusa din depozit.</span></div>
                <div class="info-item"><strong>2. Interventiile</strong><span>Urmaresti tableta si repari stalpi, sigurante si panouri electrice.</span></div>
                <div class="info-item"><strong>3. Promovarea</strong><span>Castigi XP, deblochezi inalta tensiune si primesti multiplicatori salariali.</span></div>
            </div>
        </article>
    `;
}

function renderTablet() {
    const shift = state.shift;
    if (!shift) {
        return '<div class="empty"><div><div class="symbol">▣</div><h2>Nicio tura activa</h2><p>Incepe munca din meniul companiei.</p></div></div>';
    }

    const percent = shift.total ? Math.round((shift.completed / shift.total) * 100) : 0;
    const toolsBadge = shift.hasTools
        ? '<span class="badge live">TRUSA RIDICATA</span>'
        : '<span class="badge warning">RIDICA TRUSA</span>';
    const vehicleBadge = shift.vehicleReady
        ? '<span class="badge live">DUBA ACTIVA</span>'
        : '<span class="badge danger">DUBA LIPSA</span>';

    const tasks = (shift.tasks || []).map((task, index) => {
        const active = index + 1 === shift.activeIndex && !task.completed;
        const statusClass = task.completed ? 'done' : active ? 'active' : '';
        const status = task.completed ? 'Finalizat' : active ? 'Activ' : 'In asteptare';

        return `
            <article class="task ${statusClass}">
                <div class="task-index">${task.completed ? '✓' : String(index + 1).padStart(2, '0')}</div>
                <div>
                    <h3>${task.label} · ${task.area}</h3>
                    <p>${task.voltage} — ${task.description}${task.attempts ? ` · Incercari: ${task.attempts}` : ''}</p>
                </div>
                <div class="task-side">
                    <strong>$${money(task.pay)} / ${task.xp} XP</strong>
                    <small>${status}</small>
                </div>
            </article>
        `;
    }).join('');

    return `
        ${shift.badWeather ? '<div class="notice">⚠ Vreme severa detectata. Dispeceratul a adaugat interventii suplimentare.</div>' : ''}

        <div class="stats">
            <div class="stat"><span>Interventii</span><strong>${shift.completed}/${shift.total}</strong></div>
            <div class="stat"><span>Castig tura</span><strong>$${money(shift.shiftEarned)}</strong></div>
            <div class="stat"><span>Greseli</span><strong>${shift.mistakes}</strong></div>
            <div class="stat"><span>Bonus perfect</span><strong>${shift.mistakes === 0 ? `$${money(config.cleanBonus)}` : 'Pierdut'}</strong></div>
        </div>

        <article class="card">
            <div style="display:flex;justify-content:space-between;align-items:center;gap:15px;flex-wrap:wrap">
                <div>
                    <h2 style="margin-bottom:6px">Planul interventiilor</h2>
                    <p style="margin:0">Progres general: ${percent}%</p>
                </div>
                <div class="actions">
                    ${toolsBadge}
                    ${config.vehicleEnabled ? vehicleBadge : ''}
                    ${button(shift.allComplete ? 'Ruta de intoarcere' : 'Seteaza ruta', 'routeTask', 'secondary')}
                    ${config.vehicleEnabled ? button('Recupereaza duba', 'requestVehicle', 'ghost') : ''}
                </div>
            </div>
            <div class="progress" style="margin-top:15px"><span style="width:${percent}%"></span></div>
            <div class="task-list">${tasks}</div>
        </article>
    `;
}

function render() {
    document.querySelectorAll('.tab').forEach(tab => tab.classList.toggle('active', tab.dataset.view === currentView));
    content.innerHTML = currentView === 'tablet' ? renderTablet() : renderCompany();
}

function setView(view) {
    currentView = view;
    render();
}

function close() {
    if (isRepairing) return;
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
    post('close');
}

function startRepair(task) {
    if (!task) return;

    isRepairing = true;
    app.classList.add('hidden');
    repairOverlay.classList.remove('hidden');
    repairOverlay.setAttribute('aria-hidden', 'false');

    const field = document.getElementById('repairField');
    const title = document.getElementById('repairTitle');
    const voltage = document.getElementById('repairVoltage');
    const progress = document.getElementById('repairProgress');
    const percent = document.getElementById('repairPercent');
    const mistakesEl = document.getElementById('mistakes');
    const allowedEl = document.getElementById('allowedMistakes');
    const timeEl = document.getElementById('repairTime');

    field.querySelectorAll('.fault').forEach(element => element.remove());
    title.textContent = task.label || 'Stabilizare circuit';
    voltage.textContent = task.voltage || 'Joasa tensiune';
    progress.style.width = '0%';
    percent.textContent = '0%';
    mistakesEl.textContent = '0';

    const allowedMistakes = Math.max(0, Number(task.allowedMistakes ?? 2));
    allowedEl.textContent = String(allowedMistakes);

    const totalMs = Math.max(7000, Number(task.duration || 12) * 1000);
    const highVoltage = task.type === 'panel_high';
    const spawnEvery = highVoltage ? 1150 : task.type === 'fuse' ? 1450 : 1600;
    const targetLife = highVoltage ? 780 : task.type === 'fuse' ? 930 : 1080;
    const started = performance.now();

    let mistakes = 0;
    let finished = false;
    let activeFault = null;
    let spawnTimer = null;

    const removeFault = (missed = false) => {
        if (!activeFault) return;
        clearTimeout(activeFault.timeout);
        activeFault.element.remove();
        activeFault = null;

        if (missed) {
            mistakes += 1;
            mistakesEl.textContent = String(mistakes);
        }
    };

    const spawnFault = () => {
        if (finished) return;
        removeFault(true);

        const element = document.createElement('button');
        element.className = 'fault';
        element.setAttribute('aria-label', 'Avarie');
        element.style.left = `${6 + Math.random() * 84}%`;
        element.style.top = `${7 + Math.random() * 76}%`;
        element.addEventListener('click', () => removeFault(false), { once: true });
        field.appendChild(element);

        activeFault = {
            element,
            timeout: setTimeout(() => removeFault(true), targetLife)
        };
    };

    spawnFault();
    spawnTimer = setInterval(spawnFault, spawnEvery);

    const tick = now => {
        if (finished) return;

        const elapsed = now - started;
        const ratio = clamp(elapsed / totalMs, 0, 1);
        const value = Math.round(ratio * 100);

        progress.style.width = `${value}%`;
        percent.textContent = `${value}%`;
        timeEl.textContent = `${Math.max(0, Math.ceil((totalMs - elapsed) / 1000))}s`;

        if (ratio >= 1) {
            finished = true;
            clearInterval(spawnTimer);
            removeFault(false);

            setTimeout(() => {
                repairOverlay.classList.add('hidden');
                repairOverlay.setAttribute('aria-hidden', 'true');
                isRepairing = false;

                post('repairFinished', {
                    taskId: task.id,
                    nonce: task.nonce,
                    success: mistakes <= allowedMistakes,
                    mistakes
                });
            }, 300);
            return;
        }

        requestAnimationFrame(tick);
    };

    requestAnimationFrame(tick);
}

window.addEventListener('message', event => {
    const data = event.data || {};

    if (data.action === 'open') {
        state = data.state || state;
        config = data.config || config;
        currentView = data.view || 'company';
        app.classList.remove('hidden');
        app.setAttribute('aria-hidden', 'false');
        render();
    } else if (data.action === 'sync') {
        state = data.state || state;
        render();
    } else if (data.action === 'close' || data.action === 'forceClose') {
        app.classList.add('hidden');
        repairOverlay.classList.add('hidden');
        repairOverlay.setAttribute('aria-hidden', 'true');
        isRepairing = false;
    } else if (data.action === 'repair') {
        startRepair(data.task);
    }
});

tabs.addEventListener('click', event => {
    const target = event.target.closest('[data-view]');
    if (target) setView(target.dataset.view);
});

content.addEventListener('click', event => {
    const target = event.target.closest('[data-action]');
    if (!target || target.disabled) return;

    const action = target.dataset.action;
    if (action === 'openTablet') return setView('tablet');
    if (action === 'info') {
        document.getElementById('jobInfo')?.scrollIntoView({ behavior: 'smooth' });
        return;
    }

    post('action', { action });
});

closeButton.addEventListener('click', close);
window.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !isRepairing) close();
});

setInterval(() => {
    document.getElementById('clock').textContent = new Date().toLocaleTimeString('ro-RO', {
        hour: '2-digit',
        minute: '2-digit'
    });
}, 1000);
