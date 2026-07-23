# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

Claude operates in this repo as a **senior developer / architect**. Expect design-level reasoning about Azure Landing Zones, Bicep patterns, deployment stacks, and drift detection — not just line-level edits. Push back on changes that would weaken the drift signal (e.g. adding blanket `.drift-ignore` rules) or silently rename resources whose names are seeded from `uniqueString()` of the RG.

## Tooling (MCP)

Prefer MCP servers over ad-hoc CLI when checking work:

- **Azure MCP** — for live-state queries, resource lookups, and validating deployments against Azure (Resource Graph, ARM, RBAC, Activity Log). Use it to answer "what is actually in Azure right now?" before assuming the report.
- **Bicep MCP** — for authoring, validating, and linting Bicep. Use it for `bicep build`, decompile, schema/type checks, module signature inspection, and best-practice linting on any file under `bicep/`.
- **Python MCP** — for type checking, linting, and static analysis when working on the sibling agent code (`bicep-drift-agent/`). Use it to sanity-check imports, types, and unused symbols before running the drift pipeline.

If a check can be done through an MCP server, use the MCP server. Fall back to `az` / `python` CLI only when the MCP is unavailable.

## What this repository is

An **intentionally broken** test estate for the sibling [`bicep-drift-agent`](../bicep-drift-agent). Every module here exists to exercise a specific drift-detection path in the agent: property drift, missing/extra resources, ownership routing, RBAC drift, policy drift, deployment stacks, and Virtual WAN hub routing. It is **not** a reference landing zone — it is a fixture.

- Subscription: `594e0bd0-2a8d-4419-b281-87869c20fd03`, region `australiaeast`.
- Primary RG: `rg-drift-test` (see `.github/drift-lz-config.yml`). Deployment-stack RG: `drift-test-rg-deploy`. Database check RG: `rg-drift-database`.
- The estate is regularly torn down and redeployed. **Resource names are seeded from `uniqueString(resourceGroup().id)`**, so an RG rename renames everything, which drift detection then reads as a full-estate delete-and-recreate. Do not rename RGs casually.

## Commands

### Validate / build Bicep
```bash
az bicep build --file bicep/main.bicep --stdout > /dev/null           # main
for f in bicep/*.bicep; do az bicep build --file "$f" --stdout > /dev/null; done   # all
```

### Deploy the test estate (locally)
```bash
az group create --name rg-drift-test --location australiaeast
az deployment group create \
  --resource-group rg-drift-test \
  --template-file bicep/main.bicep \
  --parameters @bicep/parameters.json                                 # add environment=test if needed
```

### Deploy the deployment-stack fixture
```bash
az stack group create \
  --name test-stack --resource-group drift-test-rg-deploy \
  --template-file bicep/test-stack/main.bicep \
  --parameters @bicep/test-stack/parameters.dev.json \
  --action-on-unmanage deleteAll \
  --deny-settings-mode denyWriteAndDelete --deny-settings-apply-to-child-scopes --yes
```

CI equivalents: `.github/workflows/drift-lz-deploy.yml` (push to `main` → `bicep/main.bicep`) and `.github/workflows/deploy-stack.yml` (workflow_dispatch, deploy/teardown).

### Run a drift check against this estate

From the sibling `bicep-drift-agent/` clone:
```bash
python analyze_drift.py .../drift-test-resources/bicep/main.bicep rg-drift-test
```
CI runs are triggered from `bicep-drift-agent/.github/workflows/drift-lz-test.yml` (main estate), `drift-lz-stacks.yml` (stack), `drift-lz-database.yml`, `drift-lz-vhub-config.yml`.

## Architecture

### Estate composition (`bicep/main.bicep`)

`main.bicep` is a **module fan-out** — a top-level RG-scoped template that composes ~25 sibling `.bicep` modules, each covering one Azure resource family. Modules exist to give the agent a specific drift surface (property drift on `sku.capacity`, RBAC drift, WAF policy drift, firewall rule collection group drift, etc.), not to model a realistic workload.

Cost-gated modules (all default off):
- `deployNetworkAppliances` — Load Balancer, App Gateway WAF_v2 (~$180/mo), Front Door.
- `deployVirtualMachine` — Linux B1s VM + AMA extension.
- `deployAks` — 2× Standard_D2s_v3 (~$140/mo).
- `deployCosmos` — Cosmos DB SQL API.
- `deployVirtualHub` — Standard vWAN hub (~$0.25/hr, ~30 min to provision).

