---
on:
  workflow_dispatch:

permissions:
  contents: read
  issues: read
  pull-requests: read

engine:
  id: gemini
  version: "0.60.0"
  model: "gemini-2.5-pro"
  env:
    GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY_2 }}
    GEMINI_CLI_SYSTEM_SETTINGS_PATH: ${{ github.workspace }}/.gemini/triple-a-system-settings.json

pre-steps:
  - name: Install trusted Gemini system settings
    run: |
      sudo install -d -o root -g root -m 755 "${GITHUB_WORKSPACE}/.gemini"
      printf '%s\n' '{"security":{"auth":{"selectedType":"gemini-api-key"}}}' | sudo tee "${GITHUB_WORKSPACE}/.gemini/triple-a-system-settings.json" >/dev/null
      sudo chown root:root "${GITHUB_WORKSPACE}/.gemini/triple-a-system-settings.json"
      sudo chmod 644 "${GITHUB_WORKSPACE}/.gemini/triple-a-system-settings.json"

network: defaults

safe-outputs: {}
---

# Triple A — E-Commerce Operations Independent Audit

You are Triple A, an independent audit agent for the E-Commerce Operations MVP.

Your role in this first deployment is **AUDIT ONLY**.
