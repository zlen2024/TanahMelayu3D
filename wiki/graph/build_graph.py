#!/usr/bin/env python3
"""Build the structural graph for the Godot Web RPG.

Two extractors, because no single tool covers this codebase:
  - GDScript (22 files): hand-rolled regex extractor. code2graph is
    tree-sitter based and has NO GDScript grammar -- it indexes 0 files
    for scripts/. See wiki/pages/known-gaps.md.
  - JavaScript (3 files): code2graph CLI, --tier scope, via --json.

Emits graph.json (facts) + symbol_index.md (human-browsable catalog).
Both are regenerable caches -- never hand-edit them.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent

# Curated source roots. Deliberately NOT rglob(ROOT): bin/ holds ~200MB of
# Godot binaries, dist/ is build output, .godot/ is an editor cache and
# server/node_modules/ is vendored.
GD_ROOTS = ["scripts", "tests"]
EXCLUDE_PARTS = {"node_modules", "dist", ".godot", "bin", ".git", "wiki"}

RE_CLASS_NAME = re.compile(r"^class_name\s+(\w+)")
RE_EXTENDS = re.compile(r'^extends\s+([\w\."/:]+)')
RE_FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\((.*?)\)\s*(?:->\s*([\w\[\], ]+))?\s*:")
RE_SIGNAL = re.compile(r"^signal\s+(\w+)\s*(\(.*?\))?")
RE_CONST = re.compile(r"^const\s+(\w+)")
RE_VAR = re.compile(r"^(?:@export\s+)?(?:@onready\s+)?var\s+(\w+)")
RE_ENUM = re.compile(r"^enum\s+(\w+)")
RE_RPC = re.compile(r"^@rpc\((.*?)\)")
RE_LOAD = re.compile(r"(?:pre)?load\(\s*[\"']([^\"']+)[\"']\s*\)")
RE_ONREADY = re.compile(r"^@onready\s+var\s+(\w+)")


def iter_source(roots, suffix):
    for r in roots:
        base = ROOT / r
        if not base.exists():
            continue
        for p in sorted(base.rglob("*" + suffix)):
            if EXCLUDE_PARTS & set(p.parts):
                continue
            yield p


def extract_gd(path):
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    rel = path.relative_to(ROOT).as_posix()
    sym = {
        "file": rel, "lang": "gdscript", "class_name": None, "extends": None,
        "funcs": [], "signals": [], "consts": [], "vars": [], "enums": [],
        "onready": [], "rpcs": [], "loads": [], "loc": len(lines),
    }
    pending_rpc = None
    for i, raw in enumerate(lines, 1):
        line = raw.strip()
        # Member declarations sit at column 0; anything indented is a local
        # inside a func body. The regex extractor has no scope awareness, so
        # indentation is the only signal available. See known-gaps.md.
        top_level = bool(raw) and raw[0] not in (" ", "\t")
        m = RE_CLASS_NAME.match(line)
        if m:
            sym["class_name"] = m.group(1)
        m = RE_EXTENDS.match(line)
        if m:
            sym["extends"] = m.group(1)
        m = RE_RPC.match(line)
        if m:
            pending_rpc = m.group(1).replace('"', "").replace(" ", "")
            continue
        m = RE_FUNC.match(line)
        if m:
            sym["funcs"].append({
                "name": m.group(2), "line": i, "args": m.group(3).strip(),
                "returns": (m.group(4) or "").strip() or None,
                "static": bool(m.group(1)), "rpc": pending_rpc,
            })
            if pending_rpc:
                sym["rpcs"].append({"name": m.group(2), "line": i, "config": pending_rpc})
            pending_rpc = None
            continue
        if line and not line.startswith("#"):
            pending_rpc = None
        m = RE_SIGNAL.match(line)
        if m:
            sym["signals"].append({"name": m.group(1), "line": i, "args": (m.group(2) or "").strip()})
        m = RE_CONST.match(line)
        if m and top_level:
            sym["consts"].append({"name": m.group(1), "line": i})
        m = RE_ENUM.match(line)
        if m and top_level:
            sym["enums"].append({"name": m.group(1), "line": i})
        m = RE_ONREADY.match(line)
        if m and top_level:
            sym["onready"].append({"name": m.group(1), "line": i})
        elif top_level:
            m = RE_VAR.match(line)
            if m:
                sym["vars"].append({"name": m.group(1), "line": i})
        for lm in RE_LOAD.finditer(raw):
            sym["loads"].append({"target": lm.group(1), "line": i})
    return sym


def extract_js():
    """Delegate to code2graph CLI, tier=scope (its default, set explicitly)."""
    server = ROOT / "server"
    exe = Path.home() / ".cargo" / "bin" / "code2graph.exe"
    if not exe.exists():
        print("  ! code2graph not found; skipping JS layer", file=sys.stderr)
        return {"symbols": [], "edges": []}
    subprocess.run([str(exe), "index", "."], cwd=server, capture_output=True)
    syms = subprocess.run([str(exe), "symbols", ".", "--tier", "scope", "--json"],
                          cwd=server, capture_output=True, text=True)
    data = json.loads(syms.stdout) if syms.stdout.strip().startswith("{") else {"results": []}
    edges = []
    for s in data.get("results", []):
        if s["kind"] != "function":
            continue
        u = subprocess.run([str(exe), "usages", s["name"], "--tier", "scope", "--json"],
                           cwd=server, capture_output=True, text=True)
        if u.stdout.strip().startswith("{"):
            for e in json.loads(u.stdout).get("results", []):
                edges.append({
                    "from": e.get("fromDisplay") or e.get("from"),
                    "to": s["name"], "file": e.get("file"),
                    "line": e.get("line"), "kind": e.get("kind"),
                })
    return {"symbols": data.get("results", []), "edges": edges}


def resolve_gd_edges(gd):
    """res:// load()/preload() targets -> repo-relative edges."""
    edges = []
    for s in gd:
        for l in s["loads"]:
            t = l["target"]
            if not t.startswith("res://"):
                continue
            edges.append({"from": s["file"], "to": t[len("res://"):],
                          "line": l["line"], "kind": "load"})
    return edges


