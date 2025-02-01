#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#define MAX_CHECKPOINTS 5
#define SpeedometerFREQ 0.05


new const Float: VEC_DUCK_HULL_MIN[3] = {-16.0, -16.0, -18.0};
new const Float: VEC_DUCK_HULL_MAX[3] = {16.0, 16.0, 32.0};
new const Float: VEC_DUCK_VIEW[3] = {0.0, 0.0, 12.0};
new const Float: VEC_NULL[3] = { 0.0, 0.0, 0.0};


new bool: plrSpeed[33]

new bool: g_bHasCheckpoint[33];
new g_CheckpointCount[33]; 
new totalCPCount[33];
new totalGCCount[33];
new Float: g_bCheckpointTimer[33][MAX_CHECKPOINTS];
new bool: g_timerstarted[33][MAX_CHECKPOINTS];

new Float: g_SpawnPosition[33][3];

new Float: g_bCheckpointOrigin[33][MAX_CHECKPOINTS][3];
new Float: g_bCheckpointAngle[33][MAX_CHECKPOINTS][3];
new Float: g_bCheckpointVelocity[33][MAX_CHECKPOINTS][3];
new Float: g_bCheckpointGravity[33][MAX_CHECKPOINTS]; 

new Float:g_HookDirection[33][3];
new surf_hook_speed

new Float: timer_time[33];
new bool: timer_started[33];
new Trie: g_tStarts;
new Trie: g_tStops;

new TaskEnt, SyncHudSpeedometer, showspeed, color, maxplayers, r, g, b

public plugin_init() {
    register_plugin("BurgerSurf", "1.0", "Hamburglar, Lopol2010, Andrew, AcidoX");

    register_clcmd("sg_cp", "SaveCheckpoint");
    register_clcmd("sg_gc", "fwTeleport");
    register_clcmd("say /lastcp", "RemoveCheckpoint");
    register_clcmd("say /setstart", "setstart");
    register_clcmd("say /start", "Gostart");
    register_clcmd("say /resetcounts", "reset_counts");
    register_clcmd("say /usp", "give_usp_command")
    register_clcmd("say /god", "surf_godmode");
    register_clcmd("say /nc", "surf_noclip");
    register_clcmd("+hook", "hook_on");
    register_clcmd("-hook", "hook_off");
    register_clcmd("say /ct", "SwitchToCT");
    register_clcmd("say /t", "SwitchToT");
    register_clcmd("say /spec", "SwitchToSpec");
    register_clcmd("say /speed", "toggleSpeed");
    register_clcmd("say /commands", "ShowCommands");

    surf_hook_speed = register_cvar("surf_hookspeed", "1000.0")
    showspeed = register_cvar("showspeed", "1")
    color = register_cvar("speed_colors", "255 255 255")

    set_task(0.2, "timer_task", 2000, "", 0, "b");
    RegisterHam(Ham_Use, "func_button", "fwdUse", 0);

    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawn", 1);

    g_tStarts = TrieCreate();
    g_tStops = TrieCreate();

    new
    const szStarts[][] = {
        "counter_start",
        "clockstartbutton",
        "firsttimerelay",
        "but_start",
        "counter_start_button",
        "multi_start",
        "timer_startbutton",
        "start_timer_emi",
        "gogogo"
    };

    new
    const szStops[][] = {
        "counter_off",
        "clockstopbutton",
        "clockstop",
        "but_stop",
        "counter_stop_button",
        "multi_stop",
        "stop_counter",
        "m_counter_end_emi"
    };

    for (new i = 0; i < sizeof(szStarts); i++)
        TrieSetCell(g_tStarts, szStarts[i], 1);

    for (new i = 0; i < sizeof(szStops); i++)
        TrieSetCell(g_tStops, szStops[i], 1);

    register_forward(FM_Think, "Think")
    TaskEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
    set_pev(TaskEnt, pev_classname, "speedometer_think")
    set_pev(TaskEnt, pev_nextthink, get_gametime() + 1.01)
    SyncHudSpeedometer = CreateHudSyncObj()

    maxplayers = get_maxplayers()

    new colors[16], red[4], green[4], blue[4]
    get_pcvar_string(color, colors, sizeof colors - 1)
    parse(colors, red, 3, green, 3, blue, 3)
    r = str_to_num(red)
    g = str_to_num(green)
    b = str_to_num(blue)
}

// ============================ Godmode/Noclip ==============================================================

