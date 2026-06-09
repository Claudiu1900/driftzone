local Sessions = {}
local UidCache = {}
local CashCache = {}

local CARD_SUITS = { '♠', '♥', '♦', '♣' }
local CARD_RANKS = { 'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K' }

local function sqlName(name)
    return ('`%s`'):format(tostring(name or ''):gsub('`', ''))
end

local function nowMs()
    return GetGameTimer()
end

local function jsonSafe(data)
    local ok, result = pcall(json.encode, data or {})
    if ok then return result end
    return '{}'
end

local function notify(src, t, msg, d)
    TriggerClientEvent('driftzone_blackjack:client:notify', src, t or 'info', tostring(msg or ''), d or 5000)
end

local function status(src, t, msg)
    TriggerClientEvent('driftzone_blackjack:client:status', src, t or 'info', tostring(msg or ''))
end

local function getIdentifierUid(src)
    local state = Player(src).state
    if state and tonumber(state.dz_uid) and tonumber(state.dz_uid) > 0 then return tonumber(state.dz_uid) end

    local cached = UidCache[src]
    if cached and cached.expires > nowMs() then return cached.uid end

    local attempts = {
        function() return exports.driftzone_auth:GetUID(src) end,
        function() return exports.driftzone_auth:GetUid(src) end,
        function() return exports.driftzone_auth:getUID(src) end,
        function() return exports.driftzone_auth:getUid(src) end
    }

    for _, fn in ipairs(attempts) do
        local ok, uid = pcall(fn)
        uid = tonumber(uid)
        if ok and uid and uid > 0 then
            UidCache[src] = { uid = uid, expires = nowMs() + 30000 }
            return uid
        end
    end

    return nil
end

local function isLogged(src)
    local state = Player(src).state
    if state and state.dz_logged == true then return true end

    local ok, result = pcall(function()
        return exports.driftzone_auth:IsLoggedIn(src)
    end)

    if ok and result == true then return true end
    return getIdentifierUid(src) ~= nil
end

local function getCash(uid, force)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return 0 end

    local cached = CashCache[uid]
    if not force and cached and cached.expires > nowMs() then return cached.cash end

    local row = MySQL.single.await(
        ('SELECT %s AS cash FROM %s WHERE %s = ? LIMIT 1'):format(
            sqlName(Config.UsersCashColumn or 'cash'),
            sqlName(Config.UsersTable or 'users'),
            sqlName(Config.UsersIdColumn or 'uid')
        ),
        { uid }
    )

    local cash = row and tonumber(row.cash or 0) or 0
    CashCache[uid] = { cash = cash, expires = nowMs() + 1000 }
    return cash
end

local function setCashCache(uid, cash)
    uid = tonumber(uid or 0) or 0
    if uid <= 0 then return end
    CashCache[uid] = { cash = tonumber(cash or 0) or 0, expires = nowMs() + 1000 }
end

local function addCash(uid, amount)
    uid = tonumber(uid or 0) or 0
    amount = math.floor(tonumber(amount or 0) or 0)
    if uid <= 0 or amount == 0 then return false, getCash(uid, true) end

    local cashCol = sqlName(Config.UsersCashColumn or 'cash')
    local maxCash = tonumber(Config.SafeCashMax or 2147483647) or 2147483647
    local affected

    if amount < 0 then
        affected = MySQL.update.await(
            ('UPDATE %s SET %s = %s + ? WHERE %s = ? AND %s >= ?'):format(
                sqlName(Config.UsersTable or 'users'), cashCol, cashCol, sqlName(Config.UsersIdColumn or 'uid'), cashCol
            ),
            { amount, uid, math.abs(amount) }
        )
    else
        affected = MySQL.update.await(
            ('UPDATE %s SET %s = LEAST(%s + ?, ?) WHERE %s = ?'):format(
                sqlName(Config.UsersTable or 'users'), cashCol, cashCol, sqlName(Config.UsersIdColumn or 'uid')
            ),
            { amount, maxCash, uid }
        )
    end

    if affected and affected > 0 then
        local cash = getCash(uid, true)
        setCashCache(uid, cash)
        return true, cash
    end

    return false, getCash(uid, true)
end

