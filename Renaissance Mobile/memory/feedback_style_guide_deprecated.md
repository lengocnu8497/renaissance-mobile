---
name: Style guide deprecated
description: Old Theme.swift style guide is deprecated — use design file colors/values directly
type: feedback
---

Do NOT reference Theme.Colors, Theme.Typography, Theme.Spacing, Theme.Brand, Theme.Gradients, or any other Theme.* constants when implementing UI. The old style guide (Theme.swift) is deprecated.

**Why:** The design system has been replaced with a new color system. Use hex values and sizes directly from the design file.

**How to apply:** When writing or editing any UI code, inline the values from the current design (e.g., `Color(hex: "#8E4C5C")` not `Theme.Colors.primaryHome`, `Font.custom("Outfit-SemiBold", size: 13)` not `Theme.Typography.cardLabel`).
