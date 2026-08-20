# 5. Vendor Callstack React Native agent skills via Gilt

Date: 2026-08-20

## Status

Accepted

## Context

We needed to make React Native expertise available to coding agents working in this repo. The upstream https://github.com/callstackincubator/agent-skills ships 11 skills across performance, navigation, TV, library creation, upgrades, CI/CD, device automation, QA, and migration workflows — drawn from Callstack's production React Native work. A local checkout is available at `/home/slavko/tmp/agent-skills`.

The existing vendoring mechanism is Gilt (`Giltfile.yaml` → `vendor/skills/<namespace>/<skill>`), already used for superpowers, ag-kit, obsidian, ayghri, mattpocock, and alexknowshtml (6 sources → `vendor/skills/*`, `vendor/agents/*`). Adding the new skills should follow that pattern and land under a `callstack` namespace.

Upstream layout: `skills/` holds 8 Callstack-maintained skills; `plugins/vendored/.agents/skills/` holds 3 external skills vendored via `plugins/vendored/skills-lock.json` (agent-device + dogfood ← callstackincubator/agent-device, react-native-testing ← callstack/react-native-testing-library). `plugins/*/skills/` are symlinks into those two locations, not independent copies; `.claude/skills/validate-skills` is an internal validation skill and not vendored.

Session that drove this decision: `.ai-files/sessions/2026-08-20-1023-add-callstack-agent-skills-to-Giltfile.md`. Plan: `.ai-files/memory-bank/plans/add-callstack-agent-skills-giltfile.md`.

## Decision

Vendor all 11 Callstack skills via Gilt under `vendor/skills/callstack/<skill>` as a single `Giltfile.yaml` repository entry `https://github.com/callstackincubator/agent-skills.git` on `main`:

- From `skills/`: assess-react-native-migration, create-react-native-library, github-actions, react-native-best-practices, react-native-brownfield-migration, react-native-tv-best-practices, react-navigation, upgrading-react-native (8).
- From `plugins/vendored/.agents/skills/` (external skills mirrored in the repo): agent-device, dogfood, react-native-testing (3). These are overlaid from the in-repo vendored mirror rather than their original upstreams, to avoid coupling to Callstack's vendoring workaround and to keep the Giltfile to a single repo entry.

Only `Giltfile.yaml` is committed; `vendor/` is gitignored and populated by `gilt overlay`. The skills are not auto-enabled in `default_skills.yaml` — enablement is left to per-project opt-in.

## Alternatives Considered

### Alternative 1: One Gilt entry per upstream repo (3 entries: agent-skills + agent-device + react-native-testing-library)
- **Pros**: Each external skill comes from its canonical source, not via the mirror.
- **Cons**: Couples the file to three repos and their internal layouts; breaks if upstream moves the skill path.
- **Why not**: Adds fragility for little benefit — the mirrored copies in `agent-skills` are already the distributed form; a single repo entry is simpler to maintain.

### Alternative 2: Submodule the agent-skills repo directly
- **Pros**: Exact upstream snapshot, simple to point at a commit.
- **Cons**: Submodule ergonomics (init/update friction); does not integrate with the existing Gilt overlay flow used for every other skill vendor.
- **Why not**: Breaks consistency with the established `Giltfile.yaml` + `vendor/` mechanism.

### Alternative 3: Copy skills into `skills/callstack/` as first-party skills
- **Pros**: Skills appear as own skills, no vendoring indirection.
- **Cons**: Forks upstream content; updates require manual copy rather than `gilt overlay`.
- **Why not**: Loses the upstream tracking benefit and pollutes first-party `skills/` with third-party content.

## Consequences

### Positive
- React Native best-practice guidance (FPS/TTI/memory/bundle, navigation stacks/tabs/drawers, TV focus, brownfield migration, upgrades, GitHub Actions artifacts) becomes available to agents without custom wiring.
- Single-repo Gilt entry keeps the config minimal and consistent with other vendors; updates are `gilt overlay` only.
- Namespacing under `callstack` preserves the `vendor/skills/<owner>/` convention and avoids collisions (verified: no existing skill uses these 11 names).

### Negative
- Vendor surface grows by 11 skills (larger `gilt overlay` clone and copy work, though mitigated by `blob:none` filtering).
- The 3 external skills are vendored via their mirror inside `agent-skills` rather than their canonical repos — a trade-off noted with a comment pointing to `plugins/vendored/skills-lock.json` for provenance.

**Confidence**: high — inventory, Giltfile edit, YAML validation, and `gilt overlay` (11 `SKILL.md` landed under `vendor/skills/callstack/`) were all verified in the session.
