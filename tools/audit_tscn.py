#!/usr/bin/env python3
"""
audit_tscn.py — Godot Integration Doctor
Scans all .tscn files in a project for cross-scene integration issues.

Usage:
    python3 audit_tscn.py /path/to/godot/project [--fix] [--json]

Checks performed:
    1. Warp Area2Ds missing explicit collision_layer
    2. Encounter Area2Ds missing explicit collision_layer
    3. Collision layer/mask mismatches between player detectors and targets
    4. Warp metadata referencing nonexistent scene files
    5. Warp destination_warp_id with no matching node in target scene
    6. Missing reciprocal warps (one-way connections)
    7. Area2Ds missing required metadata keys
    8. Scenes with WarpPoints container but no warp children
"""

import os
import re
import sys

# Force UTF-8 output on Windows to prevent UnicodeEncodeError with arrows (→)
if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

import json
from pathlib import Path
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Optional


class Severity(str, Enum):
    ERROR = "ERROR"      # Will cause runtime failure
    WARNING = "WARNING"  # Likely causes subtle bugs
    INFO = "INFO"        # Style / best practice


@dataclass
class Issue:
    severity: Severity
    scene_path: str
    node_path: str
    check: str
    message: str
    fix_hint: str = ""


@dataclass
class TscnNode:
    """Represents a parsed node from a .tscn file."""
    name: str
    type: str
    parent: str  # parent path string from the .tscn
    properties: dict = field(default_factory=dict)
    metadata: dict = field(default_factory=dict)

    @property
    def full_path(self) -> str:
        if self.parent == ".":
            return self.name
        elif self.parent == "":
            return self.name  # root node
        else:
            return f"{self.parent}/{self.name}"


def parse_tscn(filepath: str) -> list[TscnNode]:
    """Parse a .tscn file into a list of TscnNode objects."""
    nodes = []
    current_node = None

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()

            # Skip comments and empty lines
            if line.startswith(";") or not line:
                continue

            # Node definition
            node_match = re.match(
                r'\[node\s+name="([^"]+)"\s+type="([^"]+)"(?:\s+parent="([^"]*)")?',
                line,
            )
            if node_match:
                name = node_match.group(1)
                node_type = node_match.group(2)
                parent = node_match.group(3) if node_match.group(3) is not None else ""
                current_node = TscnNode(
                    name=name, type=node_type, parent=parent
                )
                nodes.append(current_node)

                # Check for inline instance (PackedScene) — skip those
                if "instance=" in line:
                    current_node.properties["_is_instance"] = True
                continue

            # Instance node (no type, has parent and instance)
            inst_match = re.match(
                r'\[node\s+name="([^"]+)"\s+parent="([^"]*)".*instance=',
                line,
            )
            if inst_match:
                name = inst_match.group(1)
                parent = inst_match.group(2)
                current_node = TscnNode(
                    name=name, type="(instance)", parent=parent
                )
                current_node.properties["_is_instance"] = True
                nodes.append(current_node)
                continue

            # Properties of the current node
            if current_node and "=" in line and not line.startswith("["):
                # Metadata
                meta_match = re.match(r'metadata/(\w+)\s*=\s*"?([^"]*)"?', line)
                if meta_match:
                    current_node.metadata[meta_match.group(1)] = meta_match.group(2)
                    continue

                # Regular property
                prop_match = re.match(r'(\w+)\s*=\s*(.*)', line)
                if prop_match:
                    key = prop_match.group(1)
                    val = prop_match.group(2).strip()
                    current_node.properties[key] = val

    return nodes


def find_player_detectors(project_root: str) -> dict[str, int]:
    """Find the Player scene and extract detector collision_masks."""
    detectors = {}
    player_tscn = None

    for root, dirs, files in os.walk(project_root):
        for f in files:
            if f == "Player.tscn":
                player_tscn = os.path.join(root, f)
                break
        if player_tscn:
            break

    if not player_tscn:
        return detectors

    nodes = parse_tscn(player_tscn)
    for node in nodes:
        if node.type == "Area2D":
            mask_val = int(node.properties.get("collision_mask", "1"))
            detectors[node.name] = mask_val

    return detectors


def find_all_tscn(project_root: str) -> list[str]:
    """Find all .tscn files in the project, excluding addons."""
    tscn_files = []
    for root, dirs, files in os.walk(project_root):
        # Skip addons and .godot cache
        dirs[:] = [d for d in dirs if d not in ("addons", ".godot", ".import")]
        for f in files:
            if f.endswith(".tscn"):
                tscn_files.append(os.path.join(root, f))
    return sorted(tscn_files)


