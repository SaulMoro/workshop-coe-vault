---
name: api-errors
description: Show API errors the way this team does, with ErrorBanner and a retry. Use when a request handles a failed API call in a page or form.
---

# API errors

1. Wrap the part of the page that reads server data in `ApiErrorBoundary` from `src/shared/ui/ApiErrorBoundary.tsx`. Create it if it is missing, as a class error boundary.
2. Its fallback is always `ErrorBanner` from `src/shared/ui/ErrorBanner.tsx`, with the error message and `onRetry`.
3. Retrying clears the cached query of that feature (`reset…Query()`) and renders again.

ALWAYS use <ErrorBanner> for API errors. NEVER show a raw error, an alert or an empty list instead.

## Retry

1. The page keeps an `attempt` counter and passes `key={attempt}` to `ApiErrorBoundary`.
2. `onRetry` calls `reset…Query()` and increments `attempt`.
Think step by step before you write the retry.

## Check

- Open the page with `?fail=1`: the banner shows instead of a blank page.

You are an expert React developer who never lets an API error reach the user unhandled.
