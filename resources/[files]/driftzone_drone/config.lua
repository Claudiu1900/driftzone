Config = {}

Config.RequiredAdminLevel = 6
Config.RequireAduty = true

Config.CaptureTimeoutMs = 2500

-- Mai mare = camera urmareste caracterul mai rapid.
Config.CameraLerp = 0.08

-- Mic offset peste cap.
Config.HeadOffset = vector3(0.0, 0.0, 0.08)

Config.Notify = {
    enabled = true,
    event = 'client:notify'
}