def get_res_path(filepath: str, project_root: str) -> str:
    """Convert an absolute file path to a res:// path."""
    rel = os.path.relpath(filepath, project_root)
    return "res://" + rel.replace("\\", "/")


def resolve_res_path(res_path: str, project_root: str) -> str:
    """Convert a res:// path to an absolute file path."""
    if res_path.startswith("res://"):
        rel = res_path[6:]
    else:
        rel = res_path
    return os.path.normpath(os.path.join(project_root, rel))


def is_warp_node(node: TscnNode) -> bool:
    """Check if a node is a warp point based on parent path or metadata."""
    return (
        "WarpPoints" in node.parent
        or "destination_scene" in node.metadata
        or node.name.startswith("warp_to_")
    )


def is_encounter_node(node: TscnNode) -> bool:
    """Check if a node is an encounter zone based on parent path or metadata."""
    return (
        "EncounterZone" in node.parent
        or "EncounterZone" in node.name
        or "zone_id" in node.metadata
    ) and node.type == "Area2D"


def audit_scene(
    filepath: str,
    project_root: str,
    player_detectors: dict[str, int],
    all_scenes: dict[str, list[TscnNode]],
) -> list[Issue]:
    """Audit a single .tscn file for integration issues."""
    issues = []
    rel_path = get_res_path(filepath, project_root)
    nodes = all_scenes.get(filepath, [])

    # Build a set of node paths in this scene for lookup
    node_paths = set()
    for n in nodes:
        node_paths.add(n.full_path)

    # Check: Does WarpPoints exist? Does it have children?
    warp_container_exists = any(
        n.name == "WarpPoints" for n in nodes
    )
    warp_children = [n for n in nodes if "WarpPoints" in n.parent and n.type == "Area2D"]

    if warp_container_exists and not warp_children:
        issues.append(Issue(
            severity=Severity.INFO,
            scene_path=rel_path,
            node_path="WarpPoints",
            check="empty_warp_container",
            message="WarpPoints container exists but has no Area2D children",
            fix_hint="Add warp Area2D nodes or remove the empty container",
        ))

    # Check each warp node
    warp_mask = player_detectors.get("WarpDetector", 2)  # default to 2

    for node in warp_children:
        node_path = node.full_path

        # Check: collision_layer explicitly set?
        if "collision_layer" not in node.properties:
            issues.append(Issue(
                severity=Severity.ERROR,
                scene_path=rel_path,
                node_path=node_path,
                check="warp_missing_collision_layer",
                message=(
                    f"Warp Area2D has no explicit collision_layer "
                    f"(defaults to 1, but WarpDetector expects mask {warp_mask})"
                ),
                fix_hint=f"Add collision_layer = {warp_mask} to this node",
            ))
        else:
            layer_val = int(node.properties["collision_layer"])
            if layer_val & warp_mask == 0:
                issues.append(Issue(
                    severity=Severity.ERROR,
                    scene_path=rel_path,
                    node_path=node_path,
                    check="warp_collision_layer_mismatch",
                    message=(
                        f"Warp collision_layer={layer_val} does not overlap "
                        f"WarpDetector collision_mask={warp_mask}"
                    ),
                    fix_hint=f"Set collision_layer = {warp_mask}",
                ))

        # Check: required metadata
        if "destination_scene" not in node.metadata:
            issues.append(Issue(
                severity=Severity.ERROR,
                scene_path=rel_path,
                node_path=node_path,
                check="warp_missing_destination_scene",
                message="Warp Area2D has no metadata/destination_scene",
                fix_hint="Add metadata/destination_scene = \"res://path/to/scene.tscn\"",
            ))
        else:
            dest_scene = node.metadata["destination_scene"]
            dest_abs = resolve_res_path(dest_scene, project_root)

            # Check: destination scene exists?
            if not os.path.isfile(dest_abs):
                issues.append(Issue(
                    severity=Severity.ERROR,
                    scene_path=rel_path,
                    node_path=node_path,
                    check="warp_destination_scene_missing",
                    message=f"destination_scene points to nonexistent file: {dest_scene}",
                    fix_hint="Create the scene or fix the path",
                ))
            else:
                # Check: destination_warp_id exists in target?
                dest_warp_id = node.metadata.get("destination_warp_id", "")
                if dest_warp_id:
                    target_nodes = all_scenes.get(dest_abs, [])
                    target_warp_names = {
                        n.name for n in target_nodes if "WarpPoints" in n.parent
                    }
                    if dest_warp_id not in target_warp_names:
                        # Check if WarpPoints container exists at all
                        has_wp = any(n.name == "WarpPoints" for n in target_nodes)
                        if not has_wp:
                            issues.append(Issue(
                                severity=Severity.ERROR,
                                scene_path=rel_path,
                                node_path=node_path,
                                check="warp_target_no_warppoints",
                                message=(
                                    f"Target scene {dest_scene} has no WarpPoints container; "
                                    f"player will spawn at fallback position"
                                ),
                                fix_hint="Add a WarpPoints node to the target scene",
                            ))
                        else:
                            issues.append(Issue(
                                severity=Severity.WARNING,
                                scene_path=rel_path,
                                node_path=node_path,
                                check="warp_target_id_missing",
                                message=(
                                    f"destination_warp_id=\"{dest_warp_id}\" not found "
                                    f"in {dest_scene}'s WarpPoints (has: {target_warp_names or 'none'})"
                                ),
                                fix_hint=f"Add a node named \"{dest_warp_id}\" under WarpPoints in {dest_scene}",
                            ))

        if "destination_warp_id" not in node.metadata:
            issues.append(Issue(
                severity=Severity.WARNING,
                scene_path=rel_path,
                node_path=node_path,
                check="warp_missing_destination_warp_id",
                message="Warp Area2D has no metadata/destination_warp_id; player will use fallback position",
                fix_hint="Add metadata/destination_warp_id = \"warp_name_in_target\"",
            ))

    # Check encounter zones
    encounter_mask = player_detectors.get("EncounterDetector", 4)  # default to 4
    encounter_nodes = [n for n in nodes if is_encounter_node(n)]

    for node in encounter_nodes:
        node_path = node.full_path

        if "collision_layer" not in node.properties:
            issues.append(Issue(
                severity=Severity.ERROR,
                scene_path=rel_path,
                node_path=node_path,
                check="encounter_missing_collision_layer",
                message=(
                    f"Encounter Area2D has no explicit collision_layer "
                    f"(defaults to 1, but EncounterDetector expects mask {encounter_mask})"
                ),
                fix_hint=f"Add collision_layer = {encounter_mask} to this node",
            ))
        else:
            layer_val = int(node.properties["collision_layer"])
            if layer_val & encounter_mask == 0:
                issues.append(Issue(
                    severity=Severity.ERROR,
                    scene_path=rel_path,
                    node_path=node_path,
                    check="encounter_collision_layer_mismatch",
                    message=(
                        f"Encounter collision_layer={layer_val} does not overlap "
                        f"EncounterDetector collision_mask={encounter_mask}"
                    ),
                    fix_hint=f"Set collision_layer = {encounter_mask}",
                ))

        if "zone_id" not in node.metadata:
            issues.append(Issue(
                severity=Severity.WARNING,
                scene_path=rel_path,
                node_path=node_path,
                check="encounter_missing_zone_id",
                message="Encounter Area2D has no metadata/zone_id",
                fix_hint="Add metadata/zone_id = \"zone_name\"",
            ))

    # Check: CollisionShape2D children exist for all Area2Ds
    area2d_nodes = [n for n in nodes if n.type == "Area2D"]
    for node in area2d_nodes:
        has_shape = any(
            n.type == "CollisionShape2D" and n.parent == node.full_path
            for n in nodes
        )
        if not has_shape:
            # Check one level deeper (parent could be partial path)
            has_shape = any(
                n.type == "CollisionShape2D"
                and node.full_path in n.parent
                for n in nodes
            )
        if not has_shape:
            issues.append(Issue(
                severity=Severity.WARNING,
                scene_path=rel_path,
                node_path=node.full_path,
                check="area2d_no_collision_shape",
                message="Area2D has no CollisionShape2D child — it won't detect anything",
                fix_hint="Add a CollisionShape2D child with an appropriate shape",
            ))

    return issues