public ShowCommands(id) {
    client_print(id, print_chat, "Commands printed in console.");
    client_print(id, print_console, "Available Commands:");
    client_print(id, print_console, "sg_cp - Save a checkpoint");
    client_print(id, print_console, "sg_gc - Teleport to the last checkpoint");
    client_print(id, print_console, "say /lastcp - Remove the last saved checkpoint");
    client_print(id, print_console, "say /setstart - Set the spawn position");
    client_print(id, print_console, "say /start - Teleport to the spawn position");
    client_print(id, print_console, "say /resetcounts - Reset checkpoint counts");
    client_print(id, print_console, "say /usp - Give USP pistol");
    client_print(id, print_console, "say /god - Toggle godmode");
    client_print(id, print_console, "say /nc - Toggle noclip");
    client_print(id, print_console, "+hook - Enable grappling hook");
    client_print(id, print_console, "say /ct - Switch to Counter-Terrorist team");
    client_print(id, print_console, "say /t - Switch to Terrorist team");
    client_print(id, print_console, "say /spec - Switch to Spectator team");
    client_print(id, print_console, "say /speed - Toggle speedometer");
    client_print(id, print_console, "amx_lights a-z|off - Change brightness: a=min, z=max, off=default");
    client_print(id, print_console, "say /pres - Toggle Prestrafe info");
}

// ============================ Checkpoint ==============================================================

public client_connect(id) {
    g_bHasCheckpoint[id] = false;
    g_CheckpointCount[id] = 0; 
    totalCPCount[id] = 0;
    totalGCCount[id] = 0;
}

public client_putinserver(id) {
    pev(id, pev_origin, g_SpawnPosition[id]); 
    plrSpeed[id] = showspeed > 0 ? true : false 
}

public setstart(id) {
    if (!is_user_alive(id)) {
        set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "You have to be alive to set the spawn position.");
        return PLUGIN_HANDLED;
    }

    pev(id, pev_origin, g_SpawnPosition[id]);
    set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
    show_hudmessage(id, "Spawn position set!");
    return PLUGIN_HANDLED;
}

public Gostart(id) {
    if (!is_user_alive(id)) {
        set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "You have to be alive to teleport to spawn.");
        return PLUGIN_HANDLED;
    }

    set_pev(id, pev_origin, g_SpawnPosition[id]);
    set_pev(id, pev_velocity, VEC_NULL);
    set_pev(id, pev_basevelocity, VEC_NULL);
    set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
    show_hudmessage(id, "Teleported to spawn position!");
    return PLUGIN_HANDLED;
}

public SaveCheckpoint(id) {
    if (!is_user_alive(id)) {
        set_hudmessage(190, 190, 190, -1.0, 0.25, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "You have to be alive to save the checkpoint.");
        return PLUGIN_HANDLED;
    }

    new index = g_CheckpointCount[id] % MAX_CHECKPOINTS;

    pev(id, pev_origin, g_bCheckpointOrigin[id][index]);
    pev(id, pev_v_angle, g_bCheckpointAngle[id][index]);
    pev(id, pev_gravity, g_bCheckpointGravity[id]);
    pev(id, pev_velocity, g_bCheckpointVelocity[id][index]);

    if (timer_started[id]) {
        g_bCheckpointTimer[id][index] = get_gametime() - timer_time[id];
        g_timerstarted[id][index] = true;
    } else {
        g_timerstarted[id][index] = false;
    }

    g_CheckpointCount[id]++;
    totalCPCount[id]++;
    g_bHasCheckpoint[id] = true;

    set_hudmessage(85, 157, 217, -1.0, 0.25, 0, 0.0, 0.75, 0.1, 0.2, 3);
    show_hudmessage(id, "CP %d saved", totalCPCount[id]);

    return PLUGIN_HANDLED;
}

public fwTeleport(id) {
    if (!is_user_alive(id)) {
        set_hudmessage(190, 190, 190, -1.0, 0.25, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "You have to be alive to teleport.");
        return PLUGIN_HANDLED;
    }

    if (!g_bHasCheckpoint[id]) {
        set_hudmessage(190, 190, 190, -1.0, 0.25, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "No checkpoints available.");
        return PLUGIN_HANDLED;
    }

    new latestIndex = (g_CheckpointCount[id] - 1) % MAX_CHECKPOINTS;

    LoadCheckpoint(id, latestIndex);

    return PLUGIN_HANDLED;
}

public LoadCheckpoint(id, index) {
    set_checkpoint(id, g_bCheckpointOrigin[id][index], g_bCheckpointAngle[id][index], g_bCheckpointVelocity[id][index]);

    if (g_timerstarted[id][index] == true) {
        timer_time[id] = get_gametime() - g_bCheckpointTimer[id][index];
    } else {
        timer_started[id] = false
    }

    totalGCCount[id]++;
    set_hudmessage(85, 157, 217, -1.0, 0.25, 0, 0.0, 0.75, 0.1, 0.2, 3);
    show_hudmessage(id, "CP %d | GC %d", totalCPCount[id], totalGCCount[id]);
}