def main():
    gd = [extract_gd(p) for p in iter_source(GD_ROOTS, ".gd")]
    print("  GDScript: %d files, %d funcs" % (len(gd), sum(len(s["funcs"]) for s in gd)))
    js = extract_js()
    print("  JavaScript: %d symbols, %d edges" % (len(js["symbols"]), len(js["edges"])))

    scenes = []
    for p in iter_source(["scenes", "tests"], ".tscn"):
        txt = p.read_text(encoding="utf-8", errors="replace")
        scenes.append({
            "file": p.relative_to(ROOT).as_posix(),
            "ext_resources": re.findall(r'\[ext_resource[^\]]*path="res://([^"]+)"', txt),
            "nodes": re.findall(r'\[node name="([^"]+)"', txt),
        })
    print("  Scenes: %d .tscn files" % len(scenes))

    graph = {"gdscript": gd, "javascript": js, "scenes": scenes,
             "gd_edges": resolve_gd_edges(gd)}
    (OUT / "graph.json").write_text(json.dumps(graph, indent=2), encoding="utf-8")

    L = ["# Symbol Index", "",
         "Generated by `build_graph.py`. Regenerable cache -- do not hand-edit.",
         "", "## GDScript", ""]
    for s in sorted(gd, key=lambda x: x["file"]):
        L.append("### `%s`" % s["file"])
        hdr = []
        if s["class_name"]:
            hdr.append("`class_name %s`" % s["class_name"])
        if s["extends"]:
            hdr.append("extends `%s`" % s["extends"])
        hdr.append("%d LOC" % s["loc"])
        L += ["", " | ".join(hdr), ""]
        for k, label in (("enums", "enum"), ("consts", "const"), ("signals", "signal"),
                         ("vars", "var"), ("onready", "@onready var")):
            for it in s[k]:
                L.append("- %s **%s** — L%d" % (label, it["name"], it["line"]))
        for f in s["funcs"]:
            tag = " `@rpc`" if f["rpc"] else ""
            st = "static " if f["static"] else ""
            ret = " -> %s" % f["returns"] if f["returns"] else ""
            L.append("- %sfunc **%s**(%s)%s — L%d%s" % (st, f["name"], f["args"], ret, f["line"], tag))
        L.append("")

    L += ["## JavaScript", ""]
    byfile = {}
    for s in js["symbols"]:
        byfile.setdefault(s["file"], []).append(s)
    for f in sorted(byfile):
        L += ["### `server/%s`" % f, ""]
        for s in sorted(byfile[f], key=lambda x: x["line"]):
            L.append("- %s **%s** — L%d" % (s["kind"], s["name"], s["line"]))
        L.append("")

    L += ["## Scenes", ""]
    for s in scenes:
        nodes = ", ".join("`" + n + "`" for n in s["nodes"][:14])
        if len(s["nodes"]) > 14:
            nodes += " …"
        res = ", ".join("`" + r + "`" for r in s["ext_resources"]) or "—"
        L += ["### `%s`" % s["file"], "", "- nodes: %s" % nodes, "- ext_resources: %s" % res, ""]

    (OUT / "symbol_index.md").write_text("\n".join(L), encoding="utf-8")
    print("  -> graph.json + symbol_index.md written to %s" % OUT)


if __name__ == "__main__":
    main()
