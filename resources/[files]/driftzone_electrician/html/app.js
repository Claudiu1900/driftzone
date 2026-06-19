const app = document.getElementById('app');
const repairOverlay = document.getElementById('repair');
const content = document.getElementById('content');
const tabs = document.getElementById('tabs');
const closeButton = document.getElementById('closeButton');
const repairField = document.getElementById('repairField');
const repairInstruction = document.getElementById('repairInstruction');
const repairTitle = document.getElementById('repairTitle');
const repairVoltage = document.getElementById('repairVoltage');
const repairProgress = document.getElementById('repairProgress');
const repairPercent = document.getElementById('repairPercent');
const mistakesElement = document.getElementById('mistakes');
const allowedMistakesElement = document.getElementById('allowedMistakes');
const repairTime = document.getElementById('repairTime');

let state = { profile: null, shift: null };
let config = { cleanBonus: 0, levels: {}, vehicleEnabled: true };
let currentView = 'company';
let isRepairing = false;
let repairSession = null;

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
const shuffle = input => {
    const output = [...input];
    for (let index = output.length - 1; index > 0; index -= 1) {
        const randomIndex = Math.floor(Math.random() * (index + 1));
        [output[index], output[randomIndex]] = [output[randomIndex], output[index]];
    }
    return output;
};

const minigameNames = {
    wires: 'Conectare fire',
    switches: 'Configurare întrerupătoare',
    fuses: 'Înlocuire siguranțe',
    sequence: 'Secvență de diagnostic',
    voltage: 'Calibrare tensiune'
};

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
        return '<div class="empty"><div><div class="symbol">⚡</div><p>Se încarcă profilul...</p></div></div>';
    }

    const progress = levelProgress(profile);
    const employment = profile.employed
        ? '<span class="badge live">● ANGAJAT ACTIV</span>'
        : '<span class="badge">NEANGAJAT</span>';

    let controls = '';
    if (!profile.employed) {
        controls = `${button('Angajează-te', 'hire')} ${button('Informații job', 'info', 'ghost')}`;
    } else if (!shift) {
        controls = `${button('Începe munca', 'startShift')} ${button('Demisionează', 'resign', 'danger')}`;
    } else {
        controls = `${button('Deschide tableta', 'openTablet', 'secondary')} ${button('Încheie tura', 'endShift', 'danger', shift.hasTools)}`;
    }

    return `
        <div class="hero">
            <article class="card">
                ${employment}
                <h1 style="margin-top:16px">Menține orașul <span class="accent">sub tensiune</span>.</h1>
                <p>Preiei intervenții de la dispecerat, folosești duba și echipamentul companiei, repari instalațiile și câștigi experiență pentru promovare.</p>
                <div class="actions">${controls}</div>
            </article>
            <article class="card">
                <h2>${profile.levelName}</h2>
                <p>Multiplicator plată: <strong class="accent">×${Number(profile.multiplier || 1).toFixed(2)}</strong></p>
                <div class="level-row"><span>${profile.xp} XP</span><span>${profile.nextLevelXp ? `${profile.nextLevelXp} XP` : 'Nivel maxim'}</span></div>
                <div class="progress"><span style="width:${progress}%"></span></div>
            </article>
        </div>

        ${profile.pendingPay > 0 ? `<div class="notice">Ai o plată restantă de $${money(profile.pendingPay)}. Sistemul va încerca automat să o livreze.</div>` : ''}

        <div class="stats">
            <div class="stat"><span>Intervenții totale</span><strong>${profile.totalJobs}</strong></div>
            <div class="stat"><span>Câștiguri totale</span><strong>$${money(profile.totalEarned)}</strong></div>
            <div class="stat"><span>Ture finalizate</span><strong>${profile.shiftsCompleted}</strong></div>
            <div class="stat"><span>Ture perfecte</span><strong>${profile.cleanShifts}</strong></div>
        </div>

        <article class="card" id="jobInfo">
            <h2>Cum funcționează jobul</h2>
            <div class="info-grid">
                <div class="info-item"><strong>1. Pregătirea</strong><span>Începi tura, primești uniforma și duba marcată permanent pe hartă, apoi ridici trusa.</span></div>
                <div class="info-item"><strong>2. Intervențiile</strong><span>Conectezi fire, schimbi siguranțe, configurezi întrerupătoare și calibrezi tensiunea.</span></div>
                <div class="info-item"><strong>3. Promovarea</strong><span>Câștigi XP, deblochezi înalta tensiune și primești multiplicatori salariali.</span></div>
            </div>
        </article>
    `;
}

