#!/usr/bin/env python3
"""Generate a GitHub-compatible table of contents for Markdown files.

    gen_toc.py FILE [FILE...] [--max-level N] [--min-level N] [--check]

GitHub does not render `[TOC]`, `[[_TOC_]]` or `{:toc}` — those are Doxygen, GitLab
and Kramdown syntax. On GitHub they display as literal text, so a file relying on one
has a dead line where its navigation should be. This writes a real Markdown list.

Placement, in order of preference:
  1. between `<!-- toc -->` and `<!-- /toc -->`  (replaced in place; use this)
  2. in place of a `[TOC]` / `[[_TOC_]]` / `{:toc}` line, which is then replaced by
     marker-wrapped output so later runs update in place

If neither is present the file is left alone and the tool says so. It does not guess
an insertion point.

Every generated link is verified against the headings before the file is written.
Exit codes: 0 ok, 1 a file needs regenerating (--check) or a link failed to verify.
"""
import sys, re, pathlib

PLACEHOLDER = re.compile(r'^[ \t]*(\[TOC\]|\[\[_TOC_\]\]|\{:toc\})[ \t]*$', re.M)
MARKERS = re.compile(r'<!-- toc -->.*?<!-- /toc -->', re.S)
ATX = re.compile(r'^(#{1,6}) +(.*?)[ \t]*#*[ \t]*$')


def clean(text):
    """Heading text as GitHub renders it: markup stripped, content kept."""
    text = re.sub(r'`([^`]*)`', r'\1', text)
    text = re.sub(r'\*\*([^*]*)\*\*', r'\1', text)
    text = re.sub(r'__([^_]*)__', r'\1', text)
    text = re.sub(r'\*([^*]*)\*', r'\1', text)
    text = re.sub(r'!?\[([^\]]*)\]\([^)]*\)', r'\1', text)
    return text.strip()


def anchor(text, seen):
    """GitHub's slug: lowercase, drop all but word/space/hyphen, spaces to hyphens,
    then a -1/-2 suffix for repeats. Unicode letters are kept (\\w with re.UNICODE)."""
    a = re.sub(r'[^\w\s-]', '', text.lower(), flags=re.UNICODE).replace(' ', '-')
    n = seen.get(a, 0)
    seen[a] = n + 1
    return a if n == 0 else f"{a}-{n}"


def headings(src):
    """(level, cleaned_text) for every ATX heading outside a fenced code block."""
    out, fence = [], None
    for line in src.splitlines():
        s = line.strip()
        m = re.match(r'^(`{3,}|~{3,})', s)
        if m:
            tok = m.group(1)[0]
            if fence is None:
                fence = tok
            elif fence == tok:
                fence = None
            continue
        if fence:
            continue
        m = ATX.match(line)
        if m:
            out.append((len(m.group(1)), clean(m.group(2))))
    return out


def build(src, lo, hi):
    seen, lines, valid = {}, [], set()
    for lvl, text in headings(src):
        a = anchor(text, seen)      # EVERY heading consumes a slot, listed or not
        valid.add(a)
        if lo <= lvl <= hi and text:
            lines.append(f"{'  ' * (lvl - lo)}- [{text}](#{a})")
    return lines, valid


def process(path, lo, hi, check):
    p = pathlib.Path(path)
    src = p.read_text(encoding='utf-8')
    lines, valid = build(src, lo, hi)
    if not lines:
        print(f"  {path}: no headings between level {lo} and {hi} — skipped")
        return 0

    broken = [l for l in lines if l.split('](#')[1][:-1] not in valid]
    if broken:
        print(f"  !! {path}: {len(broken)} link(s) failed verification — NOT written")
        for b in broken[:5]:
            print(f"       {b}")
        return 1

    block = "<!-- toc -->\n\n" + "\n".join(lines) + "\n\n<!-- /toc -->"
    if MARKERS.search(src):
        new = MARKERS.sub(lambda _: block, src, count=1)
        how = "updated"
    elif PLACEHOLDER.search(src):
        new = PLACEHOLDER.sub(lambda _: block, src, count=1)
        how = "replaced placeholder"
    else:
        print(f"  -- {path}: no <!-- toc --> markers and no [TOC] placeholder — left alone.")
        print(f"     Add `<!-- toc -->` / `<!-- /toc -->` where the contents should go.")
        return 0

    if new == src:
        print(f"  ok (up to date): {path} — {len(lines)} entries")
        return 0
    if check:
        print(f"  STALE: {path} — {len(lines)} entries would change")
        return 1
    p.write_text(new, encoding='utf-8')
    print(f"  {how}: {path} — {len(lines)} entries, all links verified")
    return 0


def main():
    args = sys.argv[1:]
    lo, hi, check, files = 2, 3, False, []
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--check':
            check = True
        elif a.startswith('--max-level'):
            hi = int(a.split('=', 1)[1]) if '=' in a else int(args[(i := i + 1)])
        elif a.startswith('--min-level'):
            lo = int(a.split('=', 1)[1]) if '=' in a else int(args[(i := i + 1)])
        elif a in ('-h', '--help'):
            print(__doc__); return 0
        else:
            files.append(a)
        i += 1
    if not files:
        print(__doc__); return 2
    if lo < 1 or hi > 6 or lo > hi:
        print(f"  !! bad level range {lo}..{hi}"); return 2
    return max(process(f, lo, hi, check) for f in files)


if __name__ == '__main__':
    sys.exit(main())