local function makeDeck()
    local deck = {}
    for _, suit in ipairs(CARD_SUITS) do
        for _, rank in ipairs(CARD_RANKS) do
            local value = tonumber(rank) or (rank == 'A' and 11 or 10)
            deck[#deck + 1] = { rank = rank, suit = suit, value = value, code = rank .. suit }
        end
    end

    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end

    return deck
end

local function drawCard(session)
    if not session.deck or #session.deck < 12 then
        session.deck = makeDeck()
    end
    return table.remove(session.deck)
end

local function handValue(cards)
    local total = 0
    local aces = 0

    for _, card in ipairs(cards or {}) do
        total = total + (tonumber(card.value or 0) or 0)
        if card.rank == 'A' then aces = aces + 1 end
    end

    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end

    return total
end

local function isBlackjack(cards)
    return #(cards or {}) == 2 and handValue(cards) == 21
end

local function publicCard(card)
    if not card then return nil end
    return { rank = card.rank, suit = card.suit, value = card.value, code = card.code }
end

local function publicHand(cards, hideSecond)
    local out = {}
    for i, card in ipairs(cards or {}) do
        if hideSecond and i == 2 then
            out[#out + 1] = { hidden = true, code = '??' }
        else
            out[#out + 1] = publicCard(card)
        end
    end
    return out
end

local function stateForClient(session, revealDealer)
    local playerValue = handValue(session.playerCards)
    local dealerValue = revealDealer and handValue(session.dealerCards) or handValue({ session.dealerCards[1] })

    return {
        active = session.active == true,
        phase = session.phase or 'idle',
        bet = session.bet or 0,
        cash = getCash(session.uid),
        playerCards = publicHand(session.playerCards, false),
        dealerCards = publicHand(session.dealerCards, not revealDealer),
        playerValue = playerValue,
        dealerValue = dealerValue,
        result = session.result or '',
        message = session.message or '',
        canHit = session.phase == 'player',
        canStand = session.phase == 'player',
        canDouble = Config.AllowDouble == true and session.phase == 'player' and #(session.playerCards or {}) == 2 and getCash(session.uid) >= (session.bet or 0),
        canSurrender = Config.AllowSurrender == true and session.phase == 'player' and #(session.playerCards or {}) == 2
    }
end

local function pushState(src, revealDealer)
    local session = Sessions[src]
    if not session then return end
    TriggerClientEvent('driftzone_blackjack:client:update', src, stateForClient(session, revealDealer == true or session.phase == 'finished'))
end

local function logRound(src, session)
    local ok, err = pcall(function()
        MySQL.insert.await(([[
            INSERT INTO %s
            (uid, player_name, bet, result, payout, player_cards, dealer_cards)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]]):format(sqlName(Config.LogsTable or 'blackjack_logs')), {
            session.uid,
            GetPlayerName(src) or 'Unknown',
            session.bet or 0,
            session.result or 'unknown',
            session.payout or 0,
            jsonSafe(session.playerCards or {}),
            jsonSafe(session.dealerCards or {})
        })
    end)

    if not ok then
        print('[DRIFTZONE_BLACKJACK] log failed: ' .. tostring(err))
    end
end

local function finishRound(src, result, message, payoutMultiplier)
    local session = Sessions[src]
    if not session then return end

    local bet = tonumber(session.bet or 0) or 0
    local payout = 0

    if payoutMultiplier and payoutMultiplier > 0 then
        payout = math.floor(bet + (bet * payoutMultiplier))
        addCash(session.uid, payout)
    elseif result == 'push' then
        payout = bet
        addCash(session.uid, payout)
    end

    session.phase = 'finished'
    session.active = false
    session.result = result
    session.message = message
    session.payout = payout
    session.finishedAt = os.time()

    logRound(src, session)
    pushState(src, true)
end

local function dealerPlay(src)
    local session = Sessions[src]
    if not session then return end

    session.phase = 'dealer'

    while handValue(session.dealerCards) < (Config.DealerStand or 17) do
        session.dealerCards[#session.dealerCards + 1] = drawCard(session)
        Wait(350)
        pushState(src, true)
    end

    local playerValue = handValue(session.playerCards)
    local dealerValue = handValue(session.dealerCards)

    if dealerValue > 21 then
        finishRound(src, 'win', 'Dealer-ul a trecut peste 21. Ai castigat.', Config.WinPayout or 1.0)
    elseif dealerValue > playerValue then
        finishRound(src, 'lose', 'Dealer-ul a castigat.', 0)
    elseif dealerValue < playerValue then
        finishRound(src, 'win', 'Ai castigat mana.', Config.WinPayout or 1.0)
    else
        finishRound(src, 'push', 'Egalitate. Ti-ai primit pariul inapoi.', 0)
    end
end

local function validAction(src)
    local session = Sessions[src]
    if not session then return false end
    local cd = tonumber(Config.ActionCooldownMs or 650) or 650
    if session.actionLock and session.actionLock > nowMs() then return false end
    session.actionLock = nowMs() + cd
    return true
end

RegisterNetEvent('driftzone_blackjack:server:open', function()
    local src = source
    if not isLogged(src) then
        notify(src, 'warning', 'Trebuie sa fii logat.')
        return
    end

    local uid = getIdentifierUid(src)
    if not uid then
        notify(src, 'warning', 'Nu ti-am gasit UID-ul.')
        return
    end

    Sessions[src] = Sessions[src] or {
        uid = uid,
        deck = makeDeck(),
        active = false,
        phase = 'idle'
    }
    Sessions[src].uid = uid

    TriggerClientEvent('driftzone_blackjack:client:open', src, { cash = getCash(uid, true) })
    pushState(src, true)
end)

RegisterNetEvent('driftzone_blackjack:server:close', function()
    local src = source
    local session = Sessions[src]
    if session and session.phase == 'player' and session.active then
        finishRound(src, 'leave', 'Ai inchis masa. Pariul a fost pierdut.', 0)
    end
end)

RegisterNetEvent('driftzone_blackjack:server:start', function(bet)
    local src = source
    bet = math.floor(tonumber(bet or 0) or 0)

    if not isLogged(src) then return end

    local uid = getIdentifierUid(src)
    if not uid then return end

    local minBet = tonumber(Config.MinBet or 1000) or 1000
    local maxBet = tonumber(Config.MaxBet or 1000000) or 1000000

    if bet < minBet or bet > maxBet then
        status(src, 'error', ('Pariul trebuie sa fie intre $%s si $%s.'):format(minBet, maxBet))
        return
    end

    Sessions[src] = Sessions[src] or { uid = uid, deck = makeDeck() }
    local session = Sessions[src]
    session.uid = uid

    if session.phase == 'player' or session.phase == 'dealer' then
        status(src, 'warning', 'Ai deja o mana activa.')
        return
    end

    local delay = tonumber(Config.NewRoundCooldownMs or 1200) or 1200
    if session.nextRoundAt and session.nextRoundAt > nowMs() then return end
    session.nextRoundAt = nowMs() + delay

    local okTake, cash = addCash(uid, -bet)
    if not okTake then
        status(src, 'error', 'Nu ai destui bani pentru acest pariu.')
        TriggerClientEvent('driftzone_blackjack:client:update', src, { cash = cash })
        return
    end

    session.bet = bet
    session.active = true
    session.phase = 'player'
    session.result = ''
    session.message = ''
    session.payout = 0
    session.playerCards = { drawCard(session), drawCard(session) }
    session.dealerCards = { drawCard(session), drawCard(session) }

    pushState(src, false)

    if isBlackjack(session.playerCards) and isBlackjack(session.dealerCards) then
        finishRound(src, 'push', 'Blackjack la amandoi. Egalitate.', 0)
    elseif isBlackjack(session.playerCards) then
        finishRound(src, 'blackjack', 'BLACKJACK! Ai castigat 3:2.', Config.BlackjackPayout or 1.5)
    elseif isBlackjack(session.dealerCards) then
        finishRound(src, 'lose', 'Dealer-ul are Blackjack.', 0)
    end
end)

RegisterNetEvent('driftzone_blackjack:server:hit', function()
    local src = source
    local session = Sessions[src]
    if not session or session.phase ~= 'player' or not validAction(src) then return end

    session.playerCards[#session.playerCards + 1] = drawCard(session)

    local value = handValue(session.playerCards)
    if value > 21 then
        finishRound(src, 'bust', 'Ai trecut peste 21. Ai pierdut.', 0)
    else
        pushState(src, false)
    end
end)

RegisterNetEvent('driftzone_blackjack:server:stand', function()
    local src = source
    local session = Sessions[src]
    if not session or session.phase ~= 'player' or not validAction(src) then return end
    dealerPlay(src)
end)

RegisterNetEvent('driftzone_blackjack:server:double', function()
    local src = source
    local session = Sessions[src]
    if not session or session.phase ~= 'player' or not validAction(src) then return end
    if Config.AllowDouble ~= true then return end
    if #(session.playerCards or {}) ~= 2 then return end

    local bet = tonumber(session.bet or 0) or 0
    local okTake = addCash(session.uid, -bet)
    if not okTake then
        status(src, 'error', 'Nu ai destui bani pentru DOUBLE.')
        pushState(src, false)
        return
    end

    session.bet = bet * 2
    session.playerCards[#session.playerCards + 1] = drawCard(session)

    if handValue(session.playerCards) > 21 then
        finishRound(src, 'bust', 'Ai dat DOUBLE si ai trecut peste 21.', 0)
    else
        dealerPlay(src)
    end
end)

RegisterNetEvent('driftzone_blackjack:server:surrender', function()
    local src = source
    local session = Sessions[src]
    if not session or session.phase ~= 'player' or not validAction(src) then return end
    if Config.AllowSurrender ~= true then return end
    if #(session.playerCards or {}) ~= 2 then return end

    local refund = math.floor((tonumber(session.bet or 0) or 0) / 2)
    if refund > 0 then addCash(session.uid, refund) end
    session.payout = refund
    session.phase = 'finished'
    session.active = false
    session.result = 'surrender'
    session.message = 'Ai dat surrender. Ai primit jumatate din pariu inapoi.'
    logRound(src, session)
    pushState(src, true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local session = Sessions[src]
    if session and session.phase == 'player' and session.active then
        session.result = 'disconnect'
        session.message = 'Player disconnect.'
        session.payout = 0
        logRound(src, session)
    end
    Sessions[src] = nil
    UidCache[src] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    math.randomseed(os.time() + GetGameTimer())
    print('[DRIFTZONE_BLACKJACK] loaded.')
end)
