import sys, re, pathlib

def anchor(text, seen):
    # GitHub: lowercase, drop everything that is not alphanumeric/space/hyphen, spaces -> hyphens
    a = text.lower()
    a = re.sub(r'[^\w\s-]', '', a, flags=re.UNICODE)
    a = a.replace(' ', '-')
    n = seen.get(a, 0); seen[a] = n + 1
    return a if n == 0 else f"{a}-{n}"

def clean(text):
    text = re.sub(r'`([^`]*)`', r'\1', text)          # inline code
    text = re.sub(r'\*\*([^*]*)\*\*', r'\1', text)    # bold
    text = re.sub(r'\*([^*]*)\*', r'\1', text)        # italic
    text = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)  # links
    return text.strip()

path = pathlib.Path(sys.argv[1]); maxlvl = int(sys.argv[2])
lines = path.read_text().splitlines()
fence = False; seen = {}; out = []
for l in lines:
    if l.strip().startswith('```'): fence = not fence; continue
    if fence: continue
    m = re.match(r'^(#{1,6}) +(.*)$', l)
    if not m: continue
    lvl, raw = len(m.group(1)), clean(m.group(2))
    a = anchor(raw, seen)                              # every heading consumes an anchor slot
    if lvl == 1 or lvl > maxlvl: continue
    out.append(f"{'  ' * (lvl - 2)}- [{raw}](#{a})")

toc = "<!-- toc -->\n\n" + "\n".join(out) + "\n\n<!-- /toc -->"
src = path.read_text()
if '<!-- toc -->' in src:
    src = re.sub(r'<!-- toc -->.*?<!-- /toc -->', toc, src, flags=re.S)
else:
    src = src.replace('[TOC]', toc, 1)
path.write_text(src)
print(f"  {path}: {len(out)} entries")
