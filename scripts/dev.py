#!/usr/bin/env python3
"""Canonical developer command surface for Primal Harmony."""

from __future__ import annotations

import argparse
import json
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

    report = run_checks(checks, stop_on_fail=args.stop_on_fail)
    if args.json:
        print_quality_json(report)
    else:
        print_quality_human(report)
    return 0 if report.overall_status == "pass" else 1


def cmd_harness_list(_: argparse.Namespace) -> int:
    print("Available harness workflows:")
    print("- scene-audit")
    return 0


def cmd_harness_scene_audit(args: argparse.Namespace) -> int:
    command = [sys.executable, "tools/audit_tscn.py", args.project_root]
    if args.json_output:
        command.append("--json")
    completed = subprocess.run(command, cwd=REPO_ROOT, check=False)  # noqa: S603
    return completed.returncode


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

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
