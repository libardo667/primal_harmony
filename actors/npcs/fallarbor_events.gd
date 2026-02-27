extends Node

@onready var dialogue_manager = get_node("/root/DialogueManager")
@onready var quest_manager = get_node("/root/QuestManager")
@onready var ehi_manager = get_node("/root/EHI")

func trigger_nurse_joy_fallarbor() -> void:
    if not quest_manager.get_flag("NURSE_JOY_INTRO_SEEN"):
        quest_manager.set_flag("NURSE_JOY_INTRO_SEEN", true)
        dialogue_manager.play_dialogue([
            "Welcome to the Fallarbor Town Pokemon Center or... what's left of it.",
            "I'm Nurse Joy. With the Ashen Glacier pressing in, supplies are tight.",
            "Are you a Rehabilitator? Oh, thank goodness.",
            "We've set up a [color=blue]Relocation Terminal[/color] over there.",
            "If you catch any of those invasive Ice-types, you can use it to transfer them to a better habitat.",
            "Every relocation helps us thaw out Route 113. Please, we need your help."
        ], "Nurse Joy")
        return

    var ehi_state = ehi_manager.get_global_ehi()
    if ehi_state < 33.0:
        dialogue_manager.play_dialogue([
            "Welcome to the Fallarbor Town Pokemon Center.",
            "Please use the Relocation Terminal if you catch any invasive Ice-types.",
            "We're slowly freezing over here..."
        ], "Nurse Joy")
    elif ehi_state < 66.0:
        dialogue_manager.play_dialogue([
            "Welcome to the Fallarbor Town Pokemon Center!",
            "The ice on the route seems to be thinning a bit. Keep up the good work!"
        ], "Nurse Joy")
    else:
        dialogue_manager.play_dialogue([
            "Welcome to the Fallarbor Town Pokemon Center!",
            "With the ash no longer freezing, the town is finally breathing again.",
            "Thank you so much for your relocation efforts!"
        ], "Nurse Joy")

func trigger_relocation_terminal_bot_fallarbor() -> void:
    # This acts as the interactable for the terminal itself.
    dialogue_manager.play_dialogue([
        "[System] Relocation Terminal Online.",
        "[System] Habitat matching systems active.",
        "[System] Insert Pokeball to begin ecological transfer..."
    ], "Terminal")
    # Await standard UI prompt for relocation minigame/menu, left mocked

func trigger_child_m_fallarbor_01() -> void:
    var ehi_state = ehi_manager.get_global_ehi()
    if ehi_state < 66.0:
        dialogue_manager.play_dialogue([
            "It's too cold to play outside.",
            "My Spinda is shivering all the time now."
        ], "Boy")
    else:
        dialogue_manager.play_dialogue([
            "Yay! It's finally warming up!",
            "I'm gonna go play in the ash drifts!"
        ], "Boy")

func trigger_child_f_fallarbor_01() -> void:
    var ehi_state = ehi_manager.get_global_ehi()
    if ehi_state < 66.0:
        dialogue_manager.play_dialogue([
            "The flower shop is closed until it gets warmer.",
            "I wanted to make a pretty glass flute..."
        ], "Girl")
    else:
        dialogue_manager.play_dialogue([
            "The flower shop is back open!",
            "We've been waiting forever to see the soot sacks again."
        ], "Girl")

func trigger_researcher_fallarbor_01() -> void:
    dialogue_manager.play_dialogue([
        "The [color=blue]Type Overload Zone[/color] on Route 113 is fascinating, but terrifying.",
        "Ice-types flooding a volcanic ash plain...",
        "It's creating a microclimate that defies all known ecosystem models."
    ], "Researcher")

func trigger_hiker_fallarbor_01() -> void:
    var ehi_state = ehi_manager.get_global_ehi()
    if ehi_state < 66.0:
        dialogue_manager.play_dialogue([
            "I came to hike Mt. Chimney, but the ash is frozen solid!",
            "I didn't pack for a blizzard!"
        ], "Hiker")
    else:
        dialogue_manager.play_dialogue([
            "The ice is melting! Time to hit the ash trails!",
            "Mt. Chimney, here I come!"
        ], "Hiker")
