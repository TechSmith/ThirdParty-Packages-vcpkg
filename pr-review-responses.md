# PR #133 Review Comment Responses

All 4 comments from Copilot (automated reviewer). All valid, all worth fixing.

## Comment 1: Missing `d3d12va` output format mapping
**File:** `test002--verify-decoding.ps1:57-62`
**Issue:** `$hwOutputFormat` switch has no `d3d12va` entry. Falls through to default, passing `d3d12va` instead of `d3d12`.
**Fix:** Add `"d3d12va" { "d3d12" }` to the switch.
**Commit:** `44f0592`
**Reply:** "Good catch. Adding d3d12va → d3d12 mapping."

## Comment 2: `d3d12va` not in hwaccel candidates
**File:** `test002--verify-decoding.ps1:166-170`
**Issue:** d3d12va features exist in vcpkg.json (`hwaccel-av1-d3d12va`, etc.) but never exercised by decode test.
**Fix:** Add `d3d12va` to Windows candidates, gated on `^hwaccel-.*-d3d12va$` feature presence (same pattern as vulkan).
**Commit:** `4704621`
**Reply:** "Valid. Adding d3d12va to hwaccel candidates, feature-gated."

## Comment 3: Misleading SKIP message in decode test
**File:** `test002--verify-decoding.ps1:180-182`
**Issue:** "No hardware decoding support on this machine" fires when feature disabled OR sample generation failed — not just missing HW.
**Fix:** Split into two distinct messages: "feature not enabled" vs "sample clip unavailable".
**Commit:** `693f803`
**Reply:** "Fair point. Splitting into distinct skip reasons."

## Comment 4: Misleading SKIP message in encode test
**File:** `test003--verify-encoding.ps1:149-151`
**Issue:** Same as #3 but for encoding. Says "No hardware encoding support" when it's really "no encoder features enabled".
**Fix:** Change to "No HW encoder features enabled for X".
**Commit:** `5c03de5`
**Reply:** "Agreed. Updating wording."

## Summary

| # | File | Change | Effort |
|---|------|--------|--------|
| 1 | test002 L57-62 | Add `d3d12va` → `d3d12` switch case | Trivial |
| 2 | test002 L166-170 | Add `d3d12va` to hwaccel candidates (feature-gated) | Small |
| 3 | test002 L180-182 | Split skip into feature-disabled vs sample-unavailable | Small |
| 4 | test003 L149-151 | Fix skip message wording | Trivial |
