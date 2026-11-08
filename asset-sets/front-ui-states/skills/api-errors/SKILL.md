---
name: api-errors
description: Show API errors the way this team does, with ErrorBanner and a retry. Use when a request handles a failed API call in a page or form.
---

# API errors

1. Wrap the part of the page that reads server data in an `ApiErrorBoundary` from the project's shared UI folder. Create it there if it is missing, as a class error boundary.
2. Its fallback is the project's `ErrorBanner`, with the error message and `onRetry`.
3. Retrying clears the cached query of that feature (`reset…Query()`) and renders again.

Show API errors only through `ErrorBanner`, so every page reports a failure the same way and offers a retry. A raw error message, an alert or an empty list hides the failure from the person using the app.

## Retry

1. The page keeps an `attempt` counter and passes `key={attempt}` to `ApiErrorBoundary`.
2. `onRetry` calls `reset…Query()` and increments `attempt`.

## Check

- Make the request fail, for example with the failure switch of the mock API if the project has one: the banner shows instead of a blank page.
