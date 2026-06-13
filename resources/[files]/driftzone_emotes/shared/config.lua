

Config = {
    Language = "en",
    UseOldVersionPlacing = false,
    PlayPlacedAnimOnPlayerPed = true,
    TeleportBackAfterPlacedCancelled = true,
    QuickAnimationsState = true,
    QuickPrimaryKey = 'LSHIFT', 
    DefaultQuickKeys = {
        [1] = {Key = 'NUM1'}, 
        [2] = {Key = 'NUM2'}, 
        [3] = {Key = 'NUM3'}, 
        [4] = {Key = 'NUM4'}, 
        [5] = {Key = 'NUM5'}, 
        [6] = {Key = 'NUM6'}, 
        [7] = {Key = 'NUM7'} 
    },
    NumKeys = { 
        [1] = {Key = 108},
        [2] = {Key = 110},
        [3] = {Key = 125},
        [4] = {Key = 117},
        [5] = {Key = 127},
        [6] = {Key = 118},
        [7] = {Key = 314}
    },
    MenuKey = {
        Command = 'emotes',
        KeyMapping = {
            Enable = false,
            Key = 'F4'
        },
        NormalKey = {
            Enable = false,
            Key = 170 
        },
        CloseKey = 27 
    },
    CanOpenMenu = function()
        if IsPedDeadOrDying(PlayerPedId(), true) then
            return false
        end
        return true
    end,
    PropTimeout = 2000,
    AllowMovement = true, 
    MaxDistanceForAnimPos = 15.0,
    AllowedInCars = false, 
    
    Pointing = {
        Enable = true,
        KeyMapping = {
            Enable = false,
            Key = 'B' 
        },
        NormalKey = {
            Enable = false,
            Key = 29 
        }
    },
    
    CrouchingEnabled = false, 
    
    Ragdoll = {
        Enable = false,
        ByPassCanRagdoll = true,
        KeyMapping = {
            Enable = true,
            Key = 'U' 
        },
        NormalKey = {
            Enable = false,
            Key = 303 
        }
    },
    NotifyEvent = 'client:notify',
    Notify = function(text, length, type)
        TriggerEvent(Config.NotifyEvent or 'client:notify', type or 'info', length or 5000, tostring(text or ''))
    end,
    UseSameKeyForCancelAndHandsUp = false, 
    CancelWalk = true, 
    CancelEmote = {
        Command = "emotecancel",
        Enable = true, 
        KeyMapping = {
            Enable = true,
            Key = 'X' 
        },
        NormalKey = {
            Enable = true,
            Key = 74 
        }
    },
    HandsUp = {
        Command = "handsup",
        Enable = false, 
        KeyMapping = {
            Enable = true,
            Key = 'GRAVE' 
        },
        NormalKey = {
            Enable = false,
            Key = 73 
        }
    },
    CanHandsup = function()
        
        return true
    end,
    HandsupDisableControls = function()
        
    end,
    HandsupEnableControls = function()
        
    end,
    AnimalPeds = {
        "a_c_boar",
        "a_c_cat_01",
        "a_c_chickenhawk",
        "a_c_chimp",
        "a_c_chop",
        "a_c_cormorant",
        "a_c_cow",
        "a_c_coyote",
        "a_c_crow",
        "a_c_deer",
        "a_c_dolphin",
        "a_c_fish",
        "a_c_hen",
        "a_c_humpback",
        "a_c_husky",
        "a_c_killerwhale",
        "a_c_mtlion",
        "a_c_pig",
        "a_c_pigeon",
        "a_c_poodle",
        "a_c_pug",
        "a_c_rabbit_01",
        "a_c_rat",
        "a_c_retriever",
        "a_c_rhesus",
        "a_c_rottweiler",
        "a_c_seagull",
        "a_c_sharkhammer",
        "a_c_sharktiger",
        "a_c_shepherd",
        "a_c_stingray",
        "a_c_westy"
    },
    AnimFlag = {
        MOVING = 51,
        LOOP = 1,
        STUCK = 50,
    },
    ScenarioType = {
        MALE = 'MaleScenario',
        SCENARIO = 'Scenario',
        OBJECT = 'ScenarioObject',
    },
    VehicleRequirement = {
        NOT_ALLOWED = 'NOT_ALLOWED',
        REQUIRED = 'REQUIRED',
    },
    AnimPos = {
        Enable = true,
        MaxDistance = 10.0,
        MaxHeightDistance = 5.0,  
    },
    Categories = {
        General = true,
        Extra = true,
        Expressions = true,
        Dances = true,
        Walks = true,
        PlacedEmotes = true,
        Shared = true,
        PropEmotes = true,
        AnimalEmotes = true,
        Gang = true
    },
    GangEmotePropMenuCommand = "gangemoteprops",
    GangEmotePropMenuKey = "O",
    GangEmotePropMenuInfoCommand = "gangemotepropsinfo",
    GangEmotePropMenuInfoKey = "I",
    GangEmotePropMenu = "built-in", 
    GangEmoteProps = {
        {objName = "w_pi_pistol", label = "Pistol", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_combatpistol", label = "Combat Pistol", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_pistol50", label = "Pistol .50", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_sns_pistol", label = "SNS Pistol", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_heavypistol", label = "Heavy Pistol", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_vintage_pistol", label = "Vintage Pistol", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_appistol", label = "AP Pistol", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_stungun", label = "Stun Gun", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_pistolmk2", label = "Pistol Mk II", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_sns_pistolmk2", label = "SNS Pistol Mk II", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_revolvermk2", label = "Heavy Revolver Mk II", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_pistol_luxe", label = "Pistol Luxe", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_combatpistol_luxe", label = "Combat Pistol Luxe", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_pistol50_luxe", label = "Pistol .50 Luxe", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_sns_pistol_luxe", label = "SNS Pistol Luxe", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_heavypistol_luxe", label = "Heavy Pistol Luxe", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }},
        {objName = "w_pi_appistol_luxe", label = "AP Pistol Luxe", handOffsets = {
            rightHand = {pos = {0.15, 0.03, -0.01}, rot = {-30.0, 0.0, 0.0}},
            leftHand  = {pos = {0.15, 0.03, -0.01}, rot = {235.0, 0.0, 0.0}}
        }}
    }
}