public RemoveCheckpoint(id) {
    if (g_CheckpointCount[id] <= 0) {
        set_hudmessage(190, 190, 190, -1.0, 0.25, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "No CPs left (only last 5 are stored)");
        return PLUGIN_HANDLED;
    }

    g_CheckpointCount[id]--;
    new latestIndex = (g_CheckpointCount[id] - 1) % MAX_CHECKPOINTS;

    if (g_CheckpointCount[id] <= 0) {
        g_bHasCheckpoint[id] = false;
        set_hudmessage(190, 190, 190, -1.0, 0.25, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "All checkpoints removed!");
    } else {
        set_hudmessage(190, 190, 190, -1.0, 0.25, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "Checkpoint removed! Restoring previous checkpoint.");
        LoadCheckpoint(id, latestIndex);
    }

    return PLUGIN_HANDLED;
}

public reset_counts(id) { 
    totalCPCount[id] = 0;
    totalGCCount[id] = 0;

    g_CheckpointCount[id] = 0; 
    g_bHasCheckpoint[id] = false;

    timer_started[id] = false;
    timer_time[id] = 0.0;

    for (new i = 0; i < MAX_CHECKPOINTS; i++) {
        for (new j = 0; j < 3; j++) {
            g_bCheckpointOrigin[id][i][j] = 0.0;
            g_bCheckpointAngle[id][i][j] = 0.0;
            g_bCheckpointVelocity[id][i][j] = 0.0;
        }
        g_bCheckpointGravity[id][i] = 0.0;
    }

    set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
    show_hudmessage(id, "Checkpoint data and counts have been reset!");

    return PLUGIN_HANDLED;
}

set_checkpoint(id, Float: flOrigin[3], Float: flAngles[3], Float: flVelocity[3]) {
    new iFlags = pev(id, pev_flags);
    iFlags &= ~FL_BASEVELOCITY;
    iFlags |= FL_DUCKING;
    set_pev(id, pev_flags, iFlags);
    engfunc(EngFunc_SetSize, id, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX);
    engfunc(EngFunc_SetOrigin, id, flOrigin);
    set_pev(id, pev_view_ofs, VEC_DUCK_VIEW);

    set_pev(id, pev_v_angle, VEC_NULL);
    set_pev(id, pev_velocity, flVelocity);
    set_pev(id, pev_basevelocity, VEC_NULL);
    set_pev(id, pev_angles, flAngles);
    set_pev(id, pev_punchangle, VEC_NULL);
    set_pev(id, pev_fixangle, 1);

    set_pev(id, pev_gravity, flAngles[2]);

    set_pev(id, pev_fuser2, 0.0);
}

// ============================ USP/Knife giver ==============================================================

public give_usp_command(id) {
    if (!is_user_alive(id)) {
        set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
        show_hudmessage(id, "You need to be alive to use this command.");
        return PLUGIN_HANDLED;
    }

    strip_user_weapons(id);

    give_item(id, "weapon_knife");
    give_item(id, "weapon_usp");
    cs_set_user_bpammo(id, CSW_USP, 120);

    set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
    show_hudmessage(id, "You have been equipped with a USP and a knife!");

    return PLUGIN_HANDLED;
}

// ============================ Godmode/Noclip ==============================================================

public surf_godmode(id) {
    new admin_name[33]
    get_user_name(id, admin_name, 31)

    if (!get_user_godmode(id)) {
        set_user_godmode(id, 1)
        client_print(0, print_chat, "Enabled Godmode")
    } else {
        set_user_godmode(id, 0)
        client_print(0, print_chat, "Disabled Godmode")
    }
    return PLUGIN_HANDLED
}

public OnPlayerSpawn(id) {
    if (is_user_connected(id) && is_user_alive(id)) {
        set_user_godmode(id, 1);
        set_cvar_num("sv_airaccelerate", 100);
        client_print(id, print_chat, "You're using BurgerSurf. Type /commands for a list of features.");
        client_print(id, print_chat, "Godmode enabled by default.");
    }
    return PLUGIN_CONTINUE;
}

public surf_noclip(id) {
    new admin_name[33]
    get_user_name(id, admin_name, 31)

    if (!get_user_noclip(id)) {
        set_user_noclip(id, 1)
        client_print(0, print_chat, "Enabled NoClip")
    } else {
        set_user_noclip(id, 0)
        client_print(0, print_chat, "Disabled NoClip")
    }
    return PLUGIN_HANDLED
}

// ============================ Hook ==============================================================

public hook_on(id) {
    if (!is_user_alive(id)) return PLUGIN_HANDLED;
	
    VelocityByAim(id, get_pcvar_num(surf_hook_speed), g_HookDirection[id]);
    hook_task(id);
    set_task(0.1, "hook_task", id, "", 0, "ab");

    return PLUGIN_HANDLED;
}

