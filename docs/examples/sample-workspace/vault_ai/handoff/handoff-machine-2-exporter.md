# Handoff: widget exporter, remaining work

Written on machine-1. To be picked up on machine-2.

## What changed
Batch mode now skips conversion for inputs already in the legacy encoding.

## Evidence checked
- 40-file batch run, no corrupted output
- commit 9f2c1ab

## Not verified
Single mode still converts unconditionally. Nobody uses it, but it is the same bug.

## Start here
`tools/widget-exporter/export.py`, the branch around the encoding check.

## Delete this file
When single mode is fixed and verified. A handoff is a work order, not a memory - it is
removed when done, not archived.
