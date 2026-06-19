const menu = document.getElementById('menu');
const game = document.getElementById('game');
const actions = document.getElementById('actions');
const gameArea = document.getElementById('gameArea');
const gameTitle = document.getElementById('gameTitle');
const gameDescription = document.getElementById('gameDescription');
const urgentBadge = document.getElementById('urgentBadge');
const gameLives = document.getElementById('gameLives');
const gameHint = document.getElementById('gameHint');

let activeTask = null;
let cleanupGame = () => {};
let lives = 3;
let finished = false;
let gameOpenedAt = 0;
let menuBusy = false;

const post = (endpoint, data = {}) => fetch(`https://${GetParentResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
}).then(response => response.json()).catch(error => {
    console.error(`[driftzone_mechanic] NUI ${endpoint}:`, error);
    return { ok: false };
});

const money = value => `$${Number(value || 0).toLocaleString('ro-RO')}`;

function setLives(value) {
    lives = value;
    gameLives.textContent = Array.from({ length: 3 }, (_, index) => index < lives ? '●' : '○').join(' ');
}

function mistake(message = 'Procedură greșită.') {
    setLives(lives - 1);
    gameHint.textContent = message;
    document.querySelector('.game-panel')?.classList.add('shake');
    setTimeout(() => document.querySelector('.game-panel')?.classList.remove('shake'), 300);
    if (lives <= 0) finishGame(false);
}

function finishGame(success) {
    if (finished) return;
    finished = true;
    cleanupGame();

    const sendResult = () => post('gameResult', { success });
    if (!success) {
        sendResult();
        return;
    }

    gameHint.textContent = 'Procedură finalizată. Se verifică lucrarea…';
    const remaining = Math.max(0, 2700 - (Date.now() - gameOpenedAt));
    setTimeout(sendResult, remaining);
}

function button(label, action, className = 'action-button') {
    const element = document.createElement('button');
    element.className = className;
    element.textContent = label;
    element.addEventListener('click', () => {
        if (menuBusy) return;
        post('menuAction', { action });
    });
    return element;
}


function setMenuBusy(busy) {
    menuBusy = Boolean(busy);
    actions.querySelectorAll('button').forEach(element => {
        element.disabled = menuBusy;
    });
}

function renderMenu(profile) {
    document.getElementById('rankName').textContent = profile.rankName;
    document.getElementById('xpBar').style.width = `${profile.xpProgress || 0}%`;
    document.getElementById('xpText').textContent = profile.nextRankName ? `${profile.currentRankXP} / ${profile.neededRankXP} XP` : `${profile.xp} XP · MAX`;
    document.getElementById('nextRank').textContent = profile.nextRankName || 'Rang maxim';
    document.getElementById('totalJobs').textContent = Number(profile.totalJobs || 0).toLocaleString('ro-RO');
    document.getElementById('totalEarnings').textContent = money(profile.totalEarnings);
    document.getElementById('shiftMistakes').textContent = profile.shiftMistakes || 0;

    const wallet = document.getElementById('internalWallet');
    if (profile.framework === 'internal') {
        wallet.classList.remove('hidden');
        wallet.textContent = `Mod intern activ · sold acumulat: ${money(profile.internalWallet)}`;
    } else {
        wallet.classList.add('hidden');
    }

    actions.innerHTML = '';
    menuBusy = false;
    if (!profile.employed) {
        actions.append(button('Angajează-te', 'hire'));
    } else if (profile.onDuty) {
        actions.append(button('Încheie tura', 'stop'));
        actions.append(button('Continuă munca', 'close', 'action-button secondary'));
    } else {
        actions.append(button('Începe tura', 'start'));
        actions.append(button('Demisionează', 'resign', 'action-button danger'));
    }
}

function baseGame(task) {
    activeTask = task;
    finished = false;
    gameOpenedAt = Date.now();
    cleanupGame();
    cleanupGame = () => {};
    setLives(3);
    gameArea.innerHTML = '';
    gameTitle.textContent = task.label;
    gameDescription.textContent = task.description;
    gameHint.textContent = 'Finalizează procedura fără greșeli.';
    urgentBadge.classList.toggle('hidden', !task.urgent);
    menu.classList.add('hidden');
    game.classList.remove('hidden');
}

function diagnosticGame() {
    const symbols = ['⚙', 'ϟ', 'Δ', 'Ω', '⌁'];
    const sequence = Array.from({ length: 4 }, () => symbols[Math.floor(Math.random() * symbols.length)]);
    let index = 0;

    gameArea.innerHTML = `<div class="game-card"><p class="instruction">Memorează secvența de erori.</p><div class="sequence" id="preview"></div><div class="diagnostic-grid hidden" id="choices"></div></div>`;
    const preview = document.getElementById('preview');
    sequence.forEach(symbol => {
        const item = document.createElement('div');
        item.className = 'symbol-button active';
        item.textContent = symbol;
        preview.append(item);
    });

    setTimeout(() => {
        preview.classList.add('hidden');
        const choices = document.getElementById('choices');
        choices.classList.remove('hidden');
        symbols.forEach(symbol => {
            const item = document.createElement('button');
            item.className = 'symbol-button';
            item.textContent = symbol;
            item.onclick = () => {
                if (symbol === sequence[index]) {
                    index += 1;
                    gameHint.textContent = `Corect: ${index}/${sequence.length}`;
                    if (index === sequence.length) finishGame(true);
                } else {
                    index = 0;
                    mistake('Secvență greșită. Reîncepe de la primul simbol.');
                }
            };
            choices.append(item);
        });
    }, 1900);
}

function movingMeterGame(mode) {
    let position = 0;
    let direction = 1;
    let hits = 0;
    const speed = mode === 'battery' ? 1.35 : 1.85;

    gameArea.innerHTML = `<div class="game-card"><p class="instruction">Oprește indicatorul în zona verde de trei ori.</p><div class="meter"><div class="safe-zone"></div><div class="needle"></div></div><button class="primary-game-button" id="meterHit">CALIBREAZĂ</button><div class="counter" id="meterCounter">0 / 3 calibrări</div></div>`;
    const needle = gameArea.querySelector('.needle');
    const counter = document.getElementById('meterCounter');
    const interval = setInterval(() => {
        position += direction * speed;
        if (position >= 99 || position <= 0) direction *= -1;
        needle.style.left = `${position}%`;
    }, 16);
    cleanupGame = () => clearInterval(interval);

    document.getElementById('meterHit').onclick = () => {
        if (position >= 42 && position <= 60) {
            hits += 1;
            counter.textContent = `${hits} / 3 calibrări`;
            gameHint.textContent = 'Calibrare corectă.';
            position = Math.random() * 20;
            if (hits >= 3) finishGame(true);
        } else {
            mistake('Valoarea este în afara zonei sigure.');
        }
    };
}

function tireGame() {
    const angles = [-90, -18, 54, 126, 198];
    const order = [1, 2, 3, 4, 5].sort(() => Math.random() - 0.5);
    let expected = 1;

    gameArea.innerHTML = `<div class="game-card"><p class="instruction">Apasă prezoanele în ordinea 1 → 5.</p><div class="wheel" id="wheel"></div></div>`;
    const wheel = document.getElementById('wheel');
    angles.forEach((angle, index) => {
        const bolt = document.createElement('button');
        const radius = 86;
        const radians = angle * Math.PI / 180;
        bolt.className = 'bolt';
        bolt.textContent = order[index];
        bolt.style.left = `${135 + Math.cos(radians) * radius}px`;
        bolt.style.top = `${135 + Math.sin(radians) * radius}px`;
        bolt.onclick = () => {
            const value = Number(bolt.textContent);
            if (value === expected) {
                bolt.classList.add('done');
                bolt.disabled = true;
                expected += 1;
                if (expected === 6) finishGame(true);
            } else {
                mistake(`Trebuia strâns prezonul ${expected}.`);
            }
        };
        wheel.append(bolt);
    });
}

function oilGame() {
    let level = 0;
    let filling = false;
    let raf;

    gameArea.innerHTML = `<div class="game-card"><p class="instruction">Ține apăsat și eliberează când nivelul este între marcajele verzi.</p><div class="fill-tank"><div class="target-line"></div><div class="fill-level"></div></div><button class="primary-game-button" id="fillButton">ȚINE APĂSAT</button></div>`;
    const fillLevel = gameArea.querySelector('.fill-level');
    const fillButton = document.getElementById('fillButton');

    const animate = () => {
        if (!filling) return;
        level = Math.min(100, level + 0.55);
        fillLevel.style.height = `${level}%`;
        if (level >= 100) {
            filling = false;
            mistake('Ai depășit nivelul maxim.');
            level = 0;
            fillLevel.style.height = '0%';
            return;
        }
        raf = requestAnimationFrame(animate);
    };

    const start = event => { event.preventDefault(); if (finished) return; filling = true; raf = requestAnimationFrame(animate); };
    const stop = event => {
        event.preventDefault();
        if (!filling) return;
        filling = false;
        cancelAnimationFrame(raf);
        if (level >= 78 && level <= 92) finishGame(true);
        else {
            mistake(level < 78 ? 'Nivel prea mic.' : 'Nivel prea mare.');
            level = 0;
            fillLevel.style.height = '0%';
        }
    };

    fillButton.addEventListener('mousedown', start);
    fillButton.addEventListener('mouseup', stop);
    fillButton.addEventListener('mouseleave', stop);
    cleanupGame = () => cancelAnimationFrame(raf);
}

function engineGame() {
    const colors = [
        { id: 'red', value: '#ff525d' },
        { id: 'blue', value: '#4ea1ff' },
        { id: 'yellow', value: '#ffd24a' },
        { id: 'green', value: '#48d584' }
    ];
    const right = [...colors].sort(() => Math.random() - 0.5);
    let selected = null;
    let matched = 0;

    gameArea.innerHTML = `<div class="game-card"><p class="instruction">Conectează fiecare fir din stânga la culoarea identică din dreapta.</p><div class="wires"><div class="wire-column" id="leftWires"></div><div class="wire-column" id="rightWires"></div></div></div>`;

    const makeWire = (wire, side) => {
        const element = document.createElement('button');
        element.className = 'wire';
        element.dataset.id = wire.id;
        element.style.color = wire.value;
        element.style.background = `${wire.value}18`;
        element.onclick = () => {
            if (side === 'left') {
                document.querySelectorAll('#leftWires .wire').forEach(item => item.classList.remove('selected'));
                selected = element;
                element.classList.add('selected');
                return;
            }
            if (!selected) {
                mistake('Selectează mai întâi un fir din stânga.');
                return;
            }
            if (selected.dataset.id === element.dataset.id) {
                selected.classList.add('done');
                element.classList.add('done');
                selected = null;
                matched += 1;
                if (matched === colors.length) finishGame(true);
            } else {
                selected.classList.remove('selected');
                selected = null;
                mistake('Culorile nu corespund.');
            }
        };
        return element;
    };

    colors.forEach(wire => document.getElementById('leftWires').append(makeWire(wire, 'left')));
    right.forEach(wire => document.getElementById('rightWires').append(makeWire(wire, 'right')));
}

function startGame(task) {
    baseGame(task);
    switch (task.type) {
        case 'diagnostics': diagnosticGame(); break;
        case 'battery': movingMeterGame('battery'); break;
        case 'tire': tireGame(); break;
        case 'oil': oilGame(); break;
        case 'brakes': movingMeterGame('brakes'); break;
        case 'engine': engineGame(); break;
        default: diagnosticGame();
    }
}

window.addEventListener('message', event => {
    const data = event.data;
    if (data.action === 'openMenu') {
        renderMenu(data.profile);
        game.classList.add('hidden');
        menu.classList.remove('hidden');
    } else if (data.action === 'setMenuBusy') {
        setMenuBusy(data.busy);
    } else if (data.action === 'startGame') {
        startGame(data.task);
    } else if (data.action === 'closeGame') {
        cleanupGame();
        game.classList.add('hidden');
    } else if (data.action === 'closeAll') {
        cleanupGame();
        menu.classList.add('hidden');
        game.classList.add('hidden');
    }
});

document.querySelectorAll('[data-action="close"]').forEach(element => {
    element.addEventListener('click', () => post('menuAction', { action: 'close' }));
});

document.getElementById('cancelGame').addEventListener('click', () => {
    if (finished) return;
    finished = true;
    cleanupGame();
    post('escapeGame');
});

document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (!game.classList.contains('hidden')) {
        if (!finished) {
            finished = true;
            cleanupGame();
            post('escapeGame');
        }
    } else if (!menu.classList.contains('hidden')) {
        post('menuAction', { action: 'close' });
    }
});
