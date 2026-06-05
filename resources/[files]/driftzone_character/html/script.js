const root = document.getElementById('root');
const controlsEl = document.getElementById('controls');

let character = null;
let activeTab = 'parents';
let dragging = false;
let lastX = 0;
let updateTimer = null;
let firstCreation = false;

const gtaHairColors = [
    '#1c1f21', '#272a2c', '#312e2c', '#35261c', '#4b321f', '#5c3b24', '#6d4c35', '#6b503b',
    '#765c45', '#7f684e', '#99815d', '#a79369', '#af9c70', '#bba063', '#d6b97b', '#dac38e',
    '#9f7f59', '#845039', '#682b1f', '#61120c', '#640f0a', '#7c140f', '#a02e19', '#b64b28',
    '#a2502f', '#aa4e2b', '#626262', '#808080', '#aaaaaa', '#c5c5c5', '#463955', '#5a3f6b',
    '#763c76', '#ed74e3', '#eb4b93', '#f299bc', '#04959e', '#025f86', '#023974', '#3fa16a',
    '#217c61', '#185c55', '#b6c034', '#70a90b', '#439d13', '#dcb857', '#e5b103', '#e69102',
    '#f28831', '#fb8057', '#e28b58', '#d1593c', '#ce3120', '#ad0903', '#880302', '#1f1814',
    '#291f19', '#2e221b', '#37291e', '#2e2218', '#231b15', '#020202', '#706c66', '#9d7a50'
];

const featureLabels = [
    'Nas latime',
    'Nas inaltime',
    'Nas lungime',
    'Nas pod',
    'Nas varf',
    'Nas deplasare',
    'Sprancene sus/jos',
    'Sprancene fata/spate',
    'Obraji sus',
    'Obraji latime',
    'Obraji jos',
    'Ochi',
    'Buze',
    'Maxilar latime',
    'Maxilar forma',
    'Barbie sus/jos',
    'Barbie lungime',
    'Barbie forma',
    'Barbie adancime',
    'Gat'
];

const tabs = {
    parents: [
        ['parents.mother', 'Mama', 0, 45, 1],
        ['parents.father', 'Tata', 0, 45, 1],
        ['parents.shapeMix', 'Forma fetei', 0, 1, 0.01],
        ['parents.skinMix', 'Culoare piele', 0, 1, 0.01]
    ],

    hair: [
        ['hair.style', 'Stil par', 0, 76, 1],
        ['hair.color', 'Culoare par', 0, 63, 1, 'color'],
        ['hair.highlight', 'Highlight par', 0, 63, 1, 'color'],
        ['eyes', 'Culoare ochi', 0, 31, 1]
    ],

    beard: [
        ['overlays.beard.id', 'Barba', 0, 28, 1],
        ['overlays.beard.opacity', 'Opacitate barba', 0, 1, 0.01],
        ['overlays.beard.color', 'Culoare barba', 0, 63, 1, 'color'],
        ['overlays.chesthair.id', 'Par piept', 0, 16, 1],
        ['overlays.chesthair.opacity', 'Opacitate par piept', 0, 1, 0.01],
        ['overlays.chesthair.color', 'Culoare par piept', 0, 63, 1, 'color']
    ],

    details: [
        ['overlays.eyebrows.id', 'Sprancene', 0, 33, 1],
        ['overlays.eyebrows.opacity', 'Opacitate sprancene', 0, 1, 0.01],
        ['overlays.eyebrows.color', 'Culoare sprancene', 0, 63, 1, 'color'],
        ['overlays.blemishes.id', 'Pete fata', 0, 23, 1],
        ['overlays.blemishes.opacity', 'Opacitate pete', 0, 1, 0.01],
        ['overlays.ageing.id', 'Varsta', 0, 14, 1],
        ['overlays.ageing.opacity', 'Opacitate varsta', 0, 1, 0.01],
        ['overlays.complexion.id', 'Ten', 0, 11, 1],
        ['overlays.complexion.opacity', 'Opacitate ten', 0, 1, 0.01],
        ['overlays.moles.id', 'Alunite', 0, 17, 1],
        ['overlays.moles.opacity', 'Opacitate alunite', 0, 1, 0.01],
        ['overlays.makeup.id', 'Makeup', 0, 74, 1],
        ['overlays.makeup.opacity', 'Opacitate makeup', 0, 1, 0.01],
        ['overlays.lipstick.id', 'Lipstick', 0, 9, 1],
        ['overlays.lipstick.opacity', 'Opacitate lipstick', 0, 1, 0.01],
        ['overlays.lipstick.color', 'Culoare lipstick', 0, 63, 1, 'color']
    ]
};

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function randInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randFloat(min, max, decimals = 2) {
    return Number((Math.random() * (max - min) + min).toFixed(decimals));
}

