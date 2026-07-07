# PRD — Product Requirements Document

**Project:** AR Racecar  
**What & Why**

---

## Problem & Vision

Racing games on a phone screen lack the physical, shared experience of playing together in the same room. AR Racecar turns any flat surface into a multiplayer racetrack: one player places the track in the real world, everyone sees the same course through their camera, and each person drives their own car with on-screen controls.

**Vision:** A local party-game AR experience — quick to set up, fun to watch, and technically demonstrative of AR placement, physics, and peer-to-peer sync.

---

## Goals

1. **Place a racetrack in AR** — Detect a horizontal surface and anchor a preset track in the physical environment.
2. **Control cars on the track** — Virtual joystick + accelerate/brake; cars stay on the track surface and respect wall boundaries.
3. **Play with nearby people** — Local multiplayer over Wi-Fi/Bluetooth via MultipeerConnectivity; all players see the same track and drive their own car.
4. **See a live leaderboard** — Session-only standings showing position, lap count, and lap times during and after a race.

---

## Non-Goals (v1)

- Cloud accounts, sign-in, or global persistent leaderboards
- Internet-based matchmaking or dedicated game servers
- In-app purchases, ads, or App Store polish beyond class demo quality
- Cross-platform (Android) support

---

## User Personas

| Persona | Description | Primary flow |
|---------|-------------|--------------|
| **Host** | Sets up the race for the group | Host Race → pick track & laps → place track in AR → wait for players → start race |
| **Guest** | Joins an existing nearby session | Join Nearby → tap session → wait in lobby → race |
| **Solo Player** | Practices without others | Practice → place track → race alone |

---

## Feature Priorities (MoSCoW)

### Must Have — App can't work without it

| Feature | Description |
|---------|-------------|
| Race track | Preset 3D track model loaded into the AR scene |
| Race boundaries / walls with physics | Invisible or visible wall colliders keep cars on course |
| Local track placement | User anchors track to a detected horizontal plane in AR |
| Car attached to race track | Cars snap to track surface; movement constrained to the course |
| Car controlling | Virtual joystick + accelerate/brake inputs drive the car |

### Should Have — Important but not blocking

| Feature | Description |
|---------|-------------|
| Dynamic AR scaling | Pinch/slider to resize track and cars in AR before confirming placement |
| Lobby screen | Browse nearby sessions; see connected players before race |
| Multiplayer | 2–4 players in a shared local session |
| Session leaderboard | Live rankings by lap, time, and finish order |
| Start, finish, and timer | Defined start line, lap counting, finish detection, elapsed time |
| Custom lap count | Host selects number of laps before the race |
| Multiple track presets | Host picks from 2+ track layouts |
| Player indicator | Color-coded car and name tag to distinguish players |
| Haptic feedback | Vibration on wall collisions and race events |
| Day / night arena options | Lighting/environment preset toggle on track select |
| Car customization | Basic color (and optionally size) per player |

### Could Have — Nice to have one day

| Feature | Description |
|---------|-------------|
| Audio spatialization (caster voice) | Position-based announcer audio for race commentary |
| 3D engine audio | Spatial engine sounds tied to car position |
| Victory screen | Dedicated end-of-race celebration UI |
| Starting lights | Countdown light sequence before green |
| Boost / turbo mode | Temporary speed boost mechanic |
| Cars can drop bombs | Combat / power-up mechanic |

---

## User Stories

### Must

- As a **solo player**, I can place a track on my table and drive a car around it so I can practice before playing with friends.
- As a **host**, I can place the track in AR and confirm its position so all guests see the course in the same spot.
- As any **player**, I can steer with a joystick and accelerate/brake so driving feels responsive.
- As any **player**, my car stays on the track and bounces off walls so the race feels fair.

### Should

- As a **guest**, I can browse nearby sessions and join one without typing an address.
- As a **host**, I can pick a track layout and lap count before placing the course.
- As any **player**, I can see who is winning on a live leaderboard during the race.
- As any **player**, I feel a vibration when I hit a wall.

### Could

- As a **player**, I hear a spatial announcer react to overtakes and finishes.
- As a **player**, I trigger a boost or drop a bomb for extra chaos.

---

## Success Metrics (Class Demo)

| Metric | Target |
|--------|--------|
| Multiplayer stability | 2–4 player race completes without crash |
| Track alignment | Guests see host-placed track within acceptable visual offset (< ~5 cm perceived) |
| Lap timing | Lap count and finish order recorded correctly for all players |
| Session length | No crash or freeze during a 5-minute play session |
| Device coverage | Runs on iPhone/iPad with and without LiDAR |

---

## Constraints

| Constraint | Detail |
|------------|--------|
| Timeline | ~2 weeks |
| Team size | 3–5 developers |
| Platform | iOS (iPhone + iPad), ARKit-capable devices |
| Networking | Local MultipeerConnectivity only — no cloud budget |
| Hardware | LiDAR optional; must not require LiDAR |
| Starting codebase | SwiftUI + RealityKit AR template ([`ContentView.swift`](../racecar/ContentView.swift)) |

---

## Open Questions (Resolved in TRD)

- **AR sync strategy** — TRD compares host-relative transform sync, ARWorldMap handoff, and image/QR anchors; recommends transform sync for v1.
- **Max players** — Recommend 4 for reliable MPC; document scaling limits up to 6–8.

---

## Related Documents

- [TRD.md](TRD.md) — Technical architecture
- [UI-UX.md](UI-UX.md) — Visual design
- [AppFlow.md](AppFlow.md) — Navigation flows
- [Backend-Schema.md](Backend-Schema.md) — Data and message schemas
- [Impl-Plan.md](Impl-Plan.md) — Build order and milestones
