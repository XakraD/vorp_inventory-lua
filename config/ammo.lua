-- max ammo allowed to transfer between players
SharedData.MaxAmmo    = {
    AMMO_PISTOL = 100,
    AMMO_PISTOL_EXPRESS = 100,
    AMMO_PISTOL_EXPRESS_EXPLOSIVE = 10,
    AMMO_PISTOL_HIGH_VELOCITY = 100,
    AMMO_PISTOL_SPLIT_POINT = 50,
    AMMO_REPEATER = 200,
    AMMO_REPEATER_EXPRESS = 200,
    AMMO_REPEATER_EXPRESS_EXPLOSIVE = 10,
    AMMO_REPEATER_HIGH_VELOCITY = 200,
    AMMO_REPEATER_SPLIT_POINT = 100,
    AMMO_REVOLVER = 200,
    AMMO_REVOLVER_EXPRESS = 200,
    AMMO_REVOLVER_EXPRESS_EXPLOSIVE = 10,
    AMMO_REVOLVER_HIGH_VELOCITY = 200,
    AMMO_REVOLVER_SPLIT_POINT = 100,
    AMMO_RIFLE = 100,
    AMMO_RIFLE_ELEPHANT = 20,
    AMMO_RIFLE_EXPRESS = 100,
    AMMO_RIFLE_EXPRESS_EXPLOSIVE = 10,
    AMMO_RIFLE_HIGH_VELOCITY = 100,
    AMMO_RIFLE_SPLIT_POINT = 50,
    AMMO_22 = 100,
    AMMO_22_TRANQUILIZER = 200,
    AMMO_SHOTGUN = 60,
    AMMO_SHOTGUN_BUCKSHOT_INCENDIARY = 14,
    AMMO_SHOTGUN_SLUG_EXPLOSIVE = 10,
    AMMO_SHOTGUN_SLUG = 60,
    AMMO_ARROW = 40,
    AMMO_ARROW_DYNAMITE = 8,
    AMMO_ARROW_FIRE = 8,
    AMMO_ARROW_IMPROVED = 40,
    AMMO_ARROW_SMALL_GAME = 40,
    AMMO_ARROW_POISON = 8,
    AMMO_THROWING_KNIVES = 8,
    AMMO_TOMAHAWK = 3,
    AMMO_POISONBOTTLE = 8,
    AMMO_BOLAS = 3,
    AMMO_BOLAS_HAWKMOTH = 3,
    AMMO_BOLAS_INTERTWINED = 3,
    AMMO_BOLAS_IRONSPIKED = 3,
    AMMO_DYNAMITE = 8,
    AMMO_DYNAMITE_VOLATILE = 3,
    AMMO_MOLOTOV = 8,
    AMMO_MOLOTOV_VOLATILE = 8,
    AMMO_HATCHET_CLEAVER = 1,
    AMMO_HATCHET_HUNTER = 1,
    AMMO_HATCHET_DOUBLE_BIT = 1,
    AMMO_HATCHET_HEWING = 1,
    AMMO_HATCHET_VIKING = 1,
    AMMO_HATCHET = 1,
    AMMO_MOONSHINEJUG_MP = 100,
}