public hook_off(id) {
    if (task_exists(id))
        remove_task(id);

    g_HookDirection[id][0] = 0.0;
    g_HookDirection[id][1] = 0.0;
    g_HookDirection[id][2] = 0.0;

    return PLUGIN_HANDLED;
}

public hook_task(id) {
    if (!is_user_connected(id) || !is_user_alive(id)) {
        return;
    }

    set_pev(id, pev_velocity, g_HookDirection[id]);
}


// ============================ Team Changer ==============================================================

public SwitchToCT(id) {
    cs_set_user_team(id, CS_TEAM_CT);
    set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
    show_hudmessage(id, "You have been moved to CT!");
    return PLUGIN_HANDLED;
}

public SwitchToT(id) {
    cs_set_user_team(id, CS_TEAM_T);
    set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
    show_hudmessage(id, "You have been moved to T!");
    return PLUGIN_HANDLED;
}

public SwitchToSpec(id) {
    set_user_health(id, 0);
    cs_set_user_team(id, CS_TEAM_SPECTATOR);
    set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
    show_hudmessage(id, "You have been moved to Spec!");
    return PLUGIN_HANDLED;
}

// ============================ SurfTimer ==============================================================

public fwdUse(ent, id) {
    if (!ent || id > 32) {
        return HAM_IGNORED;
    }

    new name[32];
    get_user_name(id, name, 31);
    new szTarget[32];
    pev(ent, pev_target, szTarget, 31);

    if (TrieKeyExists(g_tStarts, szTarget)) {
        start_surf(id); 
    }

    if (TrieKeyExists(g_tStops, szTarget)) {
        if (timer_started[id]) {
            finish_surf(id);
        } else {
            set_hudmessage(190, 190, 190, -1.0, 0.65, 0, 0.0, 2.0, 0.1, 0.2, 3);
            show_hudmessage(id, "Timer not started.");
        }
    }
    return HAM_IGNORED;
}

public start_surf(id) {
    for (new i = 0; i < MAX_CHECKPOINTS; i++) {
        g_bCheckpointTimer[id][i] = 0.0;
    }

    if (g_bHasCheckpoint[id] && g_CheckpointCount[id] > 0) {
        new latestIndex = (g_CheckpointCount[id] - 1) % MAX_CHECKPOINTS;
        timer_time[id] = get_gametime() - g_bCheckpointTimer[id][latestIndex];
    } else {
        timer_time[id] = get_gametime();
    }

    timer_started[id] = true;
}

public timer_task() {
    set_hudmessage(62, 91, 181, -1.0, 0.20, 0, 0.0, 0.4, 0.1, 0.2, 1);

    for (new id = 1; id <= 32; id++) {
        if (timer_started[id]) {
            new Float: kreedztime = get_gametime() - timer_time[id];
            new imin = floatround(kreedztime / 60.0, floatround_floor);
            new isec = floatround(kreedztime - imin * 60.0, floatround_floor);
            new ics = floatround((kreedztime - (imin * 60.0 + isec)) * 100.0, floatround_floor);

            show_hudmessage(id, "Time: %02d:%02d.%02d", imin, isec, ics);
        }
    }
}

public finish_surf(id) {
    new Float: time = get_gametime() - timer_time[id];
    timer_started[id] = false;

    new name[32];
    get_user_name(id, name, 31);
    new imin = floatround(time / 60.0, floatround_floor);
    new isec = floatround(time - imin * 60.0, floatround_floor);
    new ics = floatround((time - (imin * 60.0 + isec)) * 100.0, floatround_floor);

    client_print(id, print_chat, "%s finished in %02d:%02d.%02d", name, imin, isec, ics);
    client_cmd(0, "spk buttons/bell1");
}

// ============================ Speedometer ==============================================================

public Think(ent) {
    if (ent == TaskEnt) {
        SpeedTask()
        set_pev(ent, pev_nextthink, get_gametime() + SpeedometerFREQ)
    }
}

public toggleSpeed(id) {
    plrSpeed[id] = plrSpeed[id] ? false : true
    return PLUGIN_HANDLED
}

SpeedTask() {
    static i, target
    static Float: velocity[3]
    static Float: speedh

    for (i = 1; i <= maxplayers; i++) {
        if (!is_user_connected(i)) continue
        if (!plrSpeed[i]) continue

        target = pev(i, pev_iuser1) == 4 ? pev(i, pev_iuser2) : i
        pev(target, pev_velocity, velocity)

        speedh = floatsqroot(floatpower(velocity[0], 2.0) + floatpower(velocity[1], 2.0))
        set_hudmessage(r, g, b, -1.0, 0.7, 0, 0.0, SpeedometerFREQ, 0.01, 0.0, 4)
        ShowSyncHudMsg(i, SyncHudSpeedometer, "%.0f", speedh)
    }
}