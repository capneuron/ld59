# Signal — Guinea Pig Communication Game

Game jam (48h) entry for theme "Signal". A game about a guinea pig communicating through body movement patterns drawn on the ground.

## Core Concept

The player controls a guinea pig (Ginnie) on an open field. By moving and drawing closed shapes on the ground, the player expresses different **vibes** (emotional states) and **signals** (intentions). These combine to produce different effects on NPCs. The main goal is to court a target guinea pig by discovering the right vibe + signal combination through social interactions with other NPCs.

## Platform & Tech

- Engine: Godot 4.6 (existing project)
- Existing systems: physics-driven 8-segment tail, mouse-based movement, tail-swipe combat, PS1 retro rendering
- New systems: trail rendering, shape recognition, vibe state machine, signal trigger, NPC reaction system

---

## System 1: Trail System

- Player movement leaves a visible glowing trail on the ground
- Trail points recorded at fixed distance intervals (not time-based, to avoid clutter when stationary)
- Trail visually fades after 5-8 seconds
- When trail start and end points are within a distance threshold (~1.5m), the shape is considered closed and submitted to the shape recognizer
- Trail renders as a glowing line/decal on the ground surface

## System 2: Shape Recognizer

Based on the **$1 Unistroke Recognizer** algorithm:

1. Take closed trail as 2D point sequence (x/z coordinates, ignore y)
2. Resample to 64 evenly-spaced points
3. Normalize rotation
4. Scale to a fixed bounding box
5. Compare against 6 stored templates using sum of distances
6. Return best match + confidence score; below threshold = unrecognized

### Recognizable Shapes (6 total)

| Shape | Type | Meaning | Drawing Gesture |
|---|---|---|---|
| Figure-8 | Vibe | **Confident** — bold, showy | Weave in a figure-8 |
| Square | Vibe | **Sincere** — calm, steady | Walk in a square |
| S-curve | Vibe | **Gentle** — soft, caring | Smooth S-shaped path |
| Heart | Signal | **Court** — express love | Draw a heart shape |
| Triangle | Signal | **Warn** — threaten, declare hostility | Sharp angular turns |
| Zigzag | Signal | **Greet** — say hello, start conversation | Side-to-side movement |

## System 3: Vibe State Machine

- Four states: Sincere / Confident / Gentle / Neutral (default)
- Drawing a vibe shape switches the current state
- Vibe persists for 15-20 seconds, then reverts to Neutral
- Drawing a new vibe replaces the current one
- UI indicator in screen corner shows current vibe + remaining time

## System 4: Signal Trigger

- When a signal shape is recognized, the system reads current vibe state
- Combines into a (vibe, signal) event
- Detects NPCs within a radius around the drawn shape
- Sends the event to all NPCs in range
- If no NPC is in range, visual feedback indicates "no one heard"

## System 5: Vibe + Signal Combination Matrix

| | Greet (Zigzag) | Warn (Triangle) | Court (Heart) |
|---|---|---|---|
| **Sincere (Square)** | NPC responds friendly, willing to talk | NPC takes it seriously, backs off | Heartfelt confession, large affection boost |
| **Confident (Figure-8)** | NPC is impressed, strong first impression | NPC fears, may flee or submit | Bold courtship, some NPCs like it / some don't |
| **Gentle (S-curve)** | NPC lowers guard, reveals secrets | Soft warning, NPC doesn't take seriously | Subtle affection, shy NPCs respond well |
| **Neutral (none)** | NPC responds coldly | NPC slightly nervous | NPC confused, no effect |

## System 6: NPC Reaction System

- Each NPC has a reaction table mapping (vibe, signal) combinations to response types
- Response types: happy (jump), scared (back away), confused (spin in place), interested (approach)
- Specific combinations trigger dialogue bubbles / unlock events
- NPC reactions are expressed through body animations, not text-heavy UI

## System 7: Combat System (Existing + Extensions)

- Existing tail-swipe mechanic preserved (velocity threshold >= 80 units/sec for kill)
- Enemies include predators (cats, snakes) and rival guinea pigs
- Predators appear as task encounters
- Rival guinea pigs can be resolved through combat OR correct signal combinations
- Circle-around-enemy stun mechanic deferred to post-demo

---

## Demo Scope

- 1 open field map
- 6 recognizable shapes (3 vibes + 3 signals)
- NPC count and story flow TBD (to be designed by the developer)
- Combat encounters with predators and/or rival guinea pigs
- Core loop: move → draw shapes → interact with NPCs → learn new shapes → use correct combo for final goal

## Deferred Features

- Circle stun (drawing circle around enemy)
- Urine territory marking system
- Additional maps / areas
