# Counter-Strike 1.6 Surf Addons Pack
Given the lack of addon options for single-player surf practice and map testing, this pack seeks to fill the gap by providing useful tools and features in a lightweight plugin. Unlike traditional KZ addon packs, this is not intended for recording legal demos for platforms like XJ or Cosy Climbing.

FEATURES
Checkpoint system: saves up to 5 checkpoints with speed and angles
Surf Timer: works with CP system - CPs save and restore run time for speedrun practice
Speedometer: higher update rate than server/KZ speedometers, more suitable for surfing
GodMode/NoClip
USP & Knife giver
Hook
Team Changer

INSTALLATION
(ensure Metamod and AMX Mod X are already installed on your game)
1. Place BurgerSurf.amxx into the cstrike/addons/amxmodx/plugins/ directory.
2. Open the plugins.ini file located at cstrike/addons/amxmodx/configs/.
3. Add the line BurgerSurf at the end of the file.
4. (Re)start your server to apply the changes.

AVAILABLE COMMANDS
This pack offers commands similar to those used on Surf Gateway (speedrun.eu) servers.

Checkpoint and teleports:
sg_cp - Save a checkpoint.
sg_gc - Teleport to the last checkpoint.
say /lastcp - Remove the last saved checkpoint.
say /setstart - Set the spawn position.
say /start - Teleport to the spawn position.
say /resetcounts - Reset checkpoint counts.

Utilities:
say /usp - Give a USP pistol.
say /god - Toggle god mode.
say /nc - Toggle noclip mode.
say /speed - Toggle the speedometer.
+hook - Enable the grappling hook.

Team Switching:
say /ct - Switch to Counter-Terrorist team.
say /t - Switch to Terrorist team.
say /spec - Switch to Spectator team.

PLANNED FEATURES
Prestrafe speed shower
Surf Metrics: % loss in ramp landings + mid-air strafe synchronization.
Add sound effects

