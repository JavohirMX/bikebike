#!/usr/bin/env python3
"""Export racetrack.usdz BasisCurves centerline to JSON in TrackRoot local space."""

from __future__ import annotations

import json
import math
import re
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Iterable


def parse_float_triple(value: str) -> tuple[float, float, float]:
    parts = [float(part.strip()) for part in value.split(",")]
    if len(parts) != 3:
        raise ValueError(f"Expected 3 floats, got {value!r}")
    return parts[0], parts[1], parts[2]


def rotate_xyz(point: tuple[float, float, float], degrees: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = point
    rx, ry, rz = [math.radians(angle) for angle in degrees]

    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)

    # RotateX
    y, z = y * cx - z * sx, y * sx + z * cx
    # RotateY
    x, z = x * cy + z * sy, -x * sy + z * cy
    # RotateZ
    x, y = x * cz - y * sz, x * sz + y * cz
    return x, y, z


def apply_xform(
    point: tuple[float, float, float],
    translate: tuple[float, float, float],
    rotate_deg: tuple[float, float, float],
    scale: tuple[float, float, float],
) -> tuple[float, float, float]:
    x, y, z = point
    sx, sy, sz = scale
    x, y, z = x * sx, y * sy, z * sz
    x, y, z = rotate_xyz((x, y, z), rotate_deg)
    tx, ty, tz = translate
    return x + tx, y + ty, z + tz


def lay_flat_for_ar(point: tuple[float, float, float]) -> tuple[float, float, float]:
    """Rotate -90 degrees about X so Blender/USD XY-ground assets lie on ARKit's XZ floor."""
    x, y, z = point
    return x, z, -y


def load_usda_text(usdz_path: Path) -> str:
    usdcat = Path("/usr/bin/usdcat")
    if usdcat.exists():
        result = subprocess.run(
            [str(usdcat), str(usdz_path)],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout

    with zipfile.ZipFile(usdz_path) as archive:
        usd_names = [name for name in archive.namelist() if name.endswith((".usdc", ".usda"))]
        if not usd_names:
            raise RuntimeError(f"No USD payload found in {usdz_path}")
        payload = archive.read(usd_names[0])
        if usd_names[0].endswith(".usda"):
            return payload.decode("utf-8")
        raise RuntimeError(
            "Binary USDC requires usdcat for extraction. Install Xcode command line tools."
        )


def extract_xform(block: str) -> tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]:
    translate_match = re.search(r"xformOp:translate = \(([^)]+)\)", block)
    rotate_match = re.search(r"xformOp:rotateXYZ = \(([^)]+)\)", block)
    scale_match = re.search(r"xformOp:scale = \(([^)]+)\)", block)

    translate = parse_float_triple(translate_match.group(1)) if translate_match else (0.0, 0.0, 0.0)
    rotate = parse_float_triple(rotate_match.group(1)) if rotate_match else (0.0, 0.0, 0.0)
    scale = parse_float_triple(scale_match.group(1)) if scale_match else (1.0, 1.0, 1.0)
    return translate, rotate, scale


def extract_points_array(block: str) -> list[tuple[float, float, float]]:
    points_match = re.search(
        r"(?:point3f|float3)\[\] points = \[(.*?)\]",
        block,
        re.DOTALL,
    )
    if not points_match:
        return []

    return [
        (float(match.group(1)), float(match.group(2)), float(match.group(3)))
        for match in re.finditer(
            r"\(([-\d.eE+]+),\s*([-\d.eE+]+),\s*([-\d.eE+]+)\)",
            points_match.group(1),
        )
    ]


def extract_curve_points(usda_text: str) -> list[tuple[float, float, float]]:
    match = re.search(r'def Xform "centerLine"\s*\{', usda_text)
    if not match:
        raise RuntimeError('Could not find Xform "centerLine" in USD')

    block_start = match.start()
    next_sibling = re.search(r'\n    def Xform "', usda_text[block_start + 1 :])
    block_end = block_start + 1 + next_sibling.start() if next_sibling else len(usda_text)
    block = usda_text[block_start:block_end]

    translate, rotate, scale = extract_xform(block)
    points_match = re.search(r"(?:point3f|float3)\[\] points = \[(.*?)\]", block, re.DOTALL)
    if not points_match:
        raise RuntimeError("Could not find BasisCurves points in centerLine")

    raw_points = [
        (float(match.group(1)), float(match.group(2)), float(match.group(3)))
        for match in re.finditer(
            r"\(([-\d.eE+]+),\s*([-\d.eE+]+),\s*([-\d.eE+]+)\)",
            points_match.group(1),
        )
    ]
    if len(raw_points) < 8:
        raise RuntimeError(f"centerLine has too few points ({len(raw_points)})")

    return [lay_flat_for_ar(apply_xform(point, translate, rotate, scale)) for point in raw_points]


