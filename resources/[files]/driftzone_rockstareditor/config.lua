Config = {}

Config.Command = 'editor'

-- true = la oprire salveaza clipul
-- false = la oprire sterge clipul
Config.SaveClipOnStop = true

-- Anti spam pentru /editor
Config.CooldownMs = 1200

Config.Notify = {
    enabled = true,
    event = 'client:notify'
}

Config.Messages = {
    started = 'Rockstar Editor recording pornit.',
    stoppedSaved = 'Rockstar Editor recording oprit si salvat.',
    stoppedDiscarded = 'Rockstar Editor recording oprit fara salvare.',
    alreadyProcessing = 'Asteapta putin inainte sa folosesti iar /editor.'
}
