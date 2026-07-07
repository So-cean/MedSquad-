# Map Size Audit

## Source maps

- `D:\projects\BME1325Spring2026\ED-MAS\demo\map1_v2.png`
  - width: `1672`
  - height: `941`
- `D:\projects\BME1325Spring2026\ED-MAS\demo\map2_v4.png`
  - width: `1672`
  - height: `941`
- `D:\projects\BME1325Spring2026\ED-MAS\demo\map3_v2.png`
  - width: `1672`
  - height: `941`

## Audit result

- All three maps are already `1672 × 941`.
- They are effectively aligned to the same canvas size.
- They are close to 16:9 and use a shared coordinate frame for the current Godot client.
- No resize or padding was required for the first normalized copy.

## Marker impact

- Because the normalized copies preserve the original pixel dimensions, existing Marker2D coordinates do not need to change in this phase.
- If a future asset revision changes canvas size or trimming, marker positions must be re-audited.

## Normalized output

- `res://assets/maps/normalized/map1_norm.png`
- `res://assets/maps/normalized/map2_norm.png`
- `res://assets/maps/normalized/map3_norm.png`

## Mask status

- Walkable mask files were created as placeholder full-white masks:
  - `res://assets/maps/masks/map1_walkable_mask.png`
  - `res://assets/maps/masks/map2_walkable_mask.png`
  - `res://assets/maps/masks/map3_walkable_mask.png`
- These are placeholders only and do not represent accurate wall/obstacle segmentation.
- Manual mask correction is still required later.

