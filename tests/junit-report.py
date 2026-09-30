#!/usr/bin/env python3
"""Convert ai-files bash-suite logs into a JUnit XML report.

Every tests/*.sh suite prints machine-parseable lines — `PASS: <desc>`,
`FAIL: <desc>`, `SKIP <desc>` — and a final `PASS=<n> FAIL=<m>` tally. This
script turns one log per suite into a <testsuite> and emits a combined
<testsuites> document for CI (uploaded as a workflow artifact; most JUnit
viewers/reporters accept it as-is). Per-testcase timing is not measured by
the suites, so time="0" is emitted.

Usage:
    python3 tests/junit-report.py [--out reports/junit.xml] [--summary FILE] log1.log [log2.log ...]

Suite names come from the log file basenames. When --summary is given (point
it at $GITHUB_STEP_SUMMARY in CI), a markdown table is appended there.
"""

import argparse
import os
import re
import sys
from xml.sax.saxutils import escape, quoteattr

PASS_RE = re.compile(r"^PASS: (.*)$")
FAIL_RE = re.compile(r"^FAIL: (.*)$")
SKIP_RE = re.compile(r"^SKIP\s+(.*)$")
TALLY_RE = re.compile(r"^PASS=(\d+) FAIL=(\d+)")


def parse_log(path):
    cases = []  # (status, description)
    tally = None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            m = PASS_RE.match(line)
            if m:
                cases.append(("pass", m.group(1)))
                continue
            m = FAIL_RE.match(line)
            if m:
                cases.append(("fail", m.group(1)))
                continue
            m = SKIP_RE.match(line)
            if m:
                cases.append(("skip", m.group(1)))
                continue
            m = TALLY_RE.match(line)
            if m:
                tally = (int(m.group(1)), int(m.group(2)))
    if tally and tally != (
            sum(1 for s, _ in cases if s == "pass"),
            sum(1 for s, _ in cases if s == "fail")):
        print(f"WARNING: {os.path.basename(path)}: parsed PASS/FAIL counts "
              f"disagree with its own tally line {tally}", file=sys.stderr)
    return cases


def suite_xml(name, cases):
    failures = sum(1 for s, _ in cases if s == "fail")
    skipped = sum(1 for s, _ in cases if s == "skip")
    out = [f'  <testsuite name={quoteattr(name)} tests="{len(cases)}" '
           f'failures="{failures}" errors="0" skipped="{skipped}" time="0">']
    for status, desc in cases:
        attrs = f'classname={quoteattr(name)} name={quoteattr(desc)} time="0"'
        if status == "pass":
            out.append(f"    <testcase {attrs}/>")
        elif status == "fail":
            out.append(f'    <testcase {attrs}><failure message='
                       f'{quoteattr("assertion failed")} type="assert">'
                       f"{escape(desc)}</failure></testcase>")
        else:
            out.append(f'    <testcase {attrs}><skipped/></testcase>')
    out.append("  </testsuite>")
    return "\n".join(out), len(cases), failures, skipped


def main(argv):
    p = argparse.ArgumentParser(prog="junit-report")
    p.add_argument("--out", default="reports/junit.xml", help="output XML path")
    p.add_argument("--summary", default=None,
                   help="markdown file to append a summary table to "
                        "(point at $GITHUB_STEP_SUMMARY in CI)")
    p.add_argument("logs", nargs="+", help="suite log files")
    args = p.parse_args(argv)

    suites = []
    total = fails = skips = 0
    for log in args.logs:
        name = os.path.splitext(os.path.basename(log))[0]
        xml, n, f, s = suite_xml(name, parse_log(log))
        suites.append(xml)
        total += n
        fails += f
        skips += s

    doc = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           f'<testsuites name="ai-files tests" tests="{total}" '
           f'failures="{fails}" errors="0" skipped="{skips}" time="0">\n'
           + "\n".join(suites) + "\n</testsuites>\n")

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(doc)

    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as f:
            f.write("\n## Test report\n\n")
            f.write("| Suite | Tests | Failures | Skipped |\n|---|---|---|---|\n")
            for log in args.logs:
                name = os.path.splitext(os.path.basename(log))[0]
                cases = parse_log(log)
                f.write(f"| {name} | {len(cases)} | "
                        f"{sum(1 for s, _ in cases if s == 'fail')} | "
                        f"{sum(1 for s, _ in cases if s == 'skip')} |\n")
            f.write(f"| **Total** | **{total}** | **{fails}** | **{skips}** |\n")

    print(f"{args.out}: {total} tests, {fails} failures, {skips} skipped "
          f"across {len(args.logs)} suite(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
