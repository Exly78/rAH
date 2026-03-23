# Hollow Veil — Combat System Documentation

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture Overview](#2-architecture-overview)
3. [File Structure](#3-file-structure)
4. [Client Systems](#4-client-systems)
   - [MainScript](#41-mainscript)
   - [CharacterController](#42-charactercontroller)
   - [InputController](#43-inputcontroller)
   - [MovementController](#44-movementcontroller)
   - [CombatController](#45-combatcontroller)
5. [State Machine](#5-state-machine)
   - [StateMachine](#51-statemachine)
   - [State Base Class](#52-state-base-class)
   - [Idle](#53-idle)
   - [Attack](#54-attack)
   - [Block](#55-block)
   - [Dodge](#56-dodge)
   - [Hitstun](#57-hitstun)
   - [KnockedOut](#58-knockedout)
   - [Slide](#59-slide)
6. [Server Systems](#6-server-systems)
   - [CombatServer](#61-combatserver)
   - [WeaponServer](#62-weaponserver)
   - [DefenseServer](#63-defenseserver)
   - [HitboxServer](#64-hitboxserver)
7. [Server Managers](#7-server-managers)
   - [ServerHealthManager](#71-serverhealthmanager)
   - [ServerCombatManager](#72-servercombatmanager)
   - [ServerCriticalManager](#73-servercriticalmanager)
   - [ServerStatusManager](#74-serverstatusmanager)
8. [Client Managers](#8-client-managers)
   - [HitboxManager](#81-hitboxmanager)
   - [AnimationManager](#82-animationmanager)
   - [TagManager](#83-tagmanager)
9. [Data Configuration](#9-data-configuration)
   - [WeaponData](#91-weapondata)
   - [SkillData](#92-skilldata)
   - [StatusEffectData](#93-statuseffectdata)
   - [ClassData & PerkData](#94-classdata--perkdata)
10. [Remotes (Networking)](#10-remotes-networking)
11. [UI Systems](#11-ui-systems)
12. [Combat Flow (End to End)](#12-combat-flow-end-to-end)
13. [Anti-Cheat Design](#13-anti-cheat-design)
14. [Adding New Content](#14-adding-new-content)

---

## 1. Project Overview

Hollow Veil is a multiplayer action RPG combat system built for Roblox. It features:

- A **state machine** that controls every character action (attacking, blocking, dodging, sliding, hitstun, knockedout)
- A **server-authoritative** combat model — clients propose actions, the server validates and applies all damage
- **Hidden HP** — real health values are stored server-side only; clients cannot read or manipulate HP
- A **combo system** with up to 5 chained attacks and a queue system for responsive input
- **Parry, block, and dodge** as distinct defensive options, each with different interactions against different attack types
- **Critical attacks** with single-phase and multi-phase (two-stage) variants
- A **status effect system** supporting stackable effects that trigger on hit, on action, or on a timer
- A **slide/crouch system** with realistic slope physics
- **Server-side anti-cheat** including skill authorization tokens, hitbox distance validation, spam rate limiting, and combo sequence validation

---

## 2. Architecture Overview

The project follows a strict **client-server split**:

```
CLIENT                          SERVER
------                          ------
MainScript                      CombatServer (entry point)
  └─ CharacterController          ├─ WeaponServer
       ├─ InputController         ├─ DefenseServer
       ├─ MovementController      └─ HitboxServer
       ├─ CombatController
       └─ StateMachine            ServerHealthManager
            ├─ IdleState          ServerCombatManager
            ├─ AttackState        ServerCriticalManager
            ├─ BlockState         ServerStatusManager
            ├─ DodgeState         ServerWeaponManager
            ├─ HitstunState
            ├─ KnockedOutState
            └─ SlideState
```

**Key principle:** The client handles visuals, animation, and input. The server handles all damage, hit validation, and state tags. Clients fire remotes to *request* actions; the server decides whether they succeed.

---

## 3. File Structure

```
hv source code basically/
│
├── ReplicatedStorage/Modules/
│   ├── Controllers/
│   │   ├── CharacterController.lua   — Main character orchestrator
│   │   ├── CombatController.lua      — Weapon equip, combos, attacks
│   │   ├── InputController.lua       — Keyboard/mouse input capture
│   │   └── MovementController.lua    — Walk speed, sprint, animations
│   │
│   ├── Data/
│   │   ├── WeaponData.lua            — All weapon definitions
│   │   ├── SkillData.lua             — All skill/attack definitions
│   │   ├── StatusEffectData.lua      — Status effect definitions
│   │   ├── ClassData.lua             — Character class definitions
│   │   └── PerkData.lua              — Perk system definitions
│   │
│   ├── Managers/
│   │   ├── AnimationManager.lua      — Animation playback
│   │   ├── HitboxManager.lua         — Client-side hitbox queries
│   │   ├── TagManager.lua            — Tag-based state flags
│   │   └── CombatManager.lua         — Client combat coordination
│   │
│   ├── Remotes/
│   │   └── CombatRemotes.lua         — All RemoteEvent definitions
│   │
│   ├── StateMachine/
│   │   ├── State.lua                 — Base state class
│   │   ├── StateMachine.lua          — State machine core
│   │   └── States/
│   │       ├── Idle.lua
│   │       ├── Attack.lua
│   │       ├── Block.lua
│   │       ├── Dodge.lua
│   │       ├── Hitstun.lua
│   │       ├── KnockedOut.lua
│   │       └── Slide.lua
│   │
│   └── Weapons/
│       ├── WeaponManager.lua         — Client weapon model management
│       └── Sword.lua                 — Sword weapon implementation
│
├── ServerScriptService/
│   ├── CombatServer.lua              — Server entry point
│   ├── ProgressionServer.lua         — Progression system bootstrap
│   └── Services/
│       ├── PlayerDataService.lua     — Player data persistence
│       └── ProgressionService.lua    — Stat calculations
│
├── ServerStorage/Modules/
│   ├── Handlers/
│   │   ├── WeaponServer.lua          — Weapon remote handlers
│   │   ├── DefenseServer.lua         — Dodge/block/parry handlers
│   │   └── HitboxServer.lua          — Skill auth + hitbox handlers
│   │
│   └── Managers/
│       ├── ServerHealthManager.lua   — Hidden HP system
│       ├── ServerCombatManager.lua   — Hit validation + damage
│       ├── ServerCriticalManager.lua — Critical attack logic
│       └── ServerStatusManager.lua   — Status effect processing
│
└── StarterPlayer/StaterPlayerScripts/
    ├── MainScript.lua                — Client entry point + input
    ├── HealthListner.lua             — HP bar + posture UI
    ├── StatusEffectListener.lua      — Status effect UI
    └── ProgressionUI.lua             — Leveling UI
```

---

## 4. Client Systems

### 4.1 MainScript

**Location:** `StarterPlayer/StaterPlayerScripts/MainScript.lua`

The client entry point. Runs when the player spawns. Responsibilities:
- Creates the `CharacterController` for the local player
- Registers all keyboard/mouse input bindings
- Runs the main `controller:Update(dt)` loop every Heartbeat

**Input bindings:**

| Key | Action | Debounce |
|-----|--------|----------|
| Left Click | Basic attack | State machine (must be Idle or Attack) |
| R | Critical attack | State machine (must be Idle) |
| Q | Dodge | 0.65s client-side cooldown |
| F (tap/hold) | Block / Parry | 0.5s client-side cooldown |
| E | Equip / Unequip weapon | `_isEquipping` flag in CombatController |
| Space | Jump / Slide jump cancel | 0.3s debounce |
| Left Ctrl | Slide / Crouch | Consumed once per press |

**Debounce strategy:** Three layers of protection on each action:
1. Client-side timestamp check (prevents spam before anything is sent)
2. State machine guard (e.g. can't dodge while already dodging)
3. Server-side cooldown validation (final authority)

---

### 4.2 CharacterController

**Location:** `ReplicatedStorage/Modules/Controllers/CharacterController.lua`

The central hub for a character. Owns all sub-controllers and the state machine. Every other system talks through or to this class.

**Key properties:**

| Property | Type | Description |
|----------|------|-------------|
| `Character` | Model | The Roblox character model |
| `Humanoid` | Humanoid | The character's Humanoid |
| `RootPart` | BasePart | HumanoidRootPart |
| `StateMachine` | StateMachine | The character's state machine |
| `CombatController` | CombatController | Combat logic |
| `MovementController` | MovementController | Movement logic |
| `InputController` | InputController | Input reading |
| `AnimationManager` | AnimationManager | Animation playback |
| `WantsDodge` | bool | Set by input, consumed by IdleState |
| `WantsBlock` | bool | Set by input, consumed by IdleState |
| `WantsSlide` | bool | Set by input, consumed by IdleState |
| `IsHoldingBlock` | bool | Whether F is held down |
| `IsHoldingCrouch` | bool | Whether Ctrl is held down |
| `IsInvulnerableFlag` | bool | Manual invulnerability override |

**`Update(dt)`** — called every Heartbeat:
1. Gets move vector from InputController
2. Updates MovementController
3. Updates CombatController (combo reset timer)
4. Updates StateMachine (current state's Update)

**`IsInvulnerable()`** — returns true if:
- `IsInvulnerableFlag` is set, OR
- Currently in Dodge state, OR
- Has the `CanParry` tag (active parry window)

**`IsVulnerable()`** — returns true if not dodging, not in hitstun, not invulnerable, and not in parry window.

---

### 4.3 InputController

**Location:** `ReplicatedStorage/Modules/Controllers/InputController.lua`

Tracks raw keyboard state and handles the double-tap sprint detection.

**Sprint logic:** Double-tapping W (or any movement key in non-shift-lock mode) within `0.3s` toggles `SprintToggled`. MovementController reads this flag each frame.

**`GetMoveVector()`** — returns a `Vector3` from WASD keys, used by MovementController to set humanoid movement direction.

---

### 4.4 MovementController

**Location:** `ReplicatedStorage/Modules/Controllers/MovementController.lua`

Controls walk speed and sprint animations.

**Walk speeds:**

| State | Speed |
|-------|-------|
| Unequipped normal | 16 |
| Unequipped sprint | 26 |
| Equipped normal | 14 |
| Equipped sprint | 26 |
| Movement locked | 4 |

**Movement locked states:** Attack, Hitstun, KnockedOut — the character cannot move normally in these states.

**Sprint animation logic:** Uses edge detection — the animation only starts/stops when the sprint state *changes*, not every frame. This prevents animation flickering.

`ForceStopSprintAnimation()` — immediate stop (0s blend), used when entering combat actions.
`StopSprintAnimation()` — smooth stop (0.15s blend), used on normal sprint end.
`TryResumeSprint()` — re-arms the edge detection after a dodge so sprint resumes naturally.

---

### 4.5 CombatController

**Location:** `ReplicatedStorage/Modules/Controllers/CombatController.lua`

Handles weapon equip/unequip, combo tracking, and initiating attacks.

**Equip/Unequip debounce:** `_isEquipping` boolean is set when equip or unequip starts, and cleared when the animation's `Weld` marker fires (or after a 1.5s timeout fallback). Prevents spamming E.

**Combo system:**

| Property | Default | Description |
|----------|---------|-------------|
| `ComboCount` | 0 | Current combo step (1–5) |
| `ComboResetTimer` | 0 | Countdown until combo resets |
| `COMBO_CONFIG.RESET_DELAY` | 1.5s | Time before combo resets |
| `COMBO_CONFIG.MAX_COUNT` | 5 | Max combo steps |
| `QueuedAttack` | false | Whether an attack is queued |
| `CanQueueNextAttack` | false | Window when queuing is allowed |

**`PerformBasicAttack()`:**
1. If in Attack state and queuing is open → queue the next attack
2. If not in Idle → ignore
3. Otherwise → advance combo, play animation, transition to AttackState

**`PerformCriticalAttack()`:**
- Checks `AltCrit` attribute on character
- If false → Phase 1 (opener)
- If true → Phase 2 (follow-up, only available after Phase 1 lands)

**Remote listeners setup in constructor:**
- `ApplyHitstun` → calls `ApplyHitstun()` if target matches this character
- `DodgeSuccess` → calls `OnDodgeSuccess()` on DodgeState
- `ParrySuccess` → calls `OnParrySuccess()` on BlockState
- `GotParried` → plays the parried animation

---

## 5. State Machine

### 5.1 StateMachine

**Location:** `ReplicatedStorage/Modules/StateMachine/StateMachine.lua`

A simple but effective finite state machine.

**`SetState(name, payload)`:**
1. Finds the state by name
2. Calls `CanTransitionTo(name)` on the current state — if blocked, returns false
3. Calls `OnExit()` on current state
4. Sets new state and calls `OnEnter(payload)`

**`Update(dt)`** — calls `Update(dt)` on the current state every frame.

States communicate back to the owner (CharacterController) through `self:GetOwner()` which traverses `state.StateMachine.Owner`.

---

### 5.2 State Base Class

**Location:** `ReplicatedStorage/Modules/StateMachine/State.lua`

Every state inherits from this. Provides:
- `Name` — the state's identifier string
- `Priority` — unused currently, reserved for future priority-based transitions
- `GetOwner()` — returns the CharacterController that owns this state machine
- `OnEnter(payload)`, `OnExit()`, `Update(dt)`, `CanTransitionTo(name)` — overridable hooks

---

### 5.3 Idle

**Priority:** 0

The default resting state. Checks every frame for pending input flags set by MainScript:

- `WantsDodge` → transitions to Dodge, consumes flag
- `WantsSlide` → transitions to Slide, consumes flag
- `WantsBlock` → transitions to Block, consumes flag

On enter: plays the weapon idle animation if equipped.

`CanTransitionTo` → always returns true (Idle can go anywhere).

---

### 5.4 Attack

**Priority:** 5

Entered when performing any attack (basic or critical).

**Payload fields:**

| Field | Description |
|-------|-------------|
| `attackType` | `"BasicAttack"` or `"CriticalAttack"` |
| `comboIndex` | Current combo step number |
| `skillName` | For criticals, the skill name to send to server |
| `endlag` | Seconds of endlag after animation ends |
| `track` | The AnimationTrack playing this attack |

**Hit detection flow:**
1. Connects to the animation's `Hit` marker signal
2. When marker fires → calls `CreateHitbox()` which fires `CreateHitbox` remote to server
3. Fallback: if no `Hit` marker exists after 90% of animation length, fires anyway
4. At 60% of animation length → enables combo queuing (`CanQueueNextAttack = true`)
5. When animation stops → enters endlag
6. After endlag → if attack was queued, execute it; otherwise return to Idle

`CanTransitionTo` → only Hitstun, KnockedOut, or Idle.

---

### 5.5 Block

**Priority:** 6

Handles both the parry window and sustained blocking. Entered when F is pressed.

**Phases:**

| Phase | Duration | What happens |
|-------|----------|--------------|
| Parry window | 0.20s | `CanParry` tag active, can parry attacks |
| Block | Until F released | `IsBlocking` tag active, chip damage only |

**`OnParrySuccess()`** — called by CombatController when server confirms a parry:
- Plays a random parry animation (Parry1 or Parry2)
- Restores walk speed immediately
- Exits to Idle after 0.3s

**`OnBlockHit()`** — called when an attack is blocked (stub, can be extended).

**`CanTransitionTo`** → Hitstun, KnockedOut, or Idle only.

**Movement speed while blocking:**
- Parry window: speed × 0.3
- Blocking: speed × 0.5

---

### 5.6 Dodge

**Priority:** 8

Handles rolling/dashing in any of 8 directions (Forward, Backward, Left, Right, ForwardLeft, ForwardRight, BackwardLeft, BackwardRight). Also supports air dashes.

**On enter:**
1. Determines dodge direction from currently held WASD keys
2. Plays appropriate dash animation (e.g. `DashForward`, `AirDash`)
3. Sets WalkSpeed to 0, JumpHeight to 0, AutoRotate to false
4. Sets invulnerable flag + fires `DodgeStarted` to server
5. Starts `StartDodgeMotion()` — a RenderStepped loop applying velocity

**Dash physics:**
- Ground dash: 40 studs/s for 0.45s
- Air dash: 70 studs/s for 0.22s
- Direction blends camera influence (60%) with character-relative direction (40%)

**`OnDodgeSuccess()`** — perfect dodge (dodged an attack during i-frames):
- Kills dash motion immediately
- Plays `Spin` animation
- Gives +8 WalkSpeed bonus for 0.75s

**`CanTransitionTo`** → Hitstun, KnockedOut, or Idle only.

---

### 5.7 Hitstun

**Priority:** 10

Entered when the character is hit and staggered. Locks all input for a duration.

- Duration is passed via payload (`payload.duration`, default 0.3s)
- After duration expires → returns to Idle
- `CanTransitionTo` → Idle or Death only

---

### 5.8 KnockedOut

**Priority:** 15

A longer version of Hitstun for heavy hits. Also resets the combo counter.

- Default duration: 2s
- Zeroes velocity and locks WalkSpeed to 0 on enter
- Restores WalkSpeed on exit based on equipped state
- `CanTransitionTo` → Idle or Death only

---

### 5.9 Slide

**Priority:** 4

Handles both sliding (from sprint) and crouching (from walk).

**Entry conditions:**
- If WalkSpeed ≥ 18 (sprinting) → starts slide
- Otherwise → starts crouch
- Exits immediately if not grounded

**Slide physics (UpdateSlidePhysics, runs every Heartbeat):**

| Condition | Behavior |
|-----------|---------|
| Flat ground | Decelerates at 40 studs/s² |
| Downhill slope | Accelerates at 15 × slope_angle studs/s² |
| Uphill slope | Decelerates at 60 × slope_angle studs/s² |
| Speed < 8 | Slide ends; transitions to crouch or Idle |
| Left ground | Slide ends |

Slope detection uses a downward raycast. Slope angle is calculated as `1 - normal:Dot(Vector3.new(0,1,0))`. A hysteresis system prevents bouncing when transitioning between slope and flat ground.

**Steering (flat ground only):**
- Shift-lock: follows camera forward
- Free cam: follows held WASD direction
- Blended at `CAMERA_STEER_INFLUENCE = 0.8`

**Jump cancel during slide:**
- Keeps 70% of slide momentum as horizontal velocity
- Adds 15 studs forward boost and 25 studs vertical boost

**Ceiling detection:** If a raycast 2 studs above the head hits something, the character is forced to stay crouched even if Ctrl is released.

---

## 6. Server Systems

### 6.1 CombatServer

**Location:** `ServerScriptService/CombatServer.lua`

The server entry point. Does three things only:
1. Creates all manager instances
2. Passes them to the three handler modules (WeaponServer, DefenseServer, HitboxServer)
3. Cleans up all per-player data on `PlayerRemoving`

**Manager initialization order matters:**
```
healthManager → statusManager(health) → combatManager(health, status)
             → criticalManager(health, combat, weapon)
```

---

### 6.2 WeaponServer

**Location:** `ServerStorage/Modules/Handlers/WeaponServer.lua`

Handles all weapon-related remote events:

| Remote | Direction | Action |
|--------|-----------|--------|
| `AddWeapon` | Client → Server | Adds weapon model to character |
| `RemoveWeapon` | Client → Server | Removes weapon model |
| `WeaponEquipped` | Client → Server | Sets `EquippedWeapon` + `IsEquipped` attributes |
| `WeaponUnequipped` | Client → Server | Clears those attributes |
| `WeaponWeldToHand` | Client → Server | Welds weapon to hand bone |
| `WeaponWeldToBody` | Client → Server | Welds weapon to back/body |

All handlers validate that the player and character exist, and that the weapon name is valid in WeaponData before acting.

---

### 6.3 DefenseServer

**Location:** `ServerStorage/Modules/Handlers/DefenseServer.lua`

Handles dodge, block, and parry server-side tag management.

**DodgeStarted:**
- Server-side cooldown: 0.5s per player
- Clamps dodge duration to max 0.6s (prevents exploiting long i-frames)
- Adds `Invulnerable` and `Dodging` tags for the dodge duration
- Blocked if character has `Hitstunned` or `KnockedOut` tags

**BlockStarted:**
- Server-side cooldown: 0.1s per player
- Clamps parry window to max 0.3s
- Adds `CanParry` and `Parrying` tags for the parry window
- After parry window expires: if `CanParry` tag is gone (meaning a parry happened), does nothing; otherwise adds `IsBlocking` and `Blocking` tags for up to 10s

**BlockEnded:**
- Removes all block/parry tags immediately

---

### 6.4 HitboxServer

**Location:** `ServerStorage/Modules/Handlers/HitboxServer.lua`

The most security-critical handler. Uses a two-step authorization system.

**Step 1 — SkillRequest:**
1. Validates skill exists in SkillData
2. Calls `combatManager:RequestSkill()` — checks cooldowns, spam rate, character state, resources
3. If approved: stores `AuthorizedSkills[userId] = { skillName, timestamp, used = false }`

**Step 2 — CreateHitbox:**
1. Checks `AuthorizedSkills[userId]` exists and `used == false`
2. Checks token is not older than 2 seconds
3. Marks token as `used = true` (one-use only)
4. For critical attacks: delegates to `ServerCriticalManager`
5. For normal attacks: performs server-side spatial query, validates distances, applies damage

**Why two steps?** A player must be explicitly authorized before a hitbox is accepted. This means a hacked client cannot fire `CreateHitbox` freely — it must have a valid recent `SkillRequest` approval.

**Combo damage scaling:**
```
damageMultiplier = 1.0 + (comboIndex - 1) * 0.15
```
Combo hit 1 = 1.0×, hit 2 = 1.15×, hit 3 = 1.30×, hit 4 = 1.45×, hit 5 = 1.60×

Hit 5 also gets a 1.3× hitbox size increase.

---

## 7. Server Managers

### 7.1 ServerHealthManager

**Location:** `ServerStorage/Modules/Managers/ServerHealthManager.lua`

The core of the anti-cheat health system.

**Design:** Real HP is stored in a Lua table (`HealthData[character] = { Health, MaxHealth }`). The Humanoid's `Health` property is always locked to `MaxHealth` — clients see fake full health. The real HP is only sent to the owning player via `UpdateHealth` FireClient.

**`RegisterCharacter(character)`:**
- Reads `humanoid.MaxHealth` as starting HP
- Locks `humanoid.Health = humanoid.MaxHealth`
- Connects a `GetPropertyChangedSignal("Health")` to snap it back if anything changes it
- Fires initial HP update to owning player

**`TakeDamage(character, amount)`** → `{ died, finalDamage, newHealth }`

**`OnDeath(character)`:**
- Sets `humanoid.Health = 0` (triggers Roblox death mechanics)
- Calls `_onDeathCallback` if registered

**`SendHealthUpdate(character)`:**
- Fires `UpdateHealth` remote only to the character's owning player
- Other players cannot intercept real HP values

---

### 7.2 ServerCombatManager

**Location:** `ServerStorage/Modules/Managers/ServerCombatManager.lua`

The largest server manager. Handles skill validation, hit resolution, and damage calculation.

**`RequestSkill(player, skillName)`:**
- Checks spam rate (max 3 requests per second, kicks on violation)
- Checks character state (can't act while hitstunned/knockedout)
- For BasicAttack: validates combo sequence and cooldown (0.08s)
- For other skills: validates cooldown and resource cost

**`ApplyDamage(attacker, target, damageData)`** — full hit resolution:

```
1. Check target alive
2. Resolve attack type options (ResolveAttackType)
3. CrouchOnly / JumpOnly positional miss check
4. Invulnerability / Dodge check
5. Directional check (must face attacker to block/parry)
6. Parry check (CanParry tag)
7. Block check (IsBlocking tag)
8. Normal hit — apply damage, hitstun, posture, status effects, knockback
```

**Attack type system:**

| AttackType | canParry | canBlock | canDodge | blockBreak |
|------------|---------|---------|---------|-----------|
| Default | ✓ | ✓ | ✓ | ✗ |
| BlockBreak | ✗ | ✗ | ✓ | ✓ |
| Unparryable | ✗ | ✓ | ✓ | ✗ |
| ParryOnly | ✓ | ✗ | ✗ | ✗ |
| DodgeOnly | ✗ | ✗ | ✓ | ✗ |
| BlockOnly | ✗ | ✓ | ✗ | ✗ |
| HitboxOnly | ✗ | ✗ | ✗ | ✗ |
| CrouchOnly | Only hits crouching targets | | | |
| JumpOnly | Only hits airborne targets | | | |
| CounterWindow | Parryable only in first N seconds | | | |

**Posture system:**
- Posture fills when blocking or taking hits
- At max posture (100): `PostureBroken` tag applied for 2s, blocks are broken
- Posture decays by 5 every 5 seconds of not taking hits

**`ValidateHitbox(attacker, targetPosition, hitboxSize, offset)`:**
- Calculates where the hitbox should be (rootPart + lookVector × offset)
- Measures distance to target
- Max allowed distance = (hitboxSize / 2).Magnitude + 5 studs tolerance
- Rejects hits that exceed this (anti-teleport, anti-extended-reach exploit)

**Spam detection:**
- Tracks request count per player per second
- More than 3 requests/second → warns and kicks the player

---

### 7.3 ServerCriticalManager

**Location:** `ServerStorage/Modules/Managers/ServerCriticalManager.lua`

Handles critical attacks, which can be single-phase or multi-phase.

**Single-phase critical:**
- Scans hitbox for targets
- Applies damage with `DamageMultiplier` from WeaponData's Phases[1]

**Multi-phase critical (e.g. Katana):**

*Phase 1:*
- Scans hitbox, applies Phase 1 damage
- If any targets hit → marks them in `MarkedTargets[userId]` for `AltCritWindow` seconds (default 8s)
- Sets `AltCrit = true` attribute on attacker character

*Phase 2:*
- Validates `AltCrit` is true and marked targets still exist
- Applies rapid multi-hit damage (`RapidHits` times, `RapidHitInterval` seconds apart)
- Clears `AltCrit` and `MarkedTargets` after execution

---

### 7.4 ServerStatusManager

**Location:** `ServerStorage/Modules/Managers/ServerStatusManager.lua`

Manages all active status effects on all characters.

**Effect storage per character:**
```lua
_activeEffects[character][effectName] = {
    Stacks  : number,
    Count   : number,
    Timer   : number,   -- countdown for OnTime effects
}
```

**Trigger types:**
- `OnAction` — fires when the afflicted character attacks/moves (called via `NotifyAction`)
- `OnHit` — fires when the afflicted character takes a hit (called via `NotifyHit`)
- `OnTime` — fires on a recurring interval (processed by Heartbeat)

**Effect lifecycle:**
1. `Apply(character, effectName, { Stacks, Count })` — adds stacks/count, fires `OnApplied` if new
2. Each trigger decrements `Count` by 1
3. When `Count <= 0` → `OnExpired` fires, effect removed
4. `_replicate(character)` — sends snapshot to owning client after every change

**Passive decay:** Effects with `PassiveDecay` lose count over time even without being triggered.

---

## 8. Client Managers

### 8.1 HitboxManager

**Location:** `ReplicatedStorage/Modules/Managers/HitboxManager.lua`

Client-side spatial queries. Currently used for **visual feedback only** — actual hit detection is server-side.

**`CreateSingle(attacker, cframe, size)`** — one-shot box overlap query.

**`CreateContinuous(attacker, config)`** — repeated queries on Heartbeat for a duration. Used for lingering hitboxes (channeled attacks, etc.).

**`_scan()`** — uses `GetPartBoundsInBox` with a blacklist filter excluding the attacker. Tracks hit targets in a `hitMap` to prevent duplicate hits.

**`Destroy()`** — disconnects all active connections and clears the Active table.

---

### 8.2 AnimationManager

**Location:** `ReplicatedStorage/Modules/Managers/AnimationManager.lua`

Wraps Roblox's `AnimationController` / `Humanoid:LoadAnimation`. Maintains a registry of loaded tracks by key name.

Key features:
- `Play(key, fadeTime, looped)` — plays animation by key, returns track array
- `Stop(key, fadeTime)` — stops a specific animation
- `StopAll(fadeTime, includeLooped)` — stops all animations
- `IsKeyPlaying(key)` — checks if animation is currently playing
- `GetAllTracks()` — returns all loaded tracks (used for keyframe connections)

Animation keys follow the convention: `WeaponName_ActionName` (e.g. `Katana_Attack1`, `Katana_Sprint`, `Katana_WeaponIdle`).

---

### 8.3 TagManager

**Location:** `ReplicatedStorage/Modules/Managers/TagManager.lua`

A lightweight tag system using CollectionService or attributes. Tags represent temporary states like `Invulnerable`, `Dodging`, `CanParry`, `IsBlocking`, `Hitstunned`, `KnockedOut`, `PostureBroken`.

**`AddTag(character, tagName, duration)`** — adds tag, auto-removes after duration (if provided).
**`RemoveTag(character, tagName)`** — removes tag immediately.
**`HasTag(character, tagName)`** — returns bool.
**`Initialize(character)`** — sets up the tag table for a character.
**`Cleanup(character)`** — removes all tags and cleans up.

---

## 9. Data Configuration

### 9.1 WeaponData

**Location:** `ReplicatedStorage/Modules/Data/WeaponData.lua`

Defines all weapons. Each weapon entry contains:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | string | Weapon identifier |
| `WeaponType` | string | `"Light"` or `"Heavy"` |
| `Damage` | number | Base damage per hit |
| `Range` | number | Hitbox forward offset |
| `HitStunDuration` | number | Default hitstun on hit |
| `PostureDamage` | number | Posture damage per hit |
| `HitboxProperties` | table | `Swing: { Width, Height, Range }` |
| `Critical` | table | Critical attack definition |

**Critical definition:**
```lua
Critical = {
    AltCritWindow = 8,   -- seconds Phase 2 is available after Phase 1
    Phases = {
        [1] = {
            DamageMultiplier = 1.5,
            HitstunDuration = 0.5,
            HitboxSize = Vector3.new(8, 6, 8),
            HitboxOffset = 4,
        },
        [2] = {
            DamageMultiplier = 2.0,
            RapidHits = 5,
            RapidHitInterval = 0.065,
            ...
        }
    }
}
```

**API:**
- `WeaponData:GetWeapon(name)` → weapon table or nil
- `WeaponData:GetCritical(weaponName)` → critical table or nil

---

### 9.2 SkillData

**Location:** `ReplicatedStorage/Modules/Data/SkillData.lua`

Defines all skills/attacks. Each skill entry contains:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | string | Skill identifier |
| `Damage` | number | Base damage |
| `HitboxSize` | Vector3 | 3D hitbox dimensions |
| `HitboxOffset` | number | Forward offset from rootPart |
| `HitstunDuration` | number | Hitstun on hit |
| `AttackType` | string | See attack type table above |
| `PostureDamage` | number | Posture damage |
| `ChipDamage` | number | Damage through block |
| `BlockBreakDamage` | number | Bonus damage on block break |
| `IsCritical` | bool | Whether this is a critical skill |
| `CriticalPhase` | number | Which phase (1 or 2) |
| `StatusEffects` | table | `{ EffectName = { Stacks, Count } }` |
| `Cooldown` | number | Server-side cooldown in seconds |
| `Cost` | number | Resource cost (Mana) |

`BasicAttack` is a special built-in skill that maps to whatever weapon the player has equipped. Its damage scales with combo index in HitboxServer.

**API:**
- `SkillData:GetSkill(name)` → skill table or nil

---

### 9.3 StatusEffectData

**Location:** `ReplicatedStorage/Modules/Data/StatusEffectData.lua`

Defines all status effects. Each effect entry contains:

| Field | Type | Description |
|-------|------|-------------|
| `Name` | string | Effect identifier |
| `Color` | Color3 | UI accent color |
| `TriggerType` | string | `"OnHit"`, `"OnAction"`, or `"OnTime"` |
| `Interval` | number | Seconds between OnTime ticks |
| `MaxStacks` | number | Maximum stack count |
| `MaxCount` | number | Maximum charge count |
| `PassiveDecay` | number | Count lost per decay interval |
| `PassiveDecayInterval` | number | Seconds between passive decay ticks |
| `OnApplied(char, stacks, count, managers)` | function | Fires when first applied |
| `OnTrigger(char, stacks, managers)` | function | Fires on each trigger |
| `OnExpired(char, managers)` | function | Fires when count reaches 0 |

**`managers`** passed to callbacks contains `{ Health = healthManager, Status = statusManager }`.

**API:**
- `StatusEffectData.Get(name)` → effect table or nil

---

### 9.4 ClassData & PerkData

**Location:** `ReplicatedStorage/Modules/Data/ClassData.lua` and `PerkData.lua`

Define character class base stats and perk modifiers respectively. These feed into `ProgressionService` for stat calculation. Currently the foundation for a future class/perk selection system.

---

## 10. Remotes (Networking)

**Location:** `ReplicatedStorage/Modules/Remotes/CombatRemotes.lua`

All RemoteEvents are created in `ReplicatedStorage/Remotes/` folder. Both client and server require this same module.

**Client → Server:**

| Remote | Arguments | Purpose |
|--------|-----------|---------|
| `SkillRequest` | skillName | Request authorization to use a skill |
| `CreateHitbox` | skillName, comboIndex | Execute authorized skill hitbox |
| `WeaponEquipped` | weaponName | Notify server of equip |
| `WeaponUnequipped` | — | Notify server of unequip |
| `AddWeapon` | weaponName | Create weapon model on server |
| `RemoveWeapon` | — | Remove weapon model |
| `WeaponWeldToHand` | — | Weld weapon to hand |
| `WeaponWeldToBody` | — | Weld weapon to body |
| `DodgeStarted` | dodgeDuration | Start dodge i-frames |
| `BlockStarted` | parryWindow | Start block/parry window |
| `BlockEnded` | — | End block |

**Server → Client:**

| Remote | Arguments | Purpose |
|--------|-----------|---------|
| `UpdateHealth` | charName, health, maxHealth | Send real HP to owning player |
| `ApplyHitstun` | target, duration | Tell client to enter hitstun state |
| `ApplyKnockedOut` | target, duration | Tell client to enter knockedout state |
| `DodgeSuccess` | target | Perfect dodge triggered |
| `ParrySuccess` | target | Parry successful |
| `GotParried` | target | Your attack was parried |
| `BlockImpact` | target | Your block absorbed a hit |
| `BlockBroken` | target | Your block was broken |
| `HitConfirm` | attacker, target, type, damage | Broadcast hit result to all clients |
| `UpdateStatusEffects` | snapshot | Send effect snapshot to owning player |

---

## 11. UI Systems

### HealthListener

**Location:** `StarterPlayer/StaterPlayerScripts/HealthListner.lua`

Listens to `UpdateHealth` remote and updates:
- **Main HP bar** (`Slider`) — tweens immediately with 0.2s Quad easing
- **Trail bar** (`SecondSlider`) — waits 0.5s then tweens to catch up (0.6s Sine easing)
- **Percent label** — updates to `math.floor(percent * 100) .. "%"`

Also handles **dynamic posture billboards** on characters — shows a bar above any character whose posture is above 0. Hides automatically 5 seconds after posture returns to 0.

### StatusEffectListener

**Location:** `StarterPlayer/StaterPlayerScripts/StatusEffectListener.lua`

Listens to `UpdateStatusEffects` and renders a HUD row of effect icons. Each icon shows:
- Effect name abbreviation (first 4 characters)
- Stack count (top-right)
- Charge/count (bottom-left)
- Colored accent bar at the bottom

Icons are created on demand and fade out (0.2s tween) when effects expire.

---

## 12. Combat Flow (End to End)

Here is the complete sequence for a basic attack landing on an opponent:

```
1. Player presses Left Click
   └─ MainScript: checks IsEquipped, calls CombatController:PerformBasicAttack()

2. CombatController:PerformBasicAttack()
   ├─ Checks state machine is in Idle
   ├─ Advances combo count
   ├─ Plays attack animation
   └─ Sets state to Attack { attackType="BasicAttack", comboIndex=N, track=... }
      Also fires: SkillRequest("BasicAttack", comboIndex) to server

3. Server receives SkillRequest
   └─ HitboxServer → combatManager:RequestSkill()
      ├─ Spam check
      ├─ State check (Hitstunned? KnockedOut?)
      ├─ Combo sequence validation
      ├─ Cooldown check (0.08s)
      └─ If valid: AuthorizedSkills[userId] = { skillName, timestamp, used=false }

4. AttackState: animation reaches "Hit" keyframe marker
   └─ Fires CreateHitbox("BasicAttack", comboIndex) to server

5. Server receives CreateHitbox
   └─ HitboxServer:
      ├─ Validates auth token exists and is unused + not expired
      ├─ Marks token used
      ├─ Does GetPartBoundsInRadius scan around attacker
      ├─ For each candidate: ValidateHitbox distance check
      └─ For each valid target: combatManager:ApplyDamage()

6. ServerCombatManager:ApplyDamage()
   ├─ ResolveAttackType → determine canParry, canBlock, canDodge
   ├─ Check Invulnerable/Dodging tags → if dodging: DodgeSuccess to client
   ├─ Check CanParry tag → if parrying: GotParried to attacker, ParrySuccess to defender
   ├─ Check IsBlocking tag → if blocking: chip damage only, BlockImpact to defender
   └─ Normal hit:
      ├─ Calculate damage (base × weapon multiplier × status multipliers)
      ├─ HealthManager:TakeDamage() → sends real HP to target client via UpdateHealth
      ├─ Add Hitstunned tag on target
      ├─ Fire ApplyHitstun to target's client
      ├─ Apply status effects via StatusManager
      └─ Fire HitConfirm to all clients

7. Target client receives ApplyHitstun
   └─ CombatController:ApplyHitstun(duration)
      └─ StateMachine:SetState("Hitstun", { duration = duration })

8. Target's HealthListener receives UpdateHealth
   └─ Tweens HP bar to new value
```

---

## 13. Anti-Cheat Design

The following measures are in place:

**1. Hidden HP:**
Humanoid.Health is always locked at max. Real HP lives in `ServerHealthManager.HealthData` — a Lua table the client cannot read. Only the owning player receives their real HP via a direct FireClient.

**2. Skill authorization tokens:**
Every hitbox request must be preceded by a `SkillRequest` that the server approves. The token is single-use and expires after 2 seconds. A hacked client cannot call `CreateHitbox` without a valid recent token.

**3. Server-side hitbox validation:**
Even with a valid token, the server re-runs the hitbox scan itself. It also validates that each hit target is within a reasonable distance of the attacker's hitbox position (+ 5 stud tolerance). Hits beyond that are silently rejected.

**4. Spam detection:**
`CheckSpamRate()` tracks requests per second per player. More than 3 requests/second results in a kick.

**5. Combo sequence validation:**
The server tracks the last combo index per player. Out-of-sequence combo numbers (e.g. jumping from combo 1 to combo 4) are rejected.

**6. Server-side cooldowns:**
Every skill has a server-enforced cooldown independent of client-side debounces.

**7. Duration clamping:**
Client-reported dodge duration is clamped to 0.6s max. Parry window is clamped to 0.3s max. Clients cannot self-grant longer i-frames.

**8. State tag authority:**
All `Invulnerable`, `Dodging`, `CanParry`, `IsBlocking` etc. tags are set by the server, not the client. A client claiming to be invulnerable has no effect on server-side damage calculations.

---

## 14. Adding New Content

### Adding a new weapon

1. Add entry to `WeaponData.lua` with all required fields
2. Add its skill entries (at minimum `WeaponNameBasicAttack` pattern in SkillData if it differs from generic BasicAttack)
3. Create animations and register them in AnimationManager with keys following `WeaponName_ActionName`
4. Add the weapon model to `ServerStorage/WeaponModels/` (or wherever your models live)
5. The `DAMAGE_MULTIPLIERS` table in CombatController may need a new entry if it's a non-Katana weapon

### Adding a new skill

1. Add entry to `SkillData.lua` with all fields
2. Set `AttackType` appropriately (see attack type table)
3. Add an animation with key `WeaponName_SkillName`
4. Add `Hit` keyframe marker to the animation in Roblox Studio
5. In CombatController, add a method to trigger it (similar to `PerformCriticalAttack`)
6. Bind it to an input key in MainScript

### Adding a new status effect

1. Add entry to `StatusEffectData.lua` with `TriggerType`, callbacks, and limits
2. Reference it in a skill's `StatusEffects` field: `{ EffectName = { Stacks = N, Count = N } }`
3. The StatusManager handles everything else automatically

### Adding a new state

1. Create `NewState.lua` in `ReplicatedStorage/Modules/StateMachine/States/`
2. Inherit from `State.lua`: `local NewState = setmetatable({}, State)`
3. Implement `OnEnter(payload)`, `Update(dt)`, `OnExit()`, `CanTransitionTo(name)`
4. Register it in `CharacterController.new()`: `self.StateMachine:RegisterState(NewState.new())`
5. Add transition logic in `IdleState:Update()` or whichever state should enter it
6. Add `CanTransitionTo` entries in states that should be interruptible by it
