---
description: Environment variables in Create React App projects
applyTo: "src/**/*.{js,jsx,ts,tsx}"
---

- Read build-time variables from `process.env`. Only names that start with `REACT_APP_` reach the browser bundle.
- Everything in the bundle is public. Keep secrets on the server, never in a `REACT_APP_` variable.
- Add each new variable to `.env.example` with a placeholder value and a comment that says what it is for.
