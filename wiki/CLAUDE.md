# Wiki Schema — Godot Web RPG

Instructions for any LLM session maintaining this wiki. Read this before
touching anything under `wiki/`.

## Four layers

| Layer | Location | Who writes it |
|---|---|---|
| **Raw source** | `scripts/`, `server/`, `scenes/`, `tests/`, `tools/` | Humans + normal dev work. The wiki **never** edits it. |
| **Graph** | `wiki/graph/` | `build_graph.py` only. Regenerable cache — **never hand-edit** `graph.json` or `symbol_index.md`. |
| **Wiki** | `wiki/pages/`, `index.md`, `log.md` | Written by hand (by the LLM). The only layer carrying judgment. |
| **Design** | `wiki/design/` | Proposals. **Not implemented.** |

**`wiki/pages/` is what the game IS. `wiki/design/` is what it is MEANT TO
BECOME.** Never let a claim cross from design to pages without the code
changing first — the moment a proposal reads as fact, the whole wiki stops
being trustworthy. Every design page carries `STATUS: PLAN` in its title.

## Why the graph layer is custom here

`code2graph` is tree-sitter based and **has no GDScript grammar**. Running
`code2graph index .` inside `scripts/` admits **0 files** — 21 of the 22
GDScript files in this repo are invisible to it. So `build_graph.py` runs two
extractors and merges them:

- **GDScript** — a regex extractor in `build_graph.py`. Top-level-only
  (column 0) for members, because it has no scope awareness.
- **JavaScript** — the real `code2graph` CLI at `--tier scope`, explicitly
  set. The CLI defaults to `scope` but the Python binding defaults to `name`;
  never rely on either default.

Regenerate with:

```bash
python wiki/graph/build_graph.py
```

## Page conventions

- **One topic per page.** One source file → one page. Cross-cutting concerns
  (the wire protocol, security, gaps, decisions) get their **own** page —
  never bury a finding inside whichever module page you happened to be
  writing.
- **Cite, don't recall.** Every structural claim carries a `file.ext:line`
  reference. If you cannot point at a line, don't write the claim.
- **Verify before writing "nothing uses this."** Two traps in this codebase:
  1. *Dynamic dispatch* — `HeroClass.create()` (`hero_class.gd:22`) picks a
     subclass by string, and `network_manager.gd` dispatches the whole
     protocol through a `match` on a string field. Neither shows up as a
     static edge.
  2. *The `@rpc` decoys* — `game_state.gd` has four `@rpc`-annotated
     functions that are called as **plain functions**, never over RPC. See
     [decisions.md](pages/decisions.md).
- Link related pages with regular markdown links. Prefer linking over
  restating.
- Findings are graded: **Confirmed** (traced to lines, both sides checked) vs
  **Suspected** (looks wrong, not yet proven). Never promote one to the other
  without doing the work.

## Operations

**Ingest** (after code changes):
1. `python wiki/graph/build_graph.py`
2. Diff the new `symbol_index.md` against what pages claim.
3. Update affected pages; add new pages for new files.
4. Append to `log.md`.

**Query**: read `index.md` first, then drill into pages. Only fall back to
the graph or raw source when the wiki cannot answer — if that happens often,
the wiki has a gap worth filling.

**Lint** (periodic): pages missing from `index.md`; orphan pages with no
inbound link; entries in `known-gaps.md` that the code has since fixed;
claims whose cited line numbers have drifted.

## Log format

Append-only, one entry per pass, greppable with `grep "^## \[" log.md`:

```
## [YYYY-MM-DD] <ingest|query|lint> | <description>
```
