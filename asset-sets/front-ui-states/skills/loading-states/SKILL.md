---
name: loading-states
description: Add a loading state to a React list that fetches data, with Suspense and a skeleton that keeps the list's shape. Use when a task asks for a loading, pending or skeleton state in a component that reads server data.
---

# Loading states

This is our team's pattern for every list that reads server data. Follow it as written, even if another page in the repository does it differently.

1. The list reads its data with `use()` from the cached query of its feature (`<feature>Query.ts` in the feature folder): one shared promise per feature. Create the query if it is missing. Do not load the data with `useState` and `useEffect`.
2. The page wraps the list in `<Suspense>`. Keep the `<Suspense>` in the page, not inside the list.
3. The fallback is the shared `ListSkeleton`. If the project has none, copy [ListSkeleton.tsx](assets/ListSkeleton.tsx) into its shared UI folder. Keep its `aria-busy` and pass as many `rows` as the list usually shows.
4. When you finish, run [check-loading.sh](scripts/check-loading.sh) `<page file>` from the repository root and fix what it reports. It checks the `<Suspense>`, the `ListSkeleton` fallback and its `aria-busy`.