function getPath(obj, path) {
    return path.split('.').reduce((acc, key) => acc ? acc[key] : undefined, obj);
}

function setPath(obj, path, value) {
    const keys = path.split('.');
    let ref = obj;

    while (keys.length > 1) {
        const key = keys.shift();

        if (!ref[key]) ref[key] = {};

        ref = ref[key];
    }

    ref[keys[0]] = value;
}

function formatValue(value) {
    const n = Number(value);

    if (Number.isInteger(n)) return String(n);

    return n.toFixed(2);
}

function queueUpdate() {
    clearTimeout(updateTimer);

    updateTimer = setTimeout(() => {
        nui('update', character);
    }, 35);
}

function makeSliderControl(path, label, min, max, step) {
    const value = getPath(character, path) ?? 0;
    const id = path.replaceAll('.', '_');

    return `
        <div class="control">
            <div class="control-head">
                <div class="control-label">${label}</div>
                <div class="control-value" id="${id}_value">${formatValue(value)}</div>
            </div>
            <input
                type="range"
                min="${min}"
                max="${max}"
                step="${step}"
                value="${value}"
                oninput="updateControl('${path}', this.value, '${id}_value')"
            >
        </div>
    `;
}

function makeColorControl(path, label) {
    const value = Number(getPath(character, path) ?? 0);
    const id = path.replaceAll('.', '_');

    const boxes = gtaHairColors.map((color, index) => {
        const active = index === value ? 'active' : '';

        return `
            <button
                class="color-box ${active}"
                style="background:${color}"
                onclick="selectColor('${path}', ${index}, '${id}_value')"
                title="${index}"
            ></button>
        `;
    }).join('');

    return `
        <div class="control color-control">
            <div class="control-head">
                <div class="control-label">${label}</div>
                <div class="control-value" id="${id}_value">${value}</div>
            </div>
            <div class="color-grid" id="${id}_grid">
                ${boxes}
            </div>
        </div>
    `;
}

function updateControl(path, value, outputId) {
    const n = Number(value);

    setPath(character, path, n);

    const output = document.getElementById(outputId);

    if (output) {
        output.textContent = formatValue(n);
    }

    queueUpdate();
}

function selectColor(path, value, outputId) {
    const n = Number(value);

    setPath(character, path, n);

    const output = document.getElementById(outputId);

    if (output) {
        output.textContent = String(n);
    }

    const gridId = outputId.replace('_value', '_grid');
    const grid = document.getElementById(gridId);

    if (grid) {
        grid.querySelectorAll('.color-box').forEach((box, index) => {
            box.classList.toggle('active', index === n);
        });
    }

    queueUpdate();
}

function renderTab(tab) {
    activeTab = tab;

    document.querySelectorAll('.tab').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tab);
    });

    if (tab === 'face') {
        controlsEl.innerHTML = featureLabels.map((label, index) => {
            return makeSliderControl(`features.${index}`, label, -1, 1, 0.01);
        }).join('');

        return;
    }

    controlsEl.innerHTML = (tabs[tab] || []).map(item => {
        const type = item[5] || 'slider';

        if (type === 'color') {
            return makeColorControl(item[0], item[1]);
        }

        return makeSliderControl(item[0], item[1], item[2], item[3], item[4]);
    }).join('');
}

function refreshGenderButtons() {
    document.getElementById('maleBtn').classList.toggle('active', character.gender !== 'female');
    document.getElementById('femaleBtn').classList.toggle('active', character.gender === 'female');
}

function setGender(gender) {
    character.gender = gender === 'female' ? 'female' : 'male';

    refreshGenderButtons();
    queueUpdate();
}

