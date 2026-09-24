# T227-001 browser reproduction

This harness is intentionally diagnostic. It records the deployed URL, browser version, navigation timeline, console output, page errors, failed requests, DOM snapshot, navigation timing, a screenshot, and a Playwright trace. It does not modify application state or authentication configuration.

Clean-main baseline under test: `241e8b4a029405824400284799eba9bec1748e66`.

Verified clean-main staging deployment: `https://ecommerce-operations-staging.imranmirzadubai.workers.dev`.

The test must be run against that clean-main deployment and the resulting artifact must be retained with the task evidence before T227-001 is closed. A passing CI build alone is not sufficient evidence of browser reproduction.
