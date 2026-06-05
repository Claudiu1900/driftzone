'use strict';

const root = document.getElementById('root');
const title = document.getElementById('title');
const subtitle = document.getElementById('subtitle');
const username = document.getElementById('username');
const email = document.getElementById('email');
const password = document.getElementById('password');
const confirmPassword = document.getElementById('confirmPassword');
const registerFields = document.getElementById('registerFields');
const confirmFields = document.getElementById('confirmFields');
const rememberRow = document.getElementById('rememberRow');
const remember = document.getElementById('remember');
const submitBtn = document.getElementById('submitBtn');
const switchBtn = document.getElementById('switchBtn');
const message = document.getElementById('message');

let isLogin = true;

function nui(name, data = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8'
        },
        body: JSON.stringify(data)
    }).catch(() => {});
}

function setMessage(text) {
    message.textContent = String(text || '');
    message.classList.remove('hidden');

    submitBtn.disabled = false;
    submitBtn.textContent = isLogin ? 'LOG IN' : 'REGISTER';
}

function clearMessage() {
    message.textContent = '';
    message.classList.add('hidden');
}

function setMode(loginMode) {
    isLogin = loginMode === true;

    title.textContent = isLogin ? 'DRIFTZONE' : 'SIGN UP';
    subtitle.textContent = isLogin ? 'Secure identity access' : 'Create your DriftZone identity';

    registerFields.classList.toggle('hidden', isLogin);
    confirmFields.classList.toggle('hidden', isLogin);
    rememberRow.classList.toggle('hidden', !isLogin);

    submitBtn.textContent = isLogin ? 'LOG IN' : 'REGISTER';
    switchBtn.textContent = isLogin ? 'New Account? Register' : 'Known Identity? Login';

    password.value = '';
    confirmPassword.value = '';

    if (isLogin) {
        const saved = localStorage.getItem('dz_saved_password') || '';

        if (saved) {
            password.value = saved;
            remember.checked = true;
        }
    } else {
        remember.checked = false;
    }

    clearMessage();
}

function switchMode() {
    setMode(!isLogin);
}

function togglePassword(id, button) {
    const input = document.getElementById(id);

    if (!input) return;

    input.type = input.type === 'password' ? 'text' : 'password';
    button.textContent = input.type === 'password' ? 'SHOW' : 'HIDE';
}

function submitAuth() {
    clearMessage();

    const pass = password.value || '';

    if (isLogin) {
        if (!pass) {
            setMessage('Parola obligatorie.');
            return;
        }

        submitBtn.disabled = true;
        submitBtn.textContent = 'SE CONECTEAZA...';

        nui('submit', {
            type: 'login',
            password: pass
        });

        if (remember.checked) {
            localStorage.setItem('dz_saved_password', pass);
        } else {
            localStorage.removeItem('dz_saved_password');
        }

        return;
    }

    const mail = (email.value || '').trim().toLowerCase();
    const confirm = confirmPassword.value || '';

    if (!mail || !mail.includes('@') || !mail.includes('.')) {
        setMessage('Email invalid.');
        return;
    }

    if (!pass) {
        setMessage('Parola obligatorie.');
        return;
    }

    if (pass.length < 6) {
        setMessage('Parola prea scurta. Minim 6 caractere.');
        return;
    }

    if (pass !== confirm) {
        setMessage('Parolele nu coincid.');
        return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = 'SE INREGISTREAZA...';

    nui('submit', {
        type: 'register',
        email: mail,
        password: pass
    });
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.action === 'open') {
        root.classList.remove('hidden');

        document.documentElement.style.setProperty('--main', data.mainColor || '#04c7f7');

        username.value = data.name || 'Player';

        setMode(data.hasAccount === true);

        if (data.hasAccount !== true) {
            setMode(false);
        }
    }

    if (data.action === 'close') {
        root.classList.add('hidden');
    }

    if (data.action === 'status') {
        setMessage(data.message || 'Eroare.');
    }
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        submitAuth();
    }
});

setTimeout(() => {
    nui('ready');
}, 100);