-- you can change this to your language
SharedData.AmmoLabels = {

    AMMO_PISTOL = "Normal Pistol",
    AMMO_PISTOL_EXPRESS = "Express Pistol",
    AMMO_PISTOL_EXPRESS_EXPLOSIVE = "Explosives Pistol",
    AMMO_PISTOL_HIGH_VELOCITY = "Velocity Pistol",
    AMMO_PISTOL_SPLIT_POINT = "Splitpoint Pistol",
    AMMO_REPEATER = "Normal Repeater",
    AMMO_REPEATER_EXPRESS = "Express Repeater",
    AMMO_REPEATER_EXPRESS_EXPLOSIVE = "Explosives Repeater",
    AMMO_REPEATER_HIGH_VELOCITY = "Velocity Repeater",
    AMMO_REPEATER_SPLIT_POINT = "Splitpoint Repeater",
    AMMO_REVOLVER = "Normal Revolver",
    AMMO_REVOLVER_EXPRESS = "Express Revolver",
    AMMO_REVOLVER_EXPRESS_EXPLOSIVE = "Explosives Revolver",
    AMMO_REVOLVER_HIGH_VELOCITY = "Velocity Revolver",
    AMMO_REVOLVER_SPLIT_POINT = "Splitpoint Revolver",
    AMMO_RIFLE = "Normal Rifle",
    AMMO_RIFLE_ELEPHANT = "Elephant Rifle",
    AMMO_RIFLE_EXPRESS = "Express Rifle",
    AMMO_RIFLE_EXPRESS_EXPLOSIVE = "Explosives Rifle",
    AMMO_RIFLE_HIGH_VELOCITY = "Velocity Rifle",
    AMMO_RIFLE_SPLIT_POINT = "Splitpoint Rifle",
    AMMO_22 = "22 Rifle",
    AMMO_22_TRANQUILIZER = "22 Tranquilizer Rifle",
    AMMO_SHOTGUN = "Normal Shotgun",
    AMMO_SHOTGUN_BUCKSHOT_INCENDIARY = "Incendiary Shotgun",
    AMMO_SHOTGUN_SLUG_EXPLOSIVE = "Explosive Shotgun",
    AMMO_SHOTGUN_SLUG = "Slug Shotgun",
    AMMO_ARROW = "Normal Arrows",
    AMMO_ARROW_DYNAMITE = "Dynamite Arrows",
    AMMO_ARROW_FIRE = "Fire Arrows",
    AMMO_ARROW_IMPROVED = "Improved Arrows",
    AMMO_ARROW_SMALL_GAME = "Small Game Arrows",
    AMMO_ARROW_POISON = "Poison Arrows",
    AMMO_THROWING_KNIVES = "Throwing Knives",
    AMMO_TOMAHAWK = "Tomahawk",
    AMMO_POISONBOTTLE = "Poison Bottle",
    AMMO_BOLAS = "Bolas",
    AMMO_BOLAS_HAWKMOTH = "Hawkmoth Bolas",
    AMMO_BOLAS_INTERTWINED = "Intertwined Bolas",
    AMMO_BOLAS_IRONSPIKED = "Ironspiked Bolas",
    AMMO_DYNAMITE = "Dynamite",
    AMMO_DYNAMITE_VOLATILE = 'Volatile Dynamite',
    AMMO_MOLOTOV = "Molotov",
    AMMO_MOLOTOV_VOLATILE = "Volatile Molotov",
    AMMO_HATCHET_CLEAVER = "Cleaver Hatchet",
    AMMO_HATCHET_HUNTER = "Hunter Hatchet",
    AMMO_HATCHET_DOUBLE_BIT = "Hachet Double Bit",
    AMMO_HATCHET_HEWING = "Hachet Hewing",
    AMMO_HATCHET_VIKING = "Hachet Viking",
    AMMO_HATCHET = "Hatchet ammo",
    AMMO_MOONSHINEJUG_MP = "Moonshine Liters",
}