def is_track_mesh_name(name: str) -> bool:
    lowered = name.lower()
    if lowered in {
        "road",
        "centerline",
        "center_line",
        "roadblock",
        "road_block",
        "startfinish",
        "start_finish",
        "finishline",
        "finish_line",
    }:
        return True
    return lowered.startswith("road_")


def is_road_surface_mesh_name(name: str) -> bool:
    lowered = name.lower()
    return lowered == "road" or (lowered.startswith("road_") and "barrier" not in lowered)


def extract_mesh_bounds_points(
    usda_text: str,
    *,
    surface_only: bool = False,
) -> list[tuple[float, float, float]]:
    mesh_blocks = re.finditer(r'def Mesh "([^"]+)"\s*(?:\([^)]*\))?\s*\{', usda_text)
    all_points: list[tuple[float, float, float]] = []

    for mesh_match in mesh_blocks:
        mesh_name = mesh_match.group(1)
        start = mesh_match.start()
        depth = 0
        end = start
        for index in range(start, len(usda_text)):
            char = usda_text[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break

        block = usda_text[start:end]
        extent_match = re.search(
            r"float3\[\] extent = \[\(([^)]+)\), \(([^)]+)\)\]",
            block,
        )
        if not extent_match:
            continue

        min_corner = parse_float_triple(extent_match.group(1))
        max_corner = parse_float_triple(extent_match.group(2))

        parent_xform_start = usda_text.rfind('def Xform "', 0, start)
        parent_block_end = usda_text.find('\n    def Xform "', parent_xform_start + 1)
        parent_block = usda_text[parent_xform_start:parent_block_end if parent_block_end != -1 else start]
        parent_name_match = re.search(r'def Xform "([^"]+)"', parent_block)
        parent_name = parent_name_match.group(1) if parent_name_match else mesh_name
        matches_surface = is_road_surface_mesh_name(parent_name) or is_road_surface_mesh_name(mesh_name)
        matches_track = is_track_mesh_name(parent_name) or is_track_mesh_name(mesh_name)
        if surface_only:
            if not matches_surface:
                continue
        elif not matches_track:
            continue
        translate, rotate, scale = extract_xform(parent_block)

        corners = [
            (min_corner[0], min_corner[1], min_corner[2]),
            (max_corner[0], max_corner[1], max_corner[2]),
            (min_corner[0], min_corner[1], max_corner[2]),
            (min_corner[0], max_corner[1], min_corner[2]),
            (min_corner[0], max_corner[1], max_corner[2]),
            (max_corner[0], min_corner[1], min_corner[2]),
            (max_corner[0], min_corner[1], max_corner[2]),
            (max_corner[0], max_corner[1], min_corner[2]),
            (max_corner[0], max_corner[1], max_corner[2]),
        ]
        for corner in corners:
            transformed = apply_xform(corner, translate, rotate, scale)
            all_points.append(lay_flat_for_ar(transformed))

    return all_points


def normalize_track_root(points: Iterable[tuple[float, float, float]], mesh_points: list[tuple[float, float, float]]) -> list[list[float]]:
    if not mesh_points:
        raise RuntimeError("Could not derive scene bounds from meshes")

    xs = [point[0] for point in mesh_points]
    ys = [point[1] for point in mesh_points]
    zs = [point[2] for point in mesh_points]

    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    min_z, max_z = min(zs), max(zs)

    center_x = (min_x + max_x) / 2
    center_z = (min_z + max_z) / 2
    floor_y = min_y

    normalized: list[list[float]] = []
    for x, y, z in points:
        normalized.append([x - center_x, y - floor_y, z - center_z])
    return normalized


def close_loop(points: list[list[float]], threshold: float = 0.05) -> tuple[list[list[float]], bool]:
    if len(points) < 2:
        return points, False

    first = points[0]
    last = points[-1]
    gap = math.dist(first, last)
    if gap <= threshold:
        return points, True

    points = points + [first.copy()]
    return points, True


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <racetrack.usdz> <output.json>", file=sys.stderr)
        return 1

    usdz_path = Path(sys.argv[1]).resolve()
    output_path = Path(sys.argv[2]).resolve()

    if not usdz_path.exists():
        print(f"Input not found: {usdz_path}", file=sys.stderr)
        return 1

    usda_text = load_usda_text(usdz_path)
    curve_points = extract_curve_points(usda_text)
    mesh_points = extract_mesh_bounds_points(usda_text, surface_only=True)
    if not mesh_points:
        mesh_points = extract_mesh_bounds_points(usda_text)
    normalized = normalize_track_root(curve_points, mesh_points)
    closed_points, is_closed = close_loop(normalized)

    payload = {
        "pointCount": len(closed_points),
        "closed": is_closed,
        "source": usdz_path.name,
        "points": closed_points,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(closed_points)} centerline points to {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
