Config = {}

-- Cat de des verifica XP-ul tuturor jucatorilor online.
-- 60 secunde este safe si nu face lag.
Config.CheckIntervalSeconds = 60

-- Daca vrei sa seteze rank-ul imediat cand playerul intra/login, lasa true.
Config.CheckOnPlayerJoin = true

-- Daca vrei mesaj/notificare cand se schimba levelul.
Config.NotifyOnLevelChange = true

-- Tabela si coloanele din baza de date.
Config.Database = {
    tableName = 'users',
    uidColumn = 'uid',
    xpColumn = 'xp',
    rankColumn = 'rank',
    rankColorColumn = 'rankcolor'
}

-- Culoarea rankului setata automat.
Config.DefaultRankColor = '#ffffff'

-- Rank daca playerul nu are destul XP pentru Level 1.
-- Pune '' daca vrei sa ramana gol.
Config.DefaultRank = 'Newbie'
Config.DefaultRankColorForNewbie = '#b1b1b1'

-- Levelurile. Daca xp >= requiredXp, playerul primeste rank-ul acela.
Config.Levels = {
    { requiredXp = 1000,    rank = 'Starter',  color = '#a4a4a4' },
    { requiredXp = 5000,    rank = 'Street',  color = '#11ec3d' },
    { requiredXp = 15000,   rank = 'Slide',  color = '#00a1a9' },
    { requiredXp = 30000,   rank = 'Smoke',  color = '#6d6d6d' },
    { requiredXp = 50000,   rank = 'Turbo',  color = '#ff4747' },
    { requiredXp = 75000,   rank = 'Nitro',  color = '#c200b2' },
    { requiredXp = 100000,  rank = 'Pro Racer',  color = '#002fff' },
    { requiredXp = 250000,  rank = 'Legend',  color = '#ff0000' },
    { requiredXp = 500000,  rank = 'King',  color = '#f6ff00' },
    { requiredXp = 1000000, rank = 'DriftGod', color = '#04c7f7' },
    { requiredXp = 9999999, rank = 'Troller', color = '#ff0000' }
}
 