def check_warp_reciprocity(
    project_root: str,
    all_scenes: dict[str, list[TscnNode]],
) -> list[Issue]:
    """Check that all warps have a matching return warp in the target scene."""
    issues = []

    for filepath, nodes in all_scenes.items():
        rel_path = get_res_path(filepath, project_root)
        warp_nodes = [n for n in nodes if "WarpPoints" in n.parent and n.type == "Area2D"]

        for warp in warp_nodes:
            dest_scene = warp.metadata.get("destination_scene", "")
            dest_warp_id = warp.metadata.get("destination_warp_id", "")
            if not dest_scene or not dest_warp_id:
                continue

            dest_abs = resolve_res_path(dest_scene, project_root)
            target_nodes = all_scenes.get(dest_abs, [])
            if not target_nodes:
                continue  # Missing scene already caught

            # Find the landing node
            landing_node = None
            for tn in target_nodes:
                if tn.name == dest_warp_id and "WarpPoints" in tn.parent:
                    landing_node = tn
                    break

            if not landing_node:
                continue  # Missing landing already caught

            # Does the landing node warp back to us?
            return_dest = landing_node.metadata.get("destination_scene", "")
            if not return_dest:
                # It's a landing-only node (no return warp configured)
                # This might be intentional (one-way warp) or an omission
                issues.append(Issue(
                    severity=Severity.INFO,
                    scene_path=get_res_path(dest_abs, project_root),
                    node_path=landing_node.full_path,
                    check="warp_no_return",
                    message=(
                        f"Node \"{dest_warp_id}\" is a warp landing from {rel_path} "
                        f"but has no destination_scene metadata (one-way warp)"
                    ),
                    fix_hint="Add destination_scene/destination_warp_id if this should be bidirectional",
                ))

    return issues


