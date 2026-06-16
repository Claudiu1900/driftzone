Config = {}

Config.MainColor = '#04c7f7'
Config.KvpPrefix = 'driftzone_keybind_'
Config.CheckInterval = 0
Config.IdleInterval = 180

-- IMPORTANT:
-- Fara RegisterKeyMapping, FiveM poate detecta doar taste care exista ca GTA/FiveM controls.
-- Daca vrei o tasta 100% sigura, foloseste M, K, U, F1-F10, E, G, H, X, Z, P etc.
Config.KeyMap = {
    -- letters / controls
    E = 38,
    F = 23,
    G = 47,
    H = 74,
    K = 311,
    L = 182,
    M = 244,
    P = 199,
    Q = 44,
    R = 45,
    T = 245,
    U = 303,
    X = 73,
    Z = 20,

    -- function keys
    F1 = 288,
    F2 = 289,
    F3 = 170,
    F5 = 166,
    F6 = 167,
    F7 = 168,
    F9 = 56,
    F10 = 57,
    F11 = 344,

    -- arrows / misc
    UP = 172,
    DOWN = 173,
    LEFT = 174,
    RIGHT = 175,
    ENTER = 191,
    BACKSPACE = 177,
    DELETE = 178,
    SPACE = 22,
    TAB = 37,
    SHIFT = 21,
    CTRL = 36,
    ALT = 19,

    -- O nu are un control GTA universal stabil. Il lasam configurabil, dar daca pe build-ul tau nu merge,
    -- foloseste o tasta din lista de mai sus. Nu punem E ca fallback ca sa nu se schimbe singur.
    O = nil
}

Config.BlockedKeys = {
    ESC = true,
    F8 = true
}

Config.Keybinds = {
        {
        id = 'inventory',
        name = 'Inventory',
        description = 'Deschide inventarul',
        key = 'U',
        eventType = 'command',
        eventName = 'inventory',
        enabled = true
    },
        {
        id = 'playerinteract',
        name = 'Player Interactions',
        description = 'Deschide meniul de interactiunii cu jucatorii din apropiere',
        key = 'Z',
        eventType = 'command',
        eventName = 'playerinteract',
        enabled = true
    },
        {
        id = 'lockveh',
        name = 'Lock / Unlock Vehicle',
        description = 'Incuie sau descuie masina personala',
        key = 'F3',
        eventType = 'command',
        eventName = 'vehiclelock',
        enabled = true
    },
            {
        id = 'engine',
        name = 'Engine Toggle',
        description = 'Pornește sau oprește motorul mașinii',
        key = 'TAB',
        eventType = 'command',
        eventName = 'engine',
        enabled = true
    },
    {
        id = 'stats',
        name = 'Stats',
        description = 'Deschide statisticile contului',
        key = 'F6',
        eventType = 'command',
        eventName = 'stats',
        enabled = true
    }
}
