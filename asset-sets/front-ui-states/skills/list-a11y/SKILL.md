---
name: list-a11y
description: Accessibility rules for lists in this team's React UI, for screen readers. Use when a task asks to review or improve accessibility, ARIA attributes or screen reader support.
---

# List accessibility

Every list our team ships follows these rules.

1. The `<ul>` has an `aria-label` that says what it lists, such as `aria-label="Pedidos"`.
2. Right before the `<ul>`, a summary only screen readers hear, announced when it changes: `<p className="sr-only" aria-live="polite">{items.length} pedidos</p>`. Wrap both in a fragment.
3. Anything shown only with colour (a status badge, a role pill) also has its text.
4. When you finish, run [scripts/check-a11y.sh](scripts/check-a11y.sh) `<list file>` from the repository root and fix what it reports.
