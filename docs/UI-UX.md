# UI/UX — Visual & Interaction Design

**Project:** AR Racecar  
**How (Visual)**

---

## Design Direction

**Arcade-playful** — bold colors, rounded HUD panels, and high contrast over the live camera feed. The AR world is the hero; UI elements float above it without obscuring the track.

| Principle | Application |
|-----------|-------------|
| Clarity over camera | HUD uses semi-opaque dark panels so text stays readable on any background |
| Playful competition | Bright player colors, chunky controls, satisfying haptic feedback |
| Quick setup | Minimal taps from launch to racing; sensible defaults for track and laps |
| Physical awareness | Placement UI encourages scanning the table; ghost track shows exact footprint |

---

## Color System

| Token | Usage | Suggested value |
|-------|-------|-----------------|
| `accent` | Primary buttons, active states | App accent color from asset catalog |
| `hudBackground` | Panel fill | `#000000` at 55% opacity |
| `hudText` | Labels, timers | `#FFFFFF` |
| `player1` | Player 1 car / tag | `#FF3B30` (red) |
| `player2` | Player 2 car / tag | `#007AFF` (blue) |
| `player3` | Player 3 car / tag | `#34C759` (green) |
| `player4` | Player 4 car / tag | `#FF9500` (orange) |
| `warning` | Tracking lost, errors | `#FFCC00` |
| `success` | Race complete, ready | `#34C759` |

Player colors are never the sole differentiator — each car also shows a name label and optional ring indicator.

---

## Typography

| Element | Font | Size | Weight |
|---------|------|------|--------|
| Screen title | SF Pro Rounded | 28 pt | Bold |
| Section header | SF Pro | 20 pt | Semibold |
| Body / labels | SF Pro | 17 pt | Regular |
| HUD timer / lap | SF Pro Rounded | 24 pt | Bold (monospaced digits) |
| Leaderboard row | SF Pro | 15 pt | Medium |
| Button | SF Pro | 17 pt | Semibold |

Use Dynamic Type where practical; race HUD sizes are fixed for consistent touch targets during play.

---

## Spacing & Touch Targets

| Element | Minimum size |
|---------|--------------|
| Primary button | 48 pt height, full-width or 160 pt min width |
| Joystick base | 120 × 120 pt |
| Gas / brake buttons | 64 × 64 pt each |
| List row (session / track) | 56 pt height |
| Safe area | Respect top notch and home indicator; HUD inset 16 pt from edges |

---

## Screen Inventory

| Screen | Purpose | Key elements |
|--------|---------|--------------|
| **Home** | Entry point | Practice, Host Race, Join Nearby buttons |
| **Track Select** | Host picks course | Track thumbnails, lap stepper, day/night toggle |
| **Browse Sessions** | Guest finds games | List of nearby `SessionInfo` rows, refresh |
| **Guest Lobby** | Wait for host | Player list, connection status, leave button |
| **AR Placement** | Anchor track | Camera view, ghost track, reticle, scale slider, Confirm |
| **Pre-Race Lobby** | Multiplayer ready room | Connected players, ready indicators, host Start button |
| **Race HUD** | In-race controls | Joystick, gas/brake, lap counter, timer, mini leaderboard |
| **Session Results** | End of race | Final standings, times, Play Again / Home |

---

## Wireframes

### Home Screen

```
┌─────────────────────────────┐
│                             │
│         AR RACECAR          │
│      ┌───────────────┐      │
│      │   Practice    │      │
│      └───────────────┘      │
│      ┌───────────────┐      │
│      │  Host Race    │      │
│      └───────────────┘      │
│      ┌───────────────┐      │
│      │ Join Nearby   │      │
│      └───────────────┘      │
│                             │
└─────────────────────────────┘
```

### AR Placement (Host / Solo)

