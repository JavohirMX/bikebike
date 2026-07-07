# Feasibility Report

**Project:** AR Racecar MVP  
**Date:** 2026-06-27  
**Build:** Feasibility spike (1-week plan)

---

## Purpose

Record pass/fail results for the six feasibility criteria defined in the MVP plan. Run this checklist on **two physical iOS devices** on the same local network.

---

## Test Environment

| Field | Value |
|-------|-------|
| Device A (host) | ___________________ |
| Device B (guest) | ___________________ |
| LiDAR on host | Yes / No |
| Network | Same Wi‑Fi / Personal Hotspot |
| iOS version | ___________________ |
| Build | Debug from Xcode |

---

## Success Criteria Results

| # | Test | Pass? | Notes |
|---|------|-------|-------|
| 1 | Solo drive — car completes 1 lap on placed procedural track | ☐ Pass ☐ Fail | |
| 2 | Track sync — guest track aligns with host within ~5 cm | ☐ Pass ☐ Fail | |
| 3 | Car sync — guest sees host car move smoothly (10+ Hz) | ☐ Pass ☐ Fail | |
| 4 | Full network flow — browse, join, lobby without manual IP | ☐ Pass ☐ Fail | |
| 5 | Race completion — both finish 1 lap; correct results order | ☐ Pass ☐ Fail | |
| 6 | Stability — 3-minute 2-device session without crash | ☐ Pass ☐ Fail | |

---

## How to Run the Test

### Solo (Criterion 1)

1. Launch app → **Practice**
2. Point at a flat table → **Confirm Placement**
3. Drive one lap with joystick + gas
4. Verify lap counter increments and race completes

### Multiplayer (Criteria 2–6)

1. **Device A:** Host Race → set laps to **1** → wait in lobby
2. **Device B:** Join Nearby → tap host session
3. **Device A:** Place Track → Confirm → **Start Race**
4. Both drive one lap
5. Verify aligned track, remote car movement, results screen, no crash over 3 minutes

### If browse finds no sessions

- Enable Wi‑Fi on both devices
- Try iPhone Personal Hotspot (host phone provides network)
- Confirm local network permission was granted on first launch

---

## Known MVP Limitations

- Procedural box track and car (no USDZ assets)
- Kinematic driving with boundary clamp (not full rigid-body physics)
- Lap detection via finish-line position crossing
- Host-relative transform sync only (no ARWorldMap)
- Max 2 players; no reconnection if host leaves mid-race
- **Resend Track (debug)** button on host lobby if alignment drifts

---

## Go / No-Go Decision

| Outcome | Action |
|---------|--------|
| ☐ All 6 pass | Proceed with full [Impl-Plan.md](Impl-Plan.md) |
| ☐ Track sync fails | Spike ARWorldMap or QR marker (1 day) |
| ☐ Network unreliable | Solo demo + defer multiplayer |
| ☐ Physics/AR fail | Revisit track scale and placement UX |

**Decision:** ☐ Go  ☐ No-Go  ☐ Go with caveats

**Signed off by:** ___________________  
**Date:** ___________________

---

## Implementation Summary

The MVP adds:

- `AppState` — navigation, race logic, `RaceSessionDelegate`
- `ARSceneController` + `ProceduralTrack` — AR placement and driving
- `NetworkSessionManager` — host listen / guest browse+connect over `racecar-ar` Bonjour service
- UI flow — Home, lobbies, browse, placement, race HUD, results
- Race messages — `joinRequest`, `joinAccept`, `trackPlaced`, `raceStart`, `carPose`, `lapCompleted`, `raceEnd`, `playerLeft`

Entry point: [`racecar/UI/RootView.swift`](../racecar/UI/RootView.swift) via [`SceneDelegate.swift`](../racecar/SceneDelegate.swift).
