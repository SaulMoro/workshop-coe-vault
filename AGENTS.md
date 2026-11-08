# workshop-coe-vault

A practice vault of agent assets, used in the AI CoE training. Its content is generic and its owners are fictional.

- Asset sets live in `asset-sets/<set>/`: a `manifest.json`, a `README.md` and the assets (`skills/`, `instructions/`, `agents/`, `hooks/`, `mcp.json`).
- To create, review or propose an asset, use the asset-review skill (`/asset-review`).
- The tools in `tools/` are bash. They use Node only to read JSON and must keep working in bash 3.2 (macOS) and Git Bash (Windows).
- Text for models (skills, instructions, agents) is in English. Documentation for people and tool output are in Spanish.
- Before you finish, run `tools/verify.sh` and `tools/test.sh` and fix every error.
