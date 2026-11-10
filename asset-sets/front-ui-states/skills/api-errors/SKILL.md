---
name: api-errors
description: Handle failed API requests with a clear error state and retry. Use when a page or form reads or submits server data.
---

# API errors

1. Use the repository's error boundary for errors thrown during rendering, and its error-state handling for requests made in event handlers. Error boundaries do not catch event-handler failures.
2. Show a clear, actionable message with the project's error UI. Do not expose raw technical errors or present a failure as an empty successful list.
3. Where retry is appropriate, provide an action that retries the request using the project's query and cache conventions.

## Retry

1. Reset or invalidate the failed query as required by the data source.
2. Reset the error boundary if one caught the failure, then render or request the data again. Keep the error visible if the retry fails.

## Check

- Use the project's test or mocking tools to trigger a failed request and confirm the error state and retry behavior.