function randomizeCharacter() {
    const oldGender = character.gender === 'female' ? 'female' : 'male';

    character.parents.mother = randInt(0, 45);
    character.parents.father = randInt(0, 45);
    character.parents.shapeMix = randFloat(0.15, 0.85);
    character.parents.skinMix = randFloat(0.15, 0.85);

    for (let i = 0; i <= 19; i++) {
        character.features[String(i)] = randFloat(-0.75, 0.75);
    }

    character.hair.style = randInt(0, 35);
    character.hair.color = randInt(0, 63);
    character.hair.highlight = randInt(0, 63);
    character.eyes = randInt(0, 31);

    character.overlays.eyebrows.id = randInt(0, 33);
    character.overlays.eyebrows.opacity = randFloat(0.35, 1.0);
    character.overlays.eyebrows.color = randInt(0, 63);

    character.overlays.beard.id = oldGender === 'female' ? 255 : randInt(0, 28);
    character.overlays.beard.opacity = oldGender === 'female' ? 0.0 : randFloat(0.0, 1.0);
    character.overlays.beard.color = randInt(0, 63);

    character.overlays.chesthair.id = oldGender === 'female' ? 255 : randInt(0, 16);
    character.overlays.chesthair.opacity = oldGender === 'female' ? 0.0 : randFloat(0.0, 0.8);
    character.overlays.chesthair.color = randInt(0, 63);

    character.overlays.blemishes.id = Math.random() > 0.55 ? randInt(0, 23) : 255;
    character.overlays.blemishes.opacity = randFloat(0.0, 0.55);

    character.overlays.ageing.id = Math.random() > 0.70 ? randInt(0, 14) : 255;
    character.overlays.ageing.opacity = randFloat(0.0, 0.45);

    character.overlays.complexion.id = Math.random() > 0.55 ? randInt(0, 11) : 255;
    character.overlays.complexion.opacity = randFloat(0.0, 0.55);

    character.overlays.moles.id = Math.random() > 0.60 ? randInt(0, 17) : 255;
    character.overlays.moles.opacity = randFloat(0.0, 0.55);

    character.overlays.makeup.id = oldGender === 'female' && Math.random() > 0.45 ? randInt(0, 74) : 255;
    character.overlays.makeup.opacity = oldGender === 'female' ? randFloat(0.0, 0.65) : 0.0;

    character.overlays.lipstick.id = oldGender === 'female' && Math.random() > 0.55 ? randInt(0, 9) : 255;
    character.overlays.lipstick.opacity = oldGender === 'female' ? randFloat(0.0, 0.70) : 0.0;
    character.overlays.lipstick.color = randInt(0, 63);

    character.overlays.blush.id = oldGender === 'female' && Math.random() > 0.60 ? randInt(0, 6) : 255;
    character.overlays.blush.opacity = oldGender === 'female' ? randFloat(0.0, 0.45) : 0.0;

    character.gender = oldGender;

    refreshGenderButtons();
    renderTab(activeTab);
    queueUpdate();
}

function saveCharacter() {
    nui('save', character);
}

document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => renderTab(btn.dataset.tab));
});

document.addEventListener('mousedown', e => {
    if (e.clientX < window.innerWidth * 0.56) return;

    dragging = true;
    lastX = e.clientX;
});

document.addEventListener('mouseup', () => {
    dragging = false;
});

document.addEventListener('mousemove', e => {
    if (!dragging) return;

    const delta = e.clientX - lastX;
    lastX = e.clientX;

    nui('rotate', {
        delta: delta * 0.35
    });
});

document.addEventListener('keydown', e => {
    if (e.key === 'Escape') {
        e.preventDefault();
    }
});

window.addEventListener('message', event => {
    const data = event.data || {};

    if (data.action === 'open') {
        character = data.character || {};
        firstCreation = data.firstCreation === true;

        document.documentElement.style.setProperty('--main', data.mainColor || '#2aaeff');

        root.classList.remove('hidden');

        refreshGenderButtons();
        renderTab('parents');
    }

    if (data.action === 'close') {
        root.classList.add('hidden');
    }
});

setTimeout(() => {
    nui('ready');
}, 100);