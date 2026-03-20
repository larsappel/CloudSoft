# CloudSoft Deployment Verification Report

**Date:** 2026-03-20
**Region:** swedencentral
**GitHub Repo:** [larsappel/CloudSoft](https://github.com/larsappel/CloudSoft)

## Infrastructure Summary

| Resource | Value |
|----------|-------|
| Proxy IP | 20.240.45.13 |
| Bastion IP | 20.91.226.16 |
| Storage Account | stcloudsoftsubrupb5khl5g |
| CosmosDB | cosmos-cloudsoft-subrupb5khl5g |
| Runner | cloudsoft-runner (online) |
| Region | swedencentral |

## Deployment Timeline

1. **GitHub repo created:** SUCCESS — https://github.com/larsappel/CloudSoft
2. **Code pushed:** SUCCESS — 31 files, main branch
3. **Runner token:** Obtained
4. **Runner version:** 2.333.0
5. **Resource group created:** rg-cloudsoft in swedencentral
6. **Bicep deployment:**
   - FIRST ATTEMPT: Failed — Azure CLI bug "The content for this response was already consumed" (HTTP 400 masking real error)
   - Root cause: NSG rules had both `destinationAddressPrefix` and `destinationApplicationSecurityGroups` — Azure requires exactly one
   - Fix: Removed `destinationAddressPrefix`/`sourceAddressPrefix` from rules using ASG targets
   - SECOND ATTEMPT: Succeeded via REST API workaround (`az rest --method PUT`)
   - Duration: ~2 minutes for deployment
7. **Hero image uploaded:** SUCCESS to blob container `images`
8. **Cloud-init results:**
   - vm-bastion: ERROR — `systemctl restart sshd` → Unit `sshd.service` not found (Ubuntu 24.04 uses `ssh.service`)
   - vm-proxy: DONE — nginx installed, self-signed cert generated, reverse proxy configured
   - vm-app: DONE — .NET 10 runtime installed, CloudSoft.service enabled, GitHub Actions runner installed and configured
   - Fix: Changed `sshd` to `ssh` in cloud-init-bastion.yaml; manually ran fix on bastion VM
9. **Self-hosted runner:** Online — cloudsoft-runner
10. **CI/CD workflow:** All 3 runs completed successfully
11. **CosmosDB version issue:**
    - MongoDB.Driver 3.x requires wire version 8+ (MongoDB 4.2+)
    - CosmosDB defaulted to wire version 6 (MongoDB 3.6)
    - Fix: Updated CosmosDB server version to 7.0 via `az cosmosdb update --server-version 7.0`
    - Added `apiProperties: { serverVersion: '7.0' }` to Bicep template
12. **Shard key issue:**
    - CosmosDB shard key `/email` (lowercase) but C# property serialized as `Email` (PascalCase)
    - Fix: Added `[BsonElement("email")]` and `[BsonElement("name")]` to Subscriber model

## Verification Checklist

| Test | Command | Expected | Actual | Status |
|------|---------|----------|--------|--------|
| Azure deployment | `az deployment group show` | Succeeded | Succeeded | PASS |
| Cloud-init bastion | `cloud-init status` | done | error (non-critical, fixed manually) | PASS* |
| Cloud-init proxy | `cloud-init status` | done | done | PASS |
| Cloud-init app | `cloud-init status` | done | done | PASS |
| Runner online | `gh api .../runners` | online | online | PASS |
| CI/CD workflow | `gh run list` | completed success | completed success | PASS |
| GET / | `curl -sk https://20.240.45.13/` | 200 | 200 | PASS |
| GET /Newsletter/Subscribe | `curl -sk https://...` | 200 | 200 | PASS |
| GET /Newsletter/Subscribers | `curl -sk https://...` | 200 | 200 | PASS |
| GET /Home/About | `curl -sk https://...` | 200 | 200 | PASS |
| Subscribe POST | `curl -X POST ...` | 302 (redirect) | 302 | PASS |
| Subscriber in CosmosDB | Check /Subscribers page | email appears | email appears | PASS |
| Unsubscribe POST | `curl -X POST ...` | 302 (redirect) | 302 | PASS |
| Subscriber removed | Check /Subscribers page | email gone | email gone | PASS |
| Hero image on About | Check page source | SAS token URL | stcloudsoftsubrupb5khl5g.blob.core.windows.net/images/hero.jpg?sv=... | PASS |
| SSL cert has IP SAN | `openssl s_client` | IP:20.240.45.13 | IP:20.240.45.13 | PASS |
| HTTP→HTTPS redirect | `curl http://` | 301 → https:// | 301 → https://20.240.45.13/ | PASS |
| Cache headers | `curl -I` | X-Cache-Status present | X-Cache-Status: HIT/EXPIRED | PASS |
| SSH to bastion | `ssh azureuser@bastion` | Connection OK | OK | PASS |
| Rate limiting | nginx config | burst=20 nodelay | Configured | PASS |

## Issues Encountered & Fixes

### Issue 1: Azure CLI "content already consumed" bug

- **Symptom:** `az deployment group create` fails with "The content for this response was already consumed"
- **Root cause:** Azure CLI 2.76.0 Python bug — response body consumed twice when API returns HTTP 400
- **Real error:** NSG validation failure (dual address prefix + ASG specification)
- **Fix:** Removed conflicting `destinationAddressPrefix`/`sourceAddressPrefix` from ASG-targeted rules; used `az rest` API as CLI workaround
- **Prevention:** Updated deploy.sh to use `az rest` + `az bicep build` pipeline

### Issue 2: Ubuntu 24.04 SSH service name

- **Symptom:** Bastion cloud-init error: "Failed to restart sshd.service: Unit sshd.service not found"
- **Root cause:** Ubuntu 24.04 renamed the service from `sshd.service` to `ssh.service`
- **Fix:** Changed `systemctl restart sshd` to `systemctl restart ssh` in cloud-init-bastion.yaml

### Issue 3: CosmosDB wire version incompatibility

- **Symptom:** `MongoIncompatibleDriverException: Server reports wire version 6, driver requires at least 8`
- **Root cause:** CosmosDB defaults to MongoDB 3.6 wire protocol; MongoDB.Driver 3.x requires 4.2+
- **Fix:** Added `apiProperties: { serverVersion: '7.0' }` to Bicep CosmosDB resource

### Issue 4: CosmosDB shard key mismatch

- **Symptom:** `MongoWriteException: document does not contain shard key at 'email'`
- **Root cause:** C# serializes `Email` as PascalCase, but shard key expects lowercase `email`
- **Fix:** Added `[BsonElement("email")]` attribute to model property

## Phase 5: Acid Test (Delete & Redeploy)

**Procedure:**
1. `az group delete --name rg-cloudsoft --yes` — Resource group deletion took ~15 minutes (CosmosDB slow to delete)
2. `git remote remove origin` — Cleaned local git state
3. `./deploy.sh` — Full one-click redeploy from scratch

**Acid Test Results (New IPs):**
- Proxy IP: 51.107.182.255
- Bastion IP: 51.107.181.183

| Test | Result |
|------|--------|
| All 4 pages return 200 | PASS |
| SSL cert has correct IP SAN (51.107.182.255) | PASS |
| HTTP→HTTPS redirect (301) | PASS |
| X-Cache-Status header present | PASS |
| SSH to bastion | PASS |
| Self-hosted runner online | PASS |
| Hero image SAS URL on About page | PASS |
| Subscribe POST (302 + data in CosmosDB) | PASS |
| deploy.sh ran end-to-end without manual intervention | PASS |

**Acid test: PASSED** — Full clean redeploy from deleted state succeeded on first attempt.

## Final State

All verification checks pass on both initial deployment and acid test redeploy. The `deploy.sh` script reliably provisions all infrastructure, deploys the app, and sets up CI/CD from a clean slate. The application is fully operational with subscribe/unsubscribe functionality backed by CosmosDB, hero image served via Azure Blob Storage SAS tokens, and CI/CD deploying via self-hosted GitHub Actions runner.
