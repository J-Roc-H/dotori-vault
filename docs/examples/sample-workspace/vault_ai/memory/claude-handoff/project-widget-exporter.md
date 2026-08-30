---
name: project-widget-exporter
description: Widget exporter tool - batch export path, and the encoding trap in it
metadata:
  node_type: memory
  type: project
  status: verified
  agent: example-agent
  evidence:
    - "tools/widget-exporter/export.py, batch mode run on 40 files"
    - "commit 9f2c1ab"
  modified: 2026-01-15T09:00:00.000Z
---

The widget exporter runs in two modes. Batch mode is the one people use; single mode
exists only for debugging one failing input.

**The trap:** input files already in the legacy encoding must not go through the
conversion step again. A second pass corrupts non-ASCII characters permanently, and the
output still looks plausible, so it is not caught until much later.

**How to apply:** check the input encoding before converting. If it is already legacy,
skip the conversion entirely. Related: [[feedback-verify-output-first]]
