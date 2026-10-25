# Deployment tasks

## Current scope and approval

- Owning subproject: **DEPLOY**; [ROADMAP](ROADMAP.md), [SPEC](SPEC.md).
- Lifecycle: Stage 1 deferred. **Blocked** until BACKEND and FRONTEND complete
  their own four-stage lifecycles.
- Session authorization: documentation restructuring and adoption of the
  timeline layout only. No deployment implementation tasks selected.
- Backend work and historical database validation:
  [Backend TASKS](backend/TASKS.md).
- Frontend work and historical scaffold validation:
  [Frontend TASKS](frontend/TASKS.md).

## Deferred scope

Refine these outcomes into high-level tasks during approved DEPLOY Stage 2;
they are not an implementation queue or authorization:

- Verify Vercel/Neon support, environment mapping, staging branch/aliases,
  and secrets delivery (DEPLOY-1, DEPLOY-2, DEPLOY-5).
- Configure the Rails image, Vercel projects, and frontend API integration
  (DEPLOY-1, DEPLOY-2).
- Configure environment-specific migrations and staging seeds
  (DEPLOY-3, DEPLOY-4).
- Verify production login protection and child readiness findings (DEPLOY-6).
- Document and test deployment, updates, verification, and rollback
  (deployment SPEC acceptance).

## Validation plan and baseline

Selected future checks, not executed in this documentation session:

- From `backend/`: `docker build -f Dockerfile.vercel .` after that file
  exists; boot with `PORT` and a disposable Postgres database and check `/up`.
- Run the migration workflow for staging and production after authorization;
  check `db:migrate:status` and staging seed idempotence.
- Run each child's complete local gate plus real-browser end-to-end checks
  against matching environments. Inspect complete relevant deployment logs.
- Record exact commands, results, environment isolation, manual evidence,
  skipped checks, and rollback evidence when run.

No deployment integration harness or Stage 2 expected-red baseline exists.
Historical local Postgres success is not evidence of a Neon deployment.

## Commit and approval checkpoint

Do not begin DEPLOY while its child dependencies remain incomplete. After
each authorized, validated implementation unit, remind the user to commit and
stop before the next task unless continuation without committing is explicit.
Never stage, commit, push, provision, or deploy implicitly.

## Documentation restructuring record

- 2026-10-24: Split backend/frontend specifications, roadmaps, and tasks into
  child documents; retained top-level documents for deferred deployment.
- Accepted layout now replaces the former slider design. Historical
  foundation results are preserved in child TASKS; none were rerun here.
- Validation: `git diff --check` passed. An inline Python documentation check
  passed for all 11 changed/new documents and 69 local links, including
  subproject identifiers, deployment dependency, and removal of obsolete
  design claims. Review covered the document split and preserved foundation
  evidence; the pre-existing untracked layout plan was integrated, not removed.
- No application code, dependency manifests, schemas, or runtime behavior
  changed. Application/browser suites are skipped: documentation-only.
- Residual review: child SPEC open decisions must be resolved before Stage 2;
  the accepted layout direction is not a completed implementation design.
- No implementation task or lifecycle stage is marked complete by this edit.