Free-tier surfaces that are **always deployed**: WAF policy (unattached), Azure Firewall Policy + rule collection groups (unattached), Recovery Services vault (no protected items).

### Drift LZ configs (`.github/drift-lz-*.yml`)

Each config is consumed by the agent's `drift-check-lz-hybrid.yml` reusable workflow. They differ only in the check they emit:

| Config | Purpose | Bicep entry point |
|---|---|---|
| `drift-lz-config.yml` | Main estate scan (owner-routed) | `bicep/main.bicep` on `main` |
| `drift-lz-stacks-config.yml` | Deployment-stack drift (posture + ownership oracle) | `bicep/test-stack/main.bicep` on `main` |
| `drift-lz-database-config.yml` | Database-focused scan in a separate sub | `bicep/main.bicep` on `main` |
| `drift-lz-vhub-config.yml` | Virtual WAN hub routing drift | `bicep/vhub.bicep` on `feat/vhub-routing` |

Owner routing is via `notifications.<team>.owners: [platform|workload]`. Webhook URLs use `${DRIFT_WEBHOOK_*}` refs resolved by the agent from secrets — never commit real URLs.

### `parameters.json` is what the SCAN compiles against

Documented at length in `bicep/README-parameters.md`. Non-obvious rule: the scan and the deploy are independent and must be kept in step **by hand**. If AKS is deployed with `deployAks=true` in CI but `parameters.json` still says `false`, the compiled desired state omits AKS and the deployed cluster is flagged `extra_in_azure`. Read that file before flipping any `deployX` gate.

### `.drift-ignore` policy

Only two rules live here, both narrowly scoped:

1. `Microsoft.DocumentDB/databaseAccounts.properties.locations` — Azure returns read-only fields and normalises location casing.
2. `Microsoft.Authorization/roleAssignments` name-glob `"Monitoring Reader -> ServicePrincipal:*"` with `drift_type: extra_in_azure` — orphaned grants from prior teardown cycles.

**Do not add blanket network-fabric ignores.** The old Phase 4 blanket rules for `virtualNetworks` / `subnets` / `networkSecurityGroups` / `routeTables` were removed on purpose — this estate now *declares* its own vnet/NSG/route table (`bicep/messaging-dns.bicep`), so blanket ignores would swallow real security drift (an injected allow-RDP-anywhere rule, a firewall-bypass route). If a rule is genuinely tolerable, scope it by resource type + name + `drift_type` and write the reason inline.

### Deployment stack fixture (`bicep/test-stack/`)

`test-stack/main.bicep` is deployed as an Azure **deployment stack**, not a plain deployment. That is what makes the agent's stack drift checks meaningful:

- The stack's `resources[]` list is an **authoritative ownership record** — the drift agent uses it instead of guessing ownership from the RG boundary.
- `denySettings` + `actionOnUnmanage` are the **enforcement posture** the agent checks against `expect:` in `drift-lz-stacks-config.yml`.

Only what is declared in `expect:` is asserted — live values are deliberately never used as a baseline (otherwise a permanently wide-open stack would validate itself). With `denyWriteAndDelete + apply_to_child_scopes: true`, manual portal/CLI drift injection is **blocked** by design. To inject drift for a live test round, redispatch `deploy-stack.yml` with `excluded_principals` set or `deny_settings_mode: none`.

## Conventions

- **Every module is a fixture.** When adding one, state (in the module or a PR comment) which drift path it exercises. If it doesn't exercise a new path, it probably shouldn't be here.
- **Never commit secrets or webhook URLs.** `@secure()` params (`postgresAdminPassword`, `sqlAdminPassword`, `vmAdminPassword`) are absent from `parameters.json` on purpose — main.bicep has throwaway defaults and CI overrides via secrets.
- **`deployX` gates default off.** Turning one on has cost implications documented inline in `bicep/main.bicep` — read the comment before flipping.
- **RG names are load-bearing.** `uniqueString(resourceGroup().id)` seeds most resource names. Renaming an RG rewrites the estate from the drift agent's point of view.
- **Deploy flow is push-triggered on `main`** for `main.bicep`, dispatch-only for the deployment stack. A push-triggered stack deploy would recreate billable resources between teardown cycles.
- **When in doubt, use the MCPs.** Bicep MCP to lint/build changes, Azure MCP to confirm live state, Python MCP when touching the sibling agent code.
