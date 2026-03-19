# Riftbound - Setup Guide

## Step 1: Install Godot
1. Go to https://godotengine.org/download
2. Download **Godot 4.4** (standard, not .NET version)
3. Extract anywhere — it's a single executable, no installer needed

## Step 2: Open the Project
1. Launch Godot
2. Click **Import**
3. Browse to `Documents/Riftbound/` and select `project.godot`
4. Click **Import & Edit**

## Step 3: Play
1. Press **F5** (or the Play button at top-right)
2. The game should start immediately

## Controls
- **WASD** — Move
- **Auto-attack** — Happens automatically to nearest enemy

## What You'll See
- **Blue circle** = You (the player)
- **Red circles** = Melee enemies (chase you)
- **Yellow circles** = Ranged enemies (shoot from distance)
- **Dark red circles** = Tank enemies (slow, tough)
- **Purple circle** = Boss (spawns after 20 kills)
- **Cyan/teal circles** = Your thralls (bound shadows that fight for you)
- **"ARISE!"** text flashes when you extract a thrall

## How It Works
1. Enemies spawn in waves around you, getting faster over time
2. You auto-attack the nearest enemy
3. When an enemy dies, there's a 20-30% chance it gets **extracted** as a thrall
4. Thralls follow you and auto-attack enemies
5. After 20 kills, a **Boss** spawns — it has 300 HP and guaranteed extraction
6. If your HP hits 0, game over — click "Rise Again" to restart

## Project Structure
```
Riftbound/
├── project.godot          — Project config (inputs, autoloads, layers)
├── scenes/
│   ├── main.tscn          — Main scene (everything wired together)
│   ├── player.tscn        — Player character
│   ├── enemy_melee.tscn   — Red melee enemy
│   ├── enemy_ranged.tscn  — Yellow ranged enemy
│   ├── enemy_tank.tscn    — Dark red tank enemy
│   ├── boss.tscn          — Purple boss
│   ├── thrall.tscn        — Cyan thrall (your shadows)
│   ├── projectile.tscn    — Projectile for ranged attacks
│   ├── arise_vfx.tscn     — Arise extraction effect
│   └── game_ui.tscn       — HUD and game over screen
└── scripts/
    ├── game_manager.gd    — Global state (autoloaded as "Game")
    ├── player.gd          — Movement, auto-attack, extraction
    ├── enemy.gd           — Enemy AI (3 types)
    ├── boss.gd            — Boss with enrage + guaranteed extract
    ├── thrall.gd          — Thrall follow + fight AI
    ├── enemy_spawner.gd   — Wave spawner with scaling
    ├── projectile.gd      — Projectile behavior
    ├── arise_vfx.gd       — Expanding ring effect
    ├── game_ui.gd         — HUD controller
    └── placeholder_sprite.gd — Generates circle sprites for prototyping
```

## Troubleshooting
- **No sprites visible?** Make sure each Sprite2D node has the `placeholder_sprite.gd` script attached
- **Enemies don't take damage?** Check collision layers: Player = layer 1, Enemy = layer 2
- **Game doesn't start?** Make sure `Game` autoload is set in Project > Project Settings > Autoload
- **Input not working?** Check Project > Project Settings > Input Map for WASD bindings