-- dont touch this
SharedData.AmmoTypes  = {

    [`GROUP_PISTOL`] = {
        AMMO_PISTOL = "AMMO_PISTOL",
        AMMO_PISTOL_EXPRESS = "AMMO_PISTOL_EXPRESS",
        AMMO_PISTOL_EXPRESS_EXPLOSIVE = "AMMO_PISTOL_EXPRESS_EXPLOSIVE",
        AMMO_PISTOL_HIGH_VELOCITY = "AMMO_PISTOL_HIGH_VELOCITY",
        AMMO_PISTOL_SPLIT_POINT = "AMMO_PISTOL_SPLIT_POINT"
    },
    [`GROUP_REPEATER`] = {
        AMMO_REPEATER = "AMMO_REPEATER",
        AMMO_REPEATER_EXPRESS = "AMMO_REPEATER_EXPRESS",
        AMMO_REPEATER_EXPRESS_EXPLOSIVE = "AMMO_REPEATER_EXPRESS_EXPLOSIVE",
        AMMO_REPEATER_HIGH_VELOCITY = "AMMO_REPEATER_HIGH_VELOCITY",
        AMMO_REPEATER_SPLIT_POINT = "AMMO_REPEATER_SPLIT_POINT"
    },
    [`GROUP_REVOLVER`] = {
        AMMO_REVOLVER = "AMMO_REVOLVER",
        AMMO_REVOLVER_EXPRESS = "AMMO_REVOLVER_EXPRESS",
        AMMO_REVOLVER_EXPRESS_EXPLOSIVE = "AMMO_REVOLVER_EXPRESS_EXPLOSIVE",
        AMMO_REVOLVER_HIGH_VELOCITY = "AMMO_REVOLVER_HIGH_VELOCITY",
        AMMO_REVOLVER_SPLIT_POINT = "AMMO_REVOLVER_SPLIT_POINT",
    },
    [`GROUP_RIFLE`] = {
        AMMO_RIFLE = "AMMO_RIFLE",
        AMMO_RIFLE_ELEPHANT = "AMMO_RIFLE_ELEPHANT",
        AMMO_RIFLE_EXPRESS = "AMMO_RIFLE_EXPRESS",
        AMMO_RIFLE_EXPRESS_EXPLOSIVE = "AMMO_RIFLE_EXPRESS_EXPLOSIVE",
        AMMO_RIFLE_HIGH_VELOCITY = "AMMO_RIFLE_HIGH_VELOCITY",
        AMMO_RIFLE_SPLIT_POINT = "AMMO_RIFLE_SPLIT_POINT",
        AMMO_22 = "AMMO_22",
        AMMO_22_TRANQUILIZER = "AMMO_22_TRANQUILIZER"
    },
    [`GROUP_SNIPER`] = {
        AMMO_RIFLE = "AMMO_RIFLE",
        AMMO_RIFLE_EXPRESS = "AMMO_RIFLE_EXPRESS",
        AMMO_RIFLE_EXPRESS_EXPLOSIVE = "AMMO_RIFLE_EXPRESS_EXPLOSIVE",
        AMMO_RIFLE_HIGH_VELOCITY = "AMMO_RIFLE_HIGH_VELOCITY",
        AMMO_RIFLE_SPLIT_POINT = "AMMO_RIFLE_SPLIT_POINT"
    },
    [`GROUP_SHOTGUN`] = {
        AMMO_SHOTGUN = "AMMO_SHOTGUN",
        AMMO_SHOTGUN_BUCKSHOT_INCENDIARY = "AMMO_SHOTGUN_BUCKSHOT_INCENDIARY",
        AMMO_SHOTGUN_SLUG_EXPLOSIVE = "AMMO_SHOTGUN_SLUG_EXPLOSIVE",
        AMMO_SHOTGUN_SLUG = "AMMO_SHOTGUN_SLUG"
    },
    [`GROUP_BOW`] = {
        AMMO_ARROW = "AMMO_ARROW",
        AMMO_ARROW_DYNAMITE = "AMMO_ARROW_DYNAMITE",
        AMMO_ARROW_FIRE = "AMMO_ARROW_FIRE",
        AMMO_ARROW_IMPROVED = "AMMO_ARROW_IMPROVED",
        AMMO_ARROW_SMALL_GAME = "AMMO_ARROW_SMALL_GAME",
        AMMO_ARROW_POISON = "AMMO_ARROW_POISON"
    },
    [`GROUP_THROWN`] = {
        AMMO_THROWING_KNIVES = "AMMO_THROWING_KNIVES",
        AMMO_TOMAHAWK = "AMMO_TOMAHAWK",
        AMMO_POISONBOTTLE = "AMMO_POISONBOTTLE",
        AMMO_BOLAS = "AMMO_BOLAS",
        AMMO_BOLAS_HAWKMOTH = "AMMO_BOLAS_HAWKMOTH",
        AMMO_BOLAS_INTERTWINED = "AMMO_BOLAS_INTERTWINED",
        AMMO_BOLAS_IRONSPIKED = "AMMO_BOLAS_IRONSPIKED",
        AMMO_DYNAMITE = "AMMO_DYNAMITE",
        AMMO_DYNAMITE_VOLATILE = "AMMO_DYNAMITE_VOLATILE",
        AMMO_MOLOTOV = "AMMO_MOLOTOV",
        AMMO_MOLOTOV_VOLATILE = "AMMO_MOLOTOV_VOLATILE",
        AMMO_HATCHET_HUNTER = "AMMO_HATCHET_HUNTER",
        AMMO_HATCHET_DOUBLE_BIT = "AMMO_HATCHET_DOUBLE_BIT",
        AMMO_HATCHET_HEWING = "AMMO_HATCHET_HEWING",
        AMMO_HATCHET_VIKING = "AMMO_HATCHET_VIKING",
        AMMO_HATCHET = "AMMO_HATCHET",
        AMMO_HATCHET_CLEAVER = "AMMO_HATCHET_CLEAVER",
    },
    -- [`GROUP_HELD`] = {}, -- for weapon kits like lanter binoculars
    [`GROUP_PETROLCAN`] = {
        AMMO_MOONSHINEJUG_MP = "AMMO_MOONSHINEJUG_MP",
    },
}
