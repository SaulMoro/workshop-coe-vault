---
name: e2e-tests
description: Write end-to-end tests that drive the application in a real browser with Playwright. Use when adding or fixing a test that covers a complete user journey.
---

# End-to-end tests

1. Before writing, walk the journey once in the browser with the playwright MCP server, and note the roles and names of the elements you use.
2. One journey per test, named after what the person achieves: `places an order with a saved address`.
3. Find elements the way a person does: `getByRole` with the accessible name, then `getByLabel` or `getByText`. Use test ids only when nothing visible identifies the element.
4. Use the web-first assertions (`await expect(locator).toBeVisible()`), which wait on their own. No fixed timeouts.
5. Each test prepares its own data and runs alone: no test relies on another one having run first.
6. Run the test three times in a row before you call it done. A test that fails once in three is not done.
