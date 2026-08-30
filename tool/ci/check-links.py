"""Fail the build on a relative Markdown link that points at nothing.

Written because moving files is how documentation rots: the restructure that split the
repository into tool/ and the two vaults broke seven relative links, and reading did not
catch any of them. An intention to update links is not a check that runs every time.

Only relative links are followed. External URLs are not fetched - a network call in CI
buys flakiness, and a dead external link does not mean this repository is wrong about
its own contents.
"""
import os
import re
import sys

LINK = re.compile(r"\]\(([^)#:]+?)(?:#[^)]*)?\)")
SKIP_DIRS = {".git"}

def main(root):
    broken = []
    checked = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if not name.endswith(".md"):
                continue
            path = os.path.join(dirpath, name)
            with open(path, encoding="utf-8") as handle:
                text = handle.read()
            for match in LINK.finditer(text):
                target = match.group(1).strip()
                if target.startswith(("http://", "https://", "mailto:")):
                    continue
                checked += 1
                if not os.path.exists(os.path.normpath(os.path.join(dirpath, target))):
                    broken.append((path, target))
    for path, target in broken:
        print("broken link: {0} -> {1}".format(path, target))
    print("{0} relative link(s) checked, {1} broken".format(checked, len(broken)))
    return 1 if broken else 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
