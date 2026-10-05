# Wuming / 无名: Motion Art Brief

Status: specification only. No new raster artwork has been generated or approved.
Do not replace the current player before the user reviews the motion samples.

## Original Character

- Name: 无名 (Wuming).
- Young adult martial artist with short dark hair, visible eyes and a calm face.
- Asymmetric white and teal short mantle, dark trousers, silver left forearm guard.
- Broad, readable silhouette and clear fists and boots at gameplay scale.
- Original spatial powers expressed through teal, silver and gold angular cracks.
- Do not reuse any existing anime character's costume, face, gestures or signature effects.

## First Review Batch

Make the right-facing view first. Fix character proportions, palette, camera,
foot baseline and pivot across all frames. Preview animation loops before approval.
AI outputs are source artwork: inspect anatomy and alignment, then clean frames.
Do not assume generated sprite grids are production-ready without inspection.

| Clip | Frames | Playback | Pose Sequence |
| --- | --- | --- | --- |
| Idle | 6 | 8 fps, loop | Relaxed guard, breathing, mantle settles |
| Run | 8 | 12 fps, loop | Contact, compression, push-off, flight, alternate legs |
| Fold Step | 8 | 28 fps, once | Crouch, rear-leg push, extended leap, tuck, landing |
| Martial Combo | 12 | 20 fps, once | Guard, straight punch, recoil, pivot kick, recovery |

Final cells: 160 x 160 transparent PNG, nearest-neighbor filtering. Anchor at
(80, 132) for grounded frames; leap art may rise but the gameplay pivot stays fixed.
Keep limb and mantle extremes inside the cell, with margin for inspection.
Keep trails and spell effects separate from the character artwork.

## Expansion After Review

- Front and back idle/run views for the top-down game; mirror only side views.
- Anchor cast: extend the guarded arm, open the hand, place a spatial anchor.
- Fault cut: planted stance, diagonal arm cut, recoil and settle.
- Refold parry: short guard, contact pose, counterpunch and return.
- Ultimate: both arms set anchors, widen the stance, release linked fractures.
- Hit reaction: stagger and regain balance.
- Death: knees give way, mantle settles, body remains readable without effects.

## Generation Prompts

Shared invariants for every request:

```text
Use case: stylized-concept
Asset type: original 2D game character animation source artwork
Subject: Wuming, a young adult spatial martial artist, short dark hair, visible
eyes, asymmetric white and teal short mantle, dark trousers, silver left forearm
guard, dark boots. Original design, no existing franchise resemblance.
Style: clean detailed pixel art for a top-down action survival game, readable
anatomy, restrained shading, consistent pixel density and limited palette.
Camera: right-facing three-quarter view, identical camera and proportions in
every pose. Full body visible, uniform frame cells, fixed ground baseline.
Background: genuinely transparent alpha. No lettering, grid lines or watermark.
Constraints: same costume, face, limb lengths and colors in every frame; no
cropped hands or feet; no baked motion blur, trails, spell effects or UI.
```

Idle request: six sequential breathing poses in a 3-column by 2-row grid.
Run request: eight distinct chronological gait poses in a 4-column by 2-row grid.
Fold Step request: eight chronological poses from crouch through rear-leg push,
airborne extension, tucked legs and landing, in a 4-column by 2-row grid.
Martial Combo request: twelve chronological poses for straight punch followed by
a pivot kick and visible recovery, in a 4-column by 3-row grid.

Once the character reference is approved, use it as the visual reference for all
clips. Do not independently invent a new design for each motion sheet.
