# parameters.json — what the drift scan compiles against

The drift agent compiles `main.bicep` to work out the DESIRED state. Without a
parameter file it uses each parameter's `defaultValue`, and every `deployX` gate
here defaults to **false** — so a gated module is condition-skipped, never enters
desired state, and anything it deployed shows up in the report as
`extra_in_azure` ("unmanaged resource, consider deleting").

That is exactly what happened on 2026-07-21: AKS was deployed with
`deployAks=true` via workflow dispatch, the scan compiled with the default
`false`, and `aks-drift-test` was reported as an extra resource that nobody
managed. The analysis correctly refused to delete it, but only by inferring
from the `authorized_deployment` attribution that something was off.

**This file is read by the SCAN, not the deploy.** `drift-lz-deploy.yml` passes
`--parameters` explicitly, so the two are independent - keep them in step by
hand. The rule is simply: whatever the estate is actually deployed with, say so
here, or the scan is comparing against a different estate than the one that
exists.

## Why JSON and not a .bicepparam

The agent reads either, but with different fidelity:

- `parameters.json` goes through `json.load`, so `true` stays a boolean and
  `1` stays an int.
- `parameters/<env>.bicepparam` is read by a line-by-line text parser that
  strips quotes and yields **strings for everything** - `deployAks = true`
  becomes `"true"`. That happens to work for condition gates (the comparator
  treats the string "false" as false), but a param feeding a numeric or boolean
  RESOURCE PROPERTY would be compared as a string against Azure's real type.

Use JSON here until that parser is type-aware.

## Secure parameters are deliberately absent

`postgresAdminPassword`, `sqlAdminPassword` and `vmAdminPassword` are `@secure()`
and are NOT listed. They have defaults in `main.bicep` (this is a throwaway test
estate), the deploy does not pass them, and the agent redacts them from reports.
Do not add secrets to this file - it is committed.

## Teardown

`deployAks: true` means the scan now EXPECTS a cluster. Tear AKS down and the
next report flips from "extra" to `missing_in_azure`. That is the honest
reading - the template says deploy it and it is not there - so set the gate back
to `false` in the same change that removes the cluster.