```
┌─────────────────────────────┐
│  ← Back          [Scanning] │  ← status pill
│                             │
│     (live AR camera)        │
│         ┌─────┐             │
│         │ghost│  track      │
│         │track│  preview    │
│         └─────┘             │
│            ⊕ reticle        │
│                             │
│  Scale ────●────────        │
│  ┌─────────────────────┐    │
│  │      Confirm        │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

### Race HUD

```
┌─────────────────────────────┐
│ Lap 2/3        ⏱ 1:24.5   │  ← top bar
│ ┌──────────────────────┐    │
│ │ 1. Alex    2:01.2    │    │  ← mini leaderboard
│ │ 2. You     2:03.8    │    │
│ └──────────────────────┘    │
│                             │
│     (AR race view)            │
│                             │
│  ┌──┐              ┌──┐   │
│  │ ○│ joystick     │▲ │gas│
│  │  │              └──┘   │
│  └──┘              ┌──┐   │
│                    │▼ │brk│
│                    └──┘   │
└─────────────────────────────┘
```

### Session Results

```
┌─────────────────────────────┐
│        Race Complete        │
│  ┌──────────────────────┐   │
│  │ 🥇 Alex    3:12.4    │   │
│  │ 🥈 You     3:15.1    │   │
│  │ 🥉 Sam     3:18.0    │   │
│  └──────────────────────┘   │
│  ┌──────────┐ ┌──────────┐  │
│  │Play Again│ │   Home   │  │
│  └──────────┘ └──────────┘  │
└─────────────────────────────┘
```

---

## Interaction Patterns

### AR Placement

1. User points phone at a flat surface; app shows "Scanning…" until plane detected.
2. Ghost track preview snaps to detected plane under screen center reticle.
3. Pinch or slider adjusts scale (Should-have: dynamic AR scaling).
4. **Confirm** locks anchor; haptic tap on success.
5. Solo → race starts (or countdown). Multiplayer host → pre-race lobby.

### Virtual Joystick

- Left thumb drag within base circle maps to normalized `(-1, 1)` x/y.
- Dead zone: 10% radius to prevent drift.
- Gas/brake on right: hold for continuous input; releasing returns to coast.

### Lobby

- Sessions list shows: host name, track name, lap count, player count (e.g. `2/4`).
- Pull-to-refresh or auto-refresh every 3 s while browsing.
- Host **Start Race** enabled when ≥ 1 guest connected (or host can start solo-with-guests).

### Haptics (Should-have)

| Event | Feedback |
|-------|----------|
| Wall collision | Light impact |
| Lap complete | Medium impact |
| Race start | Heavy impact |
| Race finish | Success notification pattern |

---

## Day / Night Arenas (Should-have)

Toggle on Track Select screen:

| Theme | Visual |
|-------|--------|
| **Day** | Bright ambient; light skybox or neutral HDRI |
| **Night** | Dim ambient; emissive track edge lights; darker environment |

Theme ID sent in `RaceConfig` so all peers render consistently.

---

## Player Indicators (Should-have)

- Floating name tag above each car (billboard toward camera).
- Colored underglow or ring at car base matching `player1`–`player4` tokens.
- Local player's tag includes "(You)" suffix.

---

## Car Customization (Should-have)

Pre-race or in lobby:

- Color picker (4–6 preset swatches).
- Optional size slider (0.8×–1.2×) — applied to car model scale.

---

## Accessibility

| Need | Solution |
|------|----------|
| VoiceOver | All buttons labeled; session rows announce host, track, players |
| Color blindness | Player ID number on tag, not color alone |
| Motion sensitivity | No forced camera shake; AR can be disorienting — show tracking warnings clearly |
| Reduced motion | Disable decorative animations on results screen |

---

## Error & Empty States

| State | UI |
|-------|-----|
| No nearby sessions | Illustration + "No races nearby" + Refresh button |
| Camera denied | Icon + explanation + "Open Settings" deep link |
| AR tracking lost | Full-screen amber banner: "Move device slowly to recover tracking" |
| Connection lost | Modal: "Disconnected from host" + Return Home |

---

## Related Documents

- [AppFlow.md](AppFlow.md) — Navigation between screens
- [PRD.md](PRD.md) — Feature priorities
- [TRD.md](TRD.md) — Technical implementation
