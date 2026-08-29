---
name: feedback-verify-output-first
description: Check the actual output folder before theorizing about an output bug
metadata:
  node_type: memory
  type: feedback
  status: active
  agent: example-agent
  modified: 2026-01-20T14:30:00.000Z
---

When a bug is about produced files, open the output folder and compare the real artifacts
before forming a hypothesis.

**Why:** two sessions were spent debugging a generator that was working correctly. The
files were being written to a second output path configured months earlier, and nobody
had looked at either folder.

**How to apply:** artifacts first, theory second.
