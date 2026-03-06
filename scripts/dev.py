#!/usr/bin/env python3
"""Canonical developer command surface for Primal Harmony."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable

REPO_ROOT = Path(__file__).resolve().parents[1]


@dataclass
class CheckResult:
    name: str
    status: str
    duration_ms: int
    detail: str


@dataclass
class QualityReport:
    command: str
    overall_status: str
    passed: int
    failed: int
    results: list[CheckResult]


CheckFn = Callable[[], tuple[bool, str]]


def _decode_text(data: bytes, path: Path) -> str:
    for encoding in ("utf-8", "utf-8-sig", "cp1252"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("unknown", data, 0, len(data), f"cannot decode {path}")


def _decode_subprocess_output(data: bytes) -> str:
    for encoding in ("utf-8", "utf-8-sig", "cp1252"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def check_anchor_docs() -> tuple[bool, str]:
    required = [
        "AGENTS.md",
        "project.godot",
        "improvements/VISION.md",
        "improvements/ROADMAP.md",
        "improvements/MAJOR_SCHEMA.md",
        "improvements/MINOR_SCHEMA.md",
        "improvements/harness/README.md",
        "tools/audit_tscn.py",
    ]
    missing = [path for path in required if not (REPO_ROOT / path).exists()]
    if missing:
        return False, f"missing required files: {', '.join(missing)}"
    return True, f"required files present ({len(required)})"


def check_python_syntax() -> tuple[bool, str]:
    roots = [REPO_ROOT / "scripts", REPO_ROOT / "tools"]
    py_files: list[Path] = []
    for root in roots:
        if root.exists():
            py_files.extend(sorted(root.rglob("*.py")))
    if not py_files:
        return False, "no python files found under scripts/ or tools/"

    failures: list[str] = []
    for path in py_files:
        try:
            source = _decode_text(path.read_bytes(), path)
            compile(source, str(path), "exec")
        except Exception as exc:  # noqa: BLE001
            failures.append(f"{path.relative_to(REPO_ROOT)}: {exc}")

    if failures:
        preview = "; ".join(failures[:3])
        if len(failures) > 3:
            preview += f"; ... (+{len(failures) - 3} more)"
        return False, f"syntax check failed for {len(failures)} file(s): {preview}"

    return True, f"compiled {len(py_files)} python file(s)"


def check_data_json_parse() -> tuple[bool, str]:
    data_dir = REPO_ROOT / "data"
    if not data_dir.exists():
        return False, "data/ directory not found"

    json_files = sorted(data_dir.rglob("*.json"))
    if not json_files:
        return False, "no JSON files found under data/"

    failures: list[str] = []
    for path in json_files:
        try:
            payload = path.read_text(encoding="utf-8")
            json.loads(payload)
        except Exception as exc:  # noqa: BLE001
            failures.append(f"{path.relative_to(REPO_ROOT)}: {exc}")

    if failures:
        preview = "; ".join(failures[:3])
        if len(failures) > 3:
            preview += f"; ... (+{len(failures) - 3} more)"
        return False, f"JSON parse failed for {len(failures)} file(s): {preview}"

    return True, f"parsed {len(json_files)} data JSON file(s)"


def check_scene_audit() -> tuple[bool, str]:
    command = [sys.executable, "tools/audit_tscn.py", "."]
    completed = subprocess.run(  # noqa: S603
        command,
        cwd=REPO_ROOT,
        capture_output=True,
        text=False,
        check=False,
    )
    stdout = completed.stdout or b""
    stderr = completed.stderr or b""
    output = (_decode_subprocess_output(stdout) + _decode_subprocess_output(stderr)).strip()
    if completed.returncode == 0:
        return True, "scene audit passed"
    trimmed = output.splitlines()[-1] if output else "scene audit failed"
    return False, f"scene audit failed (exit {completed.returncode}): {trimmed}"


def _parse_schema_requirements(schema_path: Path) -> tuple[list[str], list[str]]:
    text = schema_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    required_sections: list[str] = []
    required_metadata_fields: list[str] = []
    section_mode = False
    metadata_mode = False

    section_pattern = re.compile(r"^\d+\.\s+`([^`]+)`\s*$")
    metadata_pattern = re.compile(r"^- `([^`]+)`")

    for line in lines:
        stripped = line.strip()
        if stripped == "## Required Sections":
            section_mode = True
            metadata_mode = False
            continue
        if stripped == "## Required Metadata Fields":
            section_mode = False
            metadata_mode = True
            continue
        if stripped.startswith("## ") and stripped not in {
            "## Required Sections",
            "## Required Metadata Fields",
        }:
            section_mode = False
            metadata_mode = False

        if section_mode:
            match = section_pattern.match(stripped)
            if match:
                required_sections.append(match.group(1))

        if metadata_mode:
            match = metadata_pattern.match(stripped)
            if match:
                required_metadata_fields.append(match.group(1))

    return required_sections, required_metadata_fields


def _extract_metadata_block(lines: list[str]) -> list[str]:
    in_metadata = False
    metadata_lines: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped == "## Metadata":
            in_metadata = True
            continue
        if in_metadata and stripped.startswith("## "):
            break
        if in_metadata:
            metadata_lines.append(stripped)
    return metadata_lines


def _lint_item_file(
    path: Path,
    required_sections: list[str],
    required_metadata_fields: list[str],
) -> list[str]:
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()
    headings = [line.strip() for line in lines if line.startswith("#")]
    metadata_lines = _extract_metadata_block(lines)
    issues: list[str] = []

    has_title = any(line.startswith("# ") and not line.startswith("## ") for line in lines)
    for section in required_sections:
        if section == "# <title>":
            if not has_title:
                issues.append(f"{path.relative_to(REPO_ROOT)}: missing required top-level title heading")
            continue
        if section not in headings:
            issues.append(f"{path.relative_to(REPO_ROOT)}: missing required section heading `{section}`")

    for field in required_metadata_fields:
        pattern = re.compile(rf"^- `?{re.escape(field)}`?\s*:")
        if not any(pattern.match(line) for line in metadata_lines):
            issues.append(f"{path.relative_to(REPO_ROOT)}: missing required metadata field `{field}`")

    return issues


def collect_item_lint_issues() -> tuple[list[str], int]:
    specs = [
        ("major", REPO_ROOT / "improvements/MAJOR_SCHEMA.md", REPO_ROOT / "improvements/majors"),
        ("minor", REPO_ROOT / "improvements/MINOR_SCHEMA.md", REPO_ROOT / "improvements/minors"),
    ]

    issues: list[str] = []
    total_files = 0

    for item_type, schema_path, items_dir in specs:
        if not schema_path.exists():
            issues.append(f"schema missing for {item_type}: {schema_path.relative_to(REPO_ROOT)}")
            continue
        if not items_dir.exists():
            issues.append(f"items directory missing for {item_type}: {items_dir.relative_to(REPO_ROOT)}")
            continue

        required_sections, required_metadata_fields = _parse_schema_requirements(schema_path)
        if not required_sections:
            issues.append(
                f"{schema_path.relative_to(REPO_ROOT)}: could not parse required sections for {item_type}"
            )
            continue
        if not required_metadata_fields:
            issues.append(
                f"{schema_path.relative_to(REPO_ROOT)}: could not parse required metadata fields for {item_type}"
            )
            continue

        item_files = sorted(
            path for path in items_dir.glob("*.md") if path.name.lower() != "readme.md"
        )
        total_files += len(item_files)
        for item_file in item_files:
            issues.extend(
                _lint_item_file(item_file, required_sections, required_metadata_fields)
            )

    return issues, total_files


def check_item_lint() -> tuple[bool, str]:
    issues, total_files = collect_item_lint_issues()
    if issues:
        preview = "; ".join(issues[:3])
        if len(issues) > 3:
            preview += f"; ... (+{len(issues) - 3} more)"
        return False, f"item lint failed for {total_files} file(s): {preview}"
    return True, f"item lint passed for {total_files} file(s)"


def run_checks(checks: list[tuple[str, CheckFn]], stop_on_fail: bool = False) -> QualityReport:
    results: list[CheckResult] = []
    for name, check_fn in checks:
        started = time.perf_counter()
        try:
            ok, detail = check_fn()
        except Exception as exc:  # noqa: BLE001
            ok = False
            detail = f"unexpected exception: {exc}"
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        results.append(
            CheckResult(
                name=name,
                status="pass" if ok else "fail",
                duration_ms=elapsed_ms,
                detail=detail,
            )
        )
        if stop_on_fail and not ok:
            break

    passed = sum(1 for result in results if result.status == "pass")
    failed = sum(1 for result in results if result.status == "fail")
    return QualityReport(
        command="quality-strict",
        overall_status="pass" if failed == 0 else "fail",
        passed=passed,
        failed=failed,
        results=results,
    )


def print_quality_human(report: QualityReport) -> None:
    for result in report.results:
        marker = "PASS" if result.status == "pass" else "FAIL"
        print(f"[{marker}] {result.name} ({result.duration_ms}ms) - {result.detail}")
    print(
        f"quality-strict: {report.overall_status.upper()} "
        f"({report.passed} passed, {report.failed} failed)"
    )


def print_quality_json(report: QualityReport) -> None:
    payload = {
        "command": report.command,
        "overall_status": report.overall_status,
        "passed": report.passed,
        "failed": report.failed,
        "results": [asdict(result) for result in report.results],
    }
    print(json.dumps(payload, indent=2))


def cmd_quality_strict(args: argparse.Namespace) -> int:
    checks: list[tuple[str, CheckFn]] = [
        ("anchor-docs", check_anchor_docs),
        ("python-syntax", check_python_syntax),
        ("data-json-parse", check_data_json_parse),
    ]
    if args.with_scene_audit:
        checks.append(("scene-audit", check_scene_audit))
    if args.with_item_lint:
        checks.append(("item-lint", check_item_lint))

    report = run_checks(checks, stop_on_fail=args.stop_on_fail)
    if args.json:
        print_quality_json(report)
    else:
        print_quality_human(report)
    return 0 if report.overall_status == "pass" else 1


def cmd_harness_list(_: argparse.Namespace) -> int:
    print("Available harness workflows:")
    print("- item-lint")
    print("- scene-audit")
    return 0


def cmd_harness_scene_audit(args: argparse.Namespace) -> int:
    command = [sys.executable, "tools/audit_tscn.py", args.project_root]
    if args.json_output:
        command.append("--json")
    completed = subprocess.run(command, cwd=REPO_ROOT, check=False)  # noqa: S603
    return completed.returncode


def cmd_harness_item_lint(args: argparse.Namespace) -> int:
    issues, total_files = collect_item_lint_issues()
    if args.json_output:
        payload = {
            "workflow": "item-lint",
            "overall_status": "pass" if not issues else "fail",
            "files_checked": total_files,
            "issues": issues,
        }
        print(json.dumps(payload, indent=2))
    else:
        if issues:
            print(f"item-lint: FAIL ({len(issues)} issue(s) across {total_files} file(s))")
            for issue in issues:
                print(f"- {issue}")
        else:
            print(f"item-lint: PASS ({total_files} file(s))")
    return 0 if not issues else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Canonical developer command surface for Primal Harmony."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    quality_parser = subparsers.add_parser(
        "quality-strict",
        help="Run strict baseline quality checks.",
    )
    quality_parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON summary.",
    )
    quality_parser.add_argument(
        "--stop-on-fail",
        action="store_true",
        help="Stop after first failed check.",
    )
    quality_parser.add_argument(
        "--with-scene-audit",
        action="store_true",
        help="Include tools/audit_tscn.py in strict checks.",
    )
    quality_parser.add_argument(
        "--with-item-lint",
        action="store_true",
        help="Include work-item schema lint checks in strict checks.",
    )
    quality_parser.set_defaults(func=cmd_quality_strict)

    harness_parser = subparsers.add_parser(
        "harness",
        help="Run optional harness/evaluation workflows.",
    )
    harness_subparsers = harness_parser.add_subparsers(
        dest="harness_command",
        required=True,
    )

    harness_list_parser = harness_subparsers.add_parser(
        "list",
        help="List available harness workflows.",
    )
    harness_list_parser.set_defaults(func=cmd_harness_list)

    scene_audit_parser = harness_subparsers.add_parser(
        "scene-audit",
        help="Run tools/audit_tscn.py as an optional harness workflow.",
    )
    scene_audit_parser.add_argument(
        "project_root",
        nargs="?",
        default=".",
        help="Project root passed to tools/audit_tscn.py (default: .).",
    )
    scene_audit_parser.add_argument(
        "--json",
        dest="json_output",
        action="store_true",
        help="Forward --json to tools/audit_tscn.py.",
    )
    scene_audit_parser.set_defaults(func=cmd_harness_scene_audit)

    item_lint_parser = harness_subparsers.add_parser(
        "item-lint",
        help="Validate major/minor item docs against local schema requirements.",
    )
    item_lint_parser.add_argument(
        "--json",
        dest="json_output",
        action="store_true",
        help="Print machine-readable item-lint results.",
    )
    item_lint_parser.set_defaults(func=cmd_harness_item_lint)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
