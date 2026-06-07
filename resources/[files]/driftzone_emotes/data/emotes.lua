DriftZoneEmotes = {}

-- type = 'anim'     -> animDict + animName
-- type = 'scenario' -> scenario
-- type = 'walk'     -> walk style
-- flag: 1 loop, 49 upper body moving, 51 moving loop
DriftZoneEmotes.List = {
    salute = {
        label = 'Salute', category = 'general', type = 'anim',
        dict = 'anim@mp_player_intcelebrationmale@salute', anim = 'salute', flag = 49,
        description = 'Salut rapid si curat.'
    },
    wave = {
        label = 'Wave', category = 'general', type = 'anim',
        dict = 'friends@frj@ig_1', anim = 'wave_a', flag = 49,
        description = 'Faci cu mana.'
    },
    facepalm = {
        label = 'Facepalm', category = 'general', type = 'anim',
        dict = 'anim@mp_player_intcelebrationmale@face_palm', anim = 'face_palm', flag = 49,
        description = 'Reactie de dezamagire.'
    },
    thumbs = {
        label = 'Thumbs Up', category = 'general', type = 'anim',
        dict = 'anim@mp_player_intcelebrationmale@thumbs_up', anim = 'thumbs_up', flag = 49,
        description = 'Aprobare.'
    },
    think = {
        label = 'Think', category = 'general', type = 'anim',
        dict = 'misscarsteal4@aliens', anim = 'rehearsal_base_idle_director', flag = 49,
        description = 'Stai pe ganduri.'
    },

    dance = {
        label = 'Dance', category = 'dance', type = 'anim',
        dict = 'anim@amb@nightclub@dancers@podium_dancers@', anim = 'hi_dance_facedj_17_v2_male^5', flag = 1,
        description = 'Dans de club.'
    },
    dance2 = {
        label = 'Dance 2', category = 'dance', type = 'anim',
        dict = 'anim@amb@nightclub@mini@dance@dance_solo@male@var_b@', anim = 'high_center_down', flag = 1,
        description = 'Dans energic.'
    },
    dance3 = {
        label = 'Dance 3', category = 'dance', type = 'anim',
        dict = 'anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', anim = 'med_center_up', flag = 1,
        description = 'Dans smooth.'
    },
    dj = {
        label = 'DJ', category = 'dance', type = 'anim',
        dict = 'anim@amb@nightclub@djs@dixon@', anim = 'dixn_dance_cntr_open_dix', flag = 1,
        description = 'DJ vibe.'
    },

    clipboard = {
        label = 'Clipboard', category = 'actions', type = 'anim',
        dict = 'missfam4', anim = 'base', flag = 49,
        prop = { model = 'p_amb_clipboard_01', bone = 36029, placement = {0.16, 0.08, 0.1, -130.0, -50.0, 0.0} },
        description = 'Tii un clipboard.'
    },
    phone = {
        label = 'Phone', category = 'actions', type = 'anim',
        dict = 'cellphone@', anim = 'cellphone_text_read_base', flag = 49,
        prop = { model = 'prop_npc_phone_02', bone = 28422, placement = {0.0, 0.0, 0.0, 0.0, 0.0, 0.0} },
        description = 'Telefon in mana.'
    },
    mechanic = {
        label = 'Mechanic', category = 'actions', type = 'anim',
        dict = 'mini@repair', anim = 'fixing_a_ped', flag = 1,
        description = 'Repari ceva.'
    },
    cop = {
        label = 'Cop Idle', category = 'actions', type = 'anim',
        dict = 'amb@world_human_cop_idles@male@idle_b', anim = 'idle_e', flag = 49,
        description = 'Pozitie de politist.'
    },
    lean = {
        label = 'Lean', category = 'actions', type = 'scenario',
        scenario = 'WORLD_HUMAN_LEANING',
        description = 'Te sprijini relaxat.'
    },
    smoke = {
        label = 'Smoke', category = 'actions', type = 'scenario',
        scenario = 'WORLD_HUMAN_SMOKING',
        description = 'Fumezi.'
    },
    guard = {
        label = 'Guard', category = 'actions', type = 'scenario',
        scenario = 'WORLD_HUMAN_GUARD_STAND',
        description = 'Stai de paza.'
    },

    sit = {
        label = 'Sit', category = 'sitting', type = 'anim',
        dict = 'anim@amb@business@bgen@bgen_no_work@', anim = 'sit_phone_phoneputdown_idle_nowork', flag = 1,
        description = 'Stai jos.'
    },
    sit2 = {
        label = 'Sit 2', category = 'sitting', type = 'anim',
        dict = 'timetable@ron@ig_5_p3', anim = 'ig_5_p3_base', flag = 1,
        description = 'Stai jos relaxat.'
    },
    yoga = {
        label = 'Yoga', category = 'sitting', type = 'scenario',
        scenario = 'WORLD_HUMAN_YOGA',
        description = 'Yoga.'
    },

    walkreset = {
        label = 'Normal Walk', category = 'walks', type = 'walk', walk = 'reset',
        description = 'Reseteaza mersul.'
    },
    walktough = {
        label = 'Tough Walk', category = 'walks', type = 'walk', walk = 'move_m@tough_guy@',
        description = 'Mers agresiv.'
    },
    walkgang = {
        label = 'Gang Walk', category = 'walks', type = 'walk', walk = 'move_m@gangster@generic',
        description = 'Mers de strada.'
    },
    walkposh = {
        label = 'Posh Walk', category = 'walks', type = 'walk', walk = 'move_m@posh@',
        description = 'Mers elegant.'
    },
}
