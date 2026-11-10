---
name: loading-states
description: Add a loading state to a React list that fetches data, with Suspense and a skeleton that keeps the list's shape. Use when a task asks for a loading, pending or skeleton state in a component that reads server data.
---

# Loading states

1. Use the repository's Suspense-compatible data source, such as a cached promise read with `use()`. Scope cached data to its query parameters and follow the project's cache and invalidation conventions.
2. Wrap the list in `<Suspense>` with a fallback that preserves the list's shape. Use the project's loading component, or adapt [assets/ListSkeleton.tsx](assets/ListSkeleton.tsx) to its design tokens, list layout and language. Keep a meaningful accessible loading state, including `aria-busy`.
3. Check that the fallback appears while data is pending and is replaced by the list when it resolves.
4. Optionally run [scripts/check-loading.sh](scripts/check-loading.sh) `<page file> <fallback file>` from the repository root. It searches for text only: matches and missing matches can both be misleading, so review the behavior independently.