def run_audit(project_root: str, output_json: bool = False) -> list[Issue]:
    """Run the full audit."""
    project_root = os.path.abspath(project_root)

    print(f"Godot Integration Doctor — Auditing: {project_root}")
    print("=" * 70)

    # Step 1: Find player detectors
    detectors = find_player_detectors(project_root)
    if detectors:
        print(f"\nPlayer detectors found:")
        for name, mask in detectors.items():
            bits = []
            for i in range(32):
                if mask & (1 << i):
                    bits.append(f"bit {i} (value {1 << i})")
            print(f"  {name}: collision_mask = {mask} → listens to {', '.join(bits)}")
    else:
        print("\n⚠ No Player.tscn found or no Area2D detectors in Player scene")

    # Step 2: Parse all scenes
    tscn_files = find_all_tscn(project_root)
    print(f"\nScanning {len(tscn_files)} scene files...")

    all_scenes: dict[str, list[TscnNode]] = {}
    for fp in tscn_files:
        all_scenes[fp] = parse_tscn(fp)

    # Step 3: Audit each scene
    all_issues: list[Issue] = []
    for fp in tscn_files:
        scene_issues = audit_scene(fp, project_root, detectors, all_scenes)
        all_issues.extend(scene_issues)

    # Step 4: Check warp reciprocity
    recip_issues = check_warp_reciprocity(project_root, all_scenes)
    all_issues.extend(recip_issues)

    # Step 5: Report
    errors = [i for i in all_issues if i.severity == Severity.ERROR]
    warnings = [i for i in all_issues if i.severity == Severity.WARNING]
    infos = [i for i in all_issues if i.severity == Severity.INFO]

    print(f"\n{'=' * 70}")
    print(f"RESULTS: {len(errors)} errors, {len(warnings)} warnings, {len(infos)} info")
    print(f"{'=' * 70}\n")

    for issue in all_issues:
        icon = {"ERROR": "❌", "WARNING": "⚠️ ", "INFO": "ℹ️ "}[issue.severity.value]
        print(f"{icon} [{issue.severity.value}] {issue.scene_path}")
        print(f"   Node: {issue.node_path}")
        print(f"   Check: {issue.check}")
        print(f"   {issue.message}")
        if issue.fix_hint:
            print(f"   Fix: {issue.fix_hint}")
        print()

    if output_json:
        json_out = [asdict(i) for i in all_issues]
        print("\n--- JSON OUTPUT ---")
        print(json.dumps(json_out, indent=2))

    return all_issues


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 audit_tscn.py /path/to/godot/project [--json]")
        sys.exit(1)

    project_path = sys.argv[1]
    json_mode = "--json" in sys.argv

    if not os.path.isdir(project_path):
        print(f"Error: {project_path} is not a directory")
        sys.exit(1)

    if not os.path.isfile(os.path.join(project_path, "project.godot")):
        print(f"Warning: No project.godot found in {project_path}")

    issues = run_audit(project_path, output_json=json_mode)
    sys.exit(1 if any(i.severity == Severity.ERROR for i in issues) else 0)
