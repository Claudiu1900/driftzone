Config = {}

Config.Command = 'editor'

-- true = cand opresti /editor salveaza clipul
-- false = cand opresti /editor sterge clipul
Config.SaveClipOnStop = true

Config.Notify = {
    enabled = true,
    event = 'client:notify'
}

Config.Messages = {
    started = 'Rockstar Editor recording pornit.',
    stoppedSaved = 'Rockstar Editor recording oprit si salvat.',
    stoppedDiscarded = 'Rockstar Editor recording oprit fara salvare.',
    failedStart = 'Nu am putut porni Rockstar Editor recording.'
}
