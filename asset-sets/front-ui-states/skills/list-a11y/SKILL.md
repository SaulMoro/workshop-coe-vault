---
name: list-a11y
description: Accessibility practices for React lists and screen readers. Use when creating or reviewing a list's accessibility, ARIA attributes or screen reader support.
---

# List accessibility

1. Give the list a meaningful accessible name, using `aria-label` or `aria-labelledby` as appropriate.
2. Provide a summary announced when the item count changes, using a stable polite live region. If the summary is only for screen readers, use the repository's visually hidden styling.
3. Anything shown only with colour (a status badge, a role pill) also has its text.
4. Optionally run [scripts/check-a11y.sh](scripts/check-a11y.sh) `<list file>` from the repository root. It searches for text only: matches and missing matches can both be misleading, so review the behavior independently.
