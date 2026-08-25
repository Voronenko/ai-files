#!/usr/bin/env python3
"""
Normalize ag-kit agent frontmatter for Opencode.

Fixes: tools: "Read, Grep, ..." (string) → removed (Phase 1) or permission object (Phase 2)
       model: inherit → removed, skills/version → removed, ensure mode: subagent.
Idempotent: re-running on normalized file is no-op.

Usage:
  scripts/normalize-ag-kit-agents.py [--check] [--vendor-dir DIR] [--dist-dir DIR]
  --check exits 1 if any file still has string tools.
"""
from __future__ import annotations
import argparse
import glob
import os
import sys

try:
    import yaml
except ImportError:
    print("PyYAML required: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

BAD_KEYS = {"tools", "skills", "version"}
INHERIT_MODEL = "inherit"

def find_files(vendor_dir: str, dist_dir: str) -> list[str]:
    patterns = []
    for d in [vendor_dir, dist_dir]:
        if d and os.path.isdir(d):
            patterns.extend(glob.glob(os.path.join(d, "*.md")))
    # Also catch .opencode/agents/ag-kit when it is not symlink
    for extra in [".opencode/agents/ag-kit", "dist/.opencode/agents/ag-kit", "dist/.ai-files/agents/ag-kit"]:
        if os.path.isdir(extra):
            patterns.extend(glob.glob(os.path.join(extra, "*.md")))
    # dedupe by realpath
    seen: dict[str, str] = {}
    for p in patterns:
        try:
            rp = os.path.realpath(p)
        except Exception:
            rp = p
        seen[rp] = p
    return sorted(seen.values(), key=lambda x: os.path.basename(x))

def split_frontmatter(text: str):
    """Return (frontmatter_text or None, frontmatter_dict or None, body)."""
    if not text.startswith("---"):
        return None, None, text
    # Find second --- delimiter (line exactly ---)
    lines = text.splitlines()
    # first line is ---
    end = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end == -1:
        return None, None, text
    fm_text = "\n".join(lines[1:end])
    body = "\n".join(lines[end + 1 :])
    # Keep leading newline semantics: body as originally after delimiter
    # Re-add trailing newline handling in caller
    try:
        data = yaml.safe_load(fm_text) or {}
        if not isinstance(data, dict):
            data = {}
    except Exception as e:
        print(f"  ! yaml parse error: {e}", file=sys.stderr)
        return fm_text, None, body
    return fm_text, data, body

def normalize_file(path: str, check: bool, generate_permission: bool = False) -> tuple[bool, bool, dict]:
    """Normalize one file. Returns (changed, valid, stats)."""
    text = open(path, encoding="utf-8").read()
    fm_text, data, body = split_frontmatter(text)
    if data is None:
        # no frontmatter or parse error -> skip
        return False, True, {}

    orig_data = dict(data)
    stats: dict[str, int] = {}

    # tools handling
    tools_val = data.get("tools")
    if isinstance(tools_val, str):
        if check:
            return False, False, {"string_tools": 1}
        # Phase 1: delete string tools. Optionally generate permission.
        if generate_permission:
            # Build permission from allowlist; deny missing edit
            perms: dict[str, str] = {}
            # crude mapping
            mapping = {
                "read": "read",
                "grep": "grep",
                "glob": "glob",
                "bash": "bash",
                "edit": "edit",
                "write": "edit",
                "agent": "task",
            }
            present = {t.strip().lower() for t in tools_val.split(",") if t.strip()}
            # track edit specially
            if "edit" in present or "write" in present:
                perms["edit"] = "allow"
            else:
                perms["edit"] = "deny"
            for k in ["read", "grep", "glob", "bash", "task"]:
                # task maps from Agent
                src = "agent" if k == "task" else k
                if src in present:
                    perms[k] = "allow"
            # ViewCodeItem/FindByName intentionally dropped
            data["permission"] = perms
            stats["permission_added"] = 1
        del data["tools"]
        stats["tools_removed"] = 1
    elif "tools" in data and isinstance(tools_val, dict):
        # already object -> valid, leave as-is (deprecated but accepted)
        pass
    elif "tools" in data and tools_val is None:
        del data["tools"]
        stats["tools_removed"] = 1

    # model inherit
    if data.get("model") == INHERIT_MODEL:
        del data["model"]
        stats["model_removed"] = 1

    # skills / version
    for k in ["skills", "version"]:
        if k in data:
            # skills is string CSV in ag-kit, not valid opencode key
            # version also not valid
            del data[k]
            stats[f"{k}_removed"] = 1

    # ensure mode
    if "mode" not in data:
        data["mode"] = "subagent"
        stats["mode_added"] = 1

    # keep only known order: name, description, mode, model, permission, temperature, etc.
    # But preserve all other unknown keys except removed ones - just write back data.

    if data == orig_data:
        # no change needed, but still validate tools not string
        is_valid = not isinstance(data.get("tools"), str)
        return False, is_valid, stats

    # write back
    if check:
        # In check mode we already returned for string tools; otherwise change would be needed
        return False, False, stats

    # dump frontmatter
    # yaml.safe_dump with sort_keys=False to preserve insertion order (py 3.7+)
    fm_new = yaml.safe_dump(data, sort_keys=False, allow_unicode=True).strip()
    # reconstruct file: ---\n<fm>\n---\n<body>
    # body may start with newline; ensure single newline after closing ---
    body_out = body.lstrip("\n")
    # keep body exactly as was but ensure newline at end
    new_text = f"---\n{fm_new}\n---\n\n{body_out}"
    if not new_text.endswith("\n"):
        new_text += "\n"

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_text)

    return True, True, stats

def main() -> int:
    ap = argparse.ArgumentParser(description="Normalize ag-kit agents for Opencode")
    ap.add_argument("--check", action="store_true", help="Exit 1 if any file still has string tools")
    ap.add_argument("--vendor-dir", default="vendor/agents/ag-kit", help="Vendor ag-kit dir")
    ap.add_argument("--dist-dir", default="dist/.ai-files/agents/ag-kit", help="Dist ag-kit dir")
    ap.add_argument("--permission", action="store_true", help="Generate permission object from tools allowlist (Phase 2)")
    args = ap.parse_args()

    files = find_files(args.vendor_dir, args.dist_dir)
    if not files:
        print(f"No files found (vendor={args.vendor_dir} dist={args.dist_dir})", file=sys.stderr)
        return 0

    total_changed = 0
    total_invalid = 0
    agg: dict[str, int] = {}

    for path in files:
        changed, valid, stats = normalize_file(path, check=args.check, generate_permission=args.permission)
        if not valid:
            print(f"INVALID {path}: tools is string", file=sys.stderr)
            total_invalid += 1
        if changed:
            print(f"normalized {path} {stats}")
            total_changed += 1
        for k, v in stats.items():
            agg[k] = agg.get(k, 0) + v

    print(f"Scanned {len(files)} files: changed={total_changed} invalid={total_invalid} {agg}")

    if args.check and total_invalid > 0:
        return 1
    if args.check and total_changed > 0:
        # check mode without --permission will detect string tools via invalid; but changed>0 means pending fix
        return 1 if total_invalid else 0
    return 1 if total_invalid else 0

if __name__ == "__main__":
    sys.exit(main())