function renderTablet() {
    const shift = state.shift;
    if (!shift) {
        return '<div class="empty"><div><div class="symbol">▣</div><h2>Nicio tură activă</h2><p>Începe munca din meniul companiei.</p></div></div>';
    }

    const percent = shift.total ? Math.round((shift.completed / shift.total) * 100) : 0;
    const toolsBadge = shift.hasTools
        ? '<span class="badge live">TRUSĂ RIDICATĂ</span>'
        : '<span class="badge warning">RIDICĂ TRUSA</span>';
    const vehicleBadge = shift.vehicleReady
        ? '<span class="badge live">DUBĂ MARCATĂ PE HARTĂ</span>'
        : '<span class="badge danger">DUBĂ LIPSĂ</span>';

    const tasks = (shift.tasks || []).map((task, index) => {
        const active = index + 1 === shift.activeIndex && !task.completed;
        const statusClass = task.completed ? 'done' : active ? 'active' : '';
        const status = task.completed ? 'Finalizat' : active ? 'Activ' : 'În așteptare';
        const procedure = minigameNames[task.minigame] || 'Procedură tehnică';

        return `
            <article class="task ${statusClass}">
                <div class="task-index">${task.completed ? '✓' : String(index + 1).padStart(2, '0')}</div>
                <div>
                    <h3>${task.label} · ${task.area}</h3>
                    <p>${task.voltage} — ${procedure} — ${task.description}${task.attempts ? ` · Încercări: ${task.attempts}` : ''}</p>
                </div>
                <div class="task-side">
                    <strong>$${money(task.pay)} / ${task.xp} XP</strong>
                    <small>${status}</small>
                </div>
            </article>
        `;
    }).join('');

    return `
        ${shift.badWeather ? '<div class="notice">⚠ Vreme severă detectată. Dispeceratul a adăugat intervenții suplimentare.</div>' : ''}

        <div class="stats">
            <div class="stat"><span>Intervenții</span><strong>${shift.completed}/${shift.total}</strong></div>
            <div class="stat"><span>Câștig tură</span><strong>$${money(shift.shiftEarned)}</strong></div>
            <div class="stat"><span>Greșeli</span><strong>${shift.mistakes}</strong></div>
            <div class="stat"><span>Bonus perfect</span><strong>${shift.mistakes === 0 ? `$${money(config.cleanBonus)}` : 'Pierdut'}</strong></div>
        </div>

        <article class="card">
            <div style="display:flex;justify-content:space-between;align-items:center;gap:15px;flex-wrap:wrap">
                <div>
                    <h2 style="margin-bottom:6px">Planul intervențiilor</h2>
                    <p style="margin:0">Progres general: ${percent}%</p>
                </div>
                <div class="actions">
                    ${toolsBadge}
                    ${config.vehicleEnabled ? vehicleBadge : ''}
                    ${button(shift.allComplete ? 'Ruta de întoarcere' : 'Setează ruta', 'routeTask', 'secondary')}
                    ${config.vehicleEnabled ? button('Recuperează duba', 'requestVehicle', 'ghost') : ''}
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

function setRepairInstruction(text) {
    repairInstruction.textContent = text;
}

function registerRepairCleanup(callback) {
    if (repairSession && typeof callback === 'function') {
        repairSession.cleanups.push(callback);
    }
}

function destroyRepairSession() {
    if (!repairSession) return;
    for (const cleanup of repairSession.cleanups) {
        try { cleanup(); } catch (_) { /* no-op */ }
    }
    repairSession = null;
}

function flashError(element) {
    if (!element) return;
    element.classList.remove('shake');
    void element.offsetWidth;
    element.classList.add('shake');
    window.setTimeout(() => element.classList.remove('shake'), 320);
}

function addMistake(element) {
    if (!repairSession || repairSession.finishing) return;
    repairSession.mistakes += 1;
    mistakesElement.textContent = String(repairSession.mistakes);
    flashError(element || repairField);

    if (repairSession.mistakes > repairSession.allowedMistakes) {
        queueRepairFinish(false, 'Procedura a eșuat: prea multe greșeli.');
    }
}

function showRepairResult(success, message) {
    const panel = document.createElement('div');
    panel.className = `result-panel ${success ? 'success' : 'failure'}`;
    panel.innerHTML = `<div><strong>${success ? 'CIRCUIT STABIL' : 'PROCEDURĂ EȘUATĂ'}</strong><span>${message}</span></div>`;
    repairField.appendChild(panel);
}

function queueRepairFinish(success, message) {
    if (!repairSession || repairSession.finishing) return;
    repairSession.finishing = true;
    repairSession.finalSuccess = success === true && repairSession.mistakes <= repairSession.allowedMistakes;

    repairField.classList.toggle('solved', repairSession.finalSuccess);
    repairField.classList.toggle('failed', !repairSession.finalSuccess);
    showRepairResult(repairSession.finalSuccess, message || (repairSession.finalSuccess ? 'Verificarea finală este în curs.' : 'Circuitul nu a trecut testul.'));

    const elapsed = performance.now() - repairSession.startedAt;
    const delay = Math.max(350, repairSession.minimumMs - elapsed);
    const timeout = window.setTimeout(finishRepair, delay);
    registerRepairCleanup(() => window.clearTimeout(timeout));
}

function finishRepair() {
    if (!repairSession) return;

    const payload = {
        taskId: repairSession.task.id,
        nonce: repairSession.task.nonce,
        success: repairSession.finalSuccess === true,
        mistakes: repairSession.mistakes
    };

    destroyRepairSession();
    isRepairing = false;
    repairOverlay.classList.add('hidden');
    repairOverlay.setAttribute('aria-hidden', 'true');
    repairField.innerHTML = '';
    repairField.classList.remove('solved', 'failed');
    post('repairFinished', payload);
}

function startRepairTimer() {
    const update = () => {
        if (!repairSession) return;
        const elapsed = performance.now() - repairSession.startedAt;
        const ratio = clamp(elapsed / repairSession.totalMs, 0, 1);
        const remaining = Math.max(0, repairSession.totalMs - elapsed);
        const value = Math.round(ratio * 100);

        repairProgress.style.width = `${value}%`;
        repairPercent.textContent = `${value}%`;
        repairTime.textContent = `${Math.ceil(remaining / 1000)}s`;

        if (remaining <= 0 && !repairSession.finishing) {
            queueRepairFinish(false, 'Timpul procedurii a expirat.');
        }
    };

    update();
    const interval = window.setInterval(update, 100);
    registerRepairCleanup(() => window.clearInterval(interval));
}

function renderWires(task) {
    const palette = [
        { key: 'red', name: 'ROȘU', color: '#ff5b67' },
        { key: 'blue', name: 'ALBASTRU', color: '#2ecbff' },
        { key: 'yellow', name: 'GALBEN', color: '#ffc400' },
        { key: 'green', name: 'VERDE', color: '#47e69b' },
        { key: 'purple', name: 'MOV', color: '#b58cff' },
        { key: 'orange', name: 'PORTOCALIU', color: '#ff9c45' }
    ];
    const count = clamp(3 + Number(task.difficulty || 1), 4, 6);
    const wires = palette.slice(0, count);
    const rightWires = shuffle(wires);

    repairField.innerHTML = `
        <div class="game-shell">
            <div class="wire-board" id="wireBoard">
                <svg class="wire-svg" id="wireSvg"></svg>
                <div class="wire-column left">
                    ${wires.map(wire => `<button class="wire-terminal" data-side="left" data-wire="${wire.key}" style="--wire:${wire.color}"><span class="wire-dot"></span>${wire.name}</button>`).join('')}
                </div>
                <div class="wire-column right">
                    ${rightWires.map(wire => `<button class="wire-terminal" data-side="right" data-wire="${wire.key}" style="--wire:${wire.color}"><span class="wire-dot"></span>${wire.name}</button>`).join('')}
                </div>
            </div>
        </div>
    `;
    setRepairInstruction('Selectează un fir din stânga, apoi conectează-l la culoarea identică din dreapta.');

    const board = document.getElementById('wireBoard');
    const svg = document.getElementById('wireSvg');
    let selected = null;
    let connected = 0;

    const drawLine = (left, right, color) => {
        const boardRect = board.getBoundingClientRect();
        const leftRect = left.getBoundingClientRect();
        const rightRect = right.getBoundingClientRect();
        svg.setAttribute('viewBox', `0 0 ${boardRect.width} ${boardRect.height}`);

        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', String(leftRect.right - boardRect.left));
        line.setAttribute('y1', String(leftRect.top + leftRect.height / 2 - boardRect.top));
        line.setAttribute('x2', String(rightRect.left - boardRect.left));
        line.setAttribute('y2', String(rightRect.top + rightRect.height / 2 - boardRect.top));
        line.setAttribute('stroke', color);
        svg.appendChild(line);
    };

    board.addEventListener('click', event => {
        if (!repairSession || repairSession.finishing) return;
        const terminal = event.target.closest('.wire-terminal');
        if (!terminal || terminal.classList.contains('connected')) return;

        if (terminal.dataset.side === 'left') {
            board.querySelectorAll('.wire-terminal.selected').forEach(element => element.classList.remove('selected'));
            selected = terminal;
            selected.classList.add('selected');
            return;
        }

        if (!selected) {
            setRepairInstruction('Alege mai întâi capătul firului din partea stângă.');
            flashError(terminal);
            return;
        }

        if (selected.dataset.wire === terminal.dataset.wire) {
            const color = selected.style.getPropertyValue('--wire') || '#ffffff';
            selected.classList.remove('selected');
            selected.classList.add('connected');
            terminal.classList.add('connected');
            drawLine(selected, terminal, color);
            selected = null;
            connected += 1;
            setRepairInstruction(`Conexiuni corecte: ${connected}/${count}`);

            if (connected >= count) {
                queueRepairFinish(true, 'Toate firele au fost conectate corect.');
            }
        } else {
            addMistake(terminal);
            selected.classList.remove('selected');
            selected = null;
            setRepairInstruction('Culorile nu corespund. Verifică din nou conexiunile.');
        }
    });
}

function renderSwitches(task) {
    const count = Number(task.difficulty || 1) >= 3 ? 10 : Number(task.difficulty || 1) === 2 ? 8 : 6;
    let targets = Array.from({ length: count }, () => Math.random() > 0.5);
    if (targets.every(Boolean)) targets[0] = false;
    if (targets.every(value => !value)) targets[0] = true;
    const current = Array.from({ length: count }, () => Math.random() > 0.72);
    const columns = Math.min(5, count);

    repairField.innerHTML = `
        <div class="game-shell switch-game">
            <span class="game-label">CONFIGURAȚIA CERUTĂ</span>
            <div class="target-strip" style="grid-template-columns:repeat(${columns}, minmax(54px, 1fr))">
                ${targets.map((target, index) => `<div class="target-cell"><span class="target-led ${target ? 'on' : ''}"></span><b>S${index + 1}</b></div>`).join('')}
            </div>
            <div class="switch-grid" style="grid-template-columns:repeat(${columns}, minmax(54px, 1fr))">
                ${current.map((enabled, index) => `<button class="breaker ${enabled ? 'on' : ''}" data-switch="${index}">S${index + 1}</button>`).join('')}
            </div>
            <div class="game-footer">
                <span class="game-hint">Verde = ON · Gri = OFF</span>
                <button class="game-button" id="testSwitches">TESTEAZĂ CIRCUITUL</button>
            </div>
        </div>
    `;
    setRepairInstruction('Configurează întrerupătoarele exact ca modelul luminos, apoi testează circuitul.');

    repairField.querySelectorAll('.breaker').forEach(breaker => {
        breaker.addEventListener('click', () => {
            if (!repairSession || repairSession.finishing) return;
            const index = Number(breaker.dataset.switch);
            current[index] = !current[index];
            breaker.classList.toggle('on', current[index]);
        });
    });

    document.getElementById('testSwitches').addEventListener('click', event => {
        if (!repairSession || repairSession.finishing) return;
        const incorrect = [];
        current.forEach((value, index) => {
            if (value !== targets[index]) incorrect.push(index);
        });

        if (incorrect.length === 0) {
            queueRepairFinish(true, 'Întrerupătoarele sunt configurate corect.');
            return;
        }

        addMistake(event.currentTarget);
        setRepairInstruction(`${incorrect.length} întrerupătoare sunt în poziția greșită.`);
        incorrect.forEach(index => {
            const element = repairField.querySelector(`[data-switch="${index}"]`);
            element?.classList.add('wrong');
            window.setTimeout(() => element?.classList.remove('wrong'), 650);
        });
    });
}

function renderFuses(task) {
    const difficulty = Number(task.difficulty || 1);
    const count = difficulty >= 3 ? 12 : difficulty === 2 ? 10 : 8;
    const burntCount = difficulty >= 3 ? 5 : difficulty === 2 ? 4 : 3;
    const burntIndexes = new Set(shuffle(Array.from({ length: count }, (_, index) => index)).slice(0, burntCount));
    const replaced = new Set();

    repairField.innerHTML = `
        <div class="game-shell fuse-game">
            <span class="game-label">PANOU DE SIGURANȚE</span>
            <div class="fuse-grid">
                ${Array.from({ length: count }, (_, index) => `
                    <button class="fuse-slot ${burntIndexes.has(index) ? 'burnt' : ''}" data-fuse="${index}">
                        <span class="fuse-body"></span>
                        F${String(index + 1).padStart(2, '0')}
                    </button>
                `).join('')}
            </div>
            <div class="game-footer">
                <span class="game-hint" id="fuseCounter">Înlocuite: 0/${burntCount}</span>
                <button class="game-button" id="powerFuses" disabled>PORNEȘTE ALIMENTAREA</button>
            </div>
        </div>
    `;
    setRepairInstruction('Identifică siguranțele arse după carcasa deteriorată și înlocuiește-le.');

    const powerButton = document.getElementById('powerFuses');
    const counter = document.getElementById('fuseCounter');

    repairField.querySelectorAll('.fuse-slot').forEach(slot => {
        slot.addEventListener('click', () => {
            if (!repairSession || repairSession.finishing) return;
            const index = Number(slot.dataset.fuse);
            if (replaced.has(index)) return;

            if (burntIndexes.has(index)) {
                replaced.add(index);
                slot.classList.remove('burnt');
                slot.classList.add('replaced');
                counter.textContent = `Înlocuite: ${replaced.size}/${burntCount}`;
                if (replaced.size >= burntCount) {
                    powerButton.disabled = false;
                    setRepairInstruction('Siguranțele arse au fost înlocuite. Pornește alimentarea.');
                }
            } else {
                addMistake(slot);
                slot.classList.add('bad');
                window.setTimeout(() => slot.classList.remove('bad'), 550);
                setRepairInstruction('Această siguranță este funcțională. Verifică urmele de ardere.');
            }
        });
    });

    powerButton.addEventListener('click', () => {
        if (!repairSession || repairSession.finishing) return;
        if (replaced.size !== burntCount) {
            addMistake(powerButton);
            return;
        }
        queueRepairFinish(true, 'Siguranțele au fost înlocuite, iar alimentarea este stabilă.');
    });
}

function renderSequence(task) {
    const difficulty = Number(task.difficulty || 1);
    const count = clamp(4 + difficulty, 5, 7);
    const keys = Array.from({ length: count }, (_, index) => index + 1);
    const sequence = shuffle(keys);
    let position = 0;
    let locked = true;

    repairField.innerHTML = `
        <div class="game-shell sequence-game">
            <span class="game-label">SECVENȚĂ DE REPORNIRE</span>
            <div class="sequence-display" id="sequenceDisplay">${sequence.join(' · ')}</div>
            <div class="sequence-buttons">
                ${keys.map(key => `<button class="sequence-key" data-key="${key}">${key}</button>`).join('')}
            </div>
            <div class="game-footer"><span class="game-hint" id="sequenceProgress">Memorează ordinea...</span></div>
        </div>
    `;
    setRepairInstruction('Memorează secvența afișată, apoi apasă releele în aceeași ordine.');

    const display = document.getElementById('sequenceDisplay');
    const progress = document.getElementById('sequenceProgress');

    const hideSequence = () => {
        display.textContent = 'SECVENȚĂ ASCUNSĂ';
        display.classList.add('hidden-sequence');
        progress.textContent = `Progres: ${position}/${count}`;
        locked = false;
    };

    let revealTimeout = window.setTimeout(hideSequence, Math.max(1200, 2300 - difficulty * 250));
    registerRepairCleanup(() => window.clearTimeout(revealTimeout));

    const revealAgain = () => {
        locked = true;
        display.textContent = sequence.join(' · ');
        display.classList.remove('hidden-sequence');
        progress.textContent = 'Secvența a fost resetată.';
        revealTimeout = window.setTimeout(hideSequence, 1100);
    };

    repairField.querySelectorAll('.sequence-key').forEach(keyButton => {
        keyButton.addEventListener('click', () => {
            if (!repairSession || repairSession.finishing || locked) return;
            const value = Number(keyButton.dataset.key);

            if (value === sequence[position]) {
                keyButton.classList.add('correct');
                position += 1;
                progress.textContent = `Progres: ${position}/${count}`;

                if (position >= count) {
                    queueRepairFinish(true, 'Secvența de repornire a fost executată corect.');
                }
                return;
            }

            addMistake(keyButton);
            position = 0;
            repairField.querySelectorAll('.sequence-key').forEach(element => element.classList.remove('correct'));
            setRepairInstruction('Ordine greșită. Secvența va fi afișată din nou.');
            revealAgain();
        });
    });
}

function renderVoltage(task) {
    const difficulty = Number(task.difficulty || 1);
    const roundsRequired = 2 + difficulty;
    const targetWidth = 18 - difficulty * 2;
    let rounds = 0;
    let targetStart = 30;
    let needlePosition = 0;
    let animationFrame = 0;
    const animationStarted = performance.now();
    const speed = 0.0042 + difficulty * 0.0008;

    repairField.innerHTML = `
        <div class="game-shell voltage-game">
            <span class="game-label">CALIBRARE ÎN SARCINĂ</span>
            <div class="voltage-rounds" id="voltageRounds">Stabilizări: 0/${roundsRequired}</div>
            <div class="meter">
                <div class="meter-scale"></div>
                <div class="meter-target" id="meterTarget"></div>
                <div class="meter-needle" id="meterNeedle"></div>
            </div>
            <div class="voltage-readout"><span>0 V</span><span>ZONĂ STABILĂ</span><span>240 V</span></div>
            <div class="game-footer">
                <span class="game-hint">Oprește acul în zona verde.</span>
                <button class="game-button" id="stabilizeVoltage">STABILIZEAZĂ</button>
            </div>
        </div>
    `;
    setRepairInstruction('Apasă STABILIZEAZĂ când indicatorul alb se află în zona verde.');

    const target = document.getElementById('meterTarget');
    const needle = document.getElementById('meterNeedle');
    const roundElement = document.getElementById('voltageRounds');
    const stabilize = document.getElementById('stabilizeVoltage');

    const randomizeTarget = () => {
        targetStart = 12 + Math.random() * (76 - targetWidth);
        target.style.left = `${targetStart}%`;
        target.style.width = `${targetWidth}%`;
    };

    const animate = now => {
        if (!repairSession || repairSession.finishing) return;
        const phase = (now - animationStarted) * speed;
        needlePosition = (Math.sin(phase) + 1) * 50;
        needle.style.left = `${needlePosition}%`;
        animationFrame = requestAnimationFrame(animate);
    };

    randomizeTarget();
    animationFrame = requestAnimationFrame(animate);
    registerRepairCleanup(() => cancelAnimationFrame(animationFrame));

    stabilize.addEventListener('click', () => {
        if (!repairSession || repairSession.finishing) return;
        const inside = needlePosition >= targetStart && needlePosition <= targetStart + targetWidth;

        if (inside) {
            rounds += 1;
            roundElement.textContent = `Stabilizări: ${rounds}/${roundsRequired}`;
            stabilize.textContent = rounds >= roundsRequired ? 'STABIL' : 'URMĂTOAREA FAZĂ';

            if (rounds >= roundsRequired) {
                queueRepairFinish(true, 'Tensiunea a fost calibrată în toate fazele.');
                return;
            }

            randomizeTarget();
            setRepairInstruction('Fază stabilizată. Repetă calibrarea pentru următoarea fază.');
        } else {
            addMistake(stabilize);
            setRepairInstruction('Valoarea este în afara zonei stabile. Încearcă din nou.');
        }
    });
}

function resolveMinigame(task) {
    if (minigameNames[task.minigame]) return task.minigame;
    if (task.type === 'fuse') return 'fuses';
    if (task.type === 'panel_low') return 'wires';
    if (task.type === 'panel_high') return 'switches';
    return 'sequence';
}

function startRepair(task) {
    if (!task || isRepairing) return;

    isRepairing = true;
    app.classList.add('hidden');
    app.setAttribute('aria-hidden', 'true');
    repairOverlay.classList.remove('hidden');
    repairOverlay.setAttribute('aria-hidden', 'false');
    repairField.innerHTML = '';
    repairField.classList.remove('solved', 'failed');

    const totalMs = Math.max(8000, Number(task.duration || 20) * 1000);
    const minimumMs = Math.min(totalMs - 500, Math.max(2000, Number(task.minimumDuration || 5) * 1000));
    repairSession = {
        task,
        startedAt: performance.now(),
        totalMs,
        minimumMs,
        allowedMistakes: Math.max(0, Number(task.allowedMistakes ?? 2)),
        mistakes: 0,
        finishing: false,
        finalSuccess: false,
        cleanups: []
    };

    repairTitle.textContent = task.label || 'Stabilizare circuit';
    repairVoltage.textContent = task.voltage || 'Joasă tensiune';
    repairProgress.style.width = '0%';
    repairPercent.textContent = '0%';
    mistakesElement.textContent = '0';
    allowedMistakesElement.textContent = String(repairSession.allowedMistakes);
    repairTime.textContent = `${Math.ceil(totalMs / 1000)}s`;

    const minigame = resolveMinigame(task);
    if (minigame === 'wires') renderWires(task);
    else if (minigame === 'switches') renderSwitches(task);
    else if (minigame === 'fuses') renderFuses(task);
    else if (minigame === 'voltage') renderVoltage(task);
    else renderSequence(task);

    startRepairTimer();
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
        app.setAttribute('aria-hidden', 'true');
        repairOverlay.classList.add('hidden');
        repairOverlay.setAttribute('aria-hidden', 'true');
        destroyRepairSession();
        isRepairing = false;
        repairField.innerHTML = '';
        repairField.classList.remove('solved', 'failed');
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
