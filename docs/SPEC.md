# Deployment specification

## Scope and document ownership

Subproject ID: **DEPLOY**. This top-level specification covers deployment
after the **BACKEND** and **FRONTEND** subprojects are completed. It does not
replace their requirements or grant approval to implement or deploy them.

| Subproject | Specification | Roadmap | Tasks |
| --- | --- | --- | --- |
| BACKEND | [Backend SPEC](backend/SPEC.md) | [Backend ROADMAP](backend/ROADMAP.md) | [Backend TASKS](backend/TASKS.md) |
| FRONTEND | [Frontend SPEC](frontend/SPEC.md) | [Frontend ROADMAP](frontend/ROADMAP.md) | [Frontend TASKS](frontend/TASKS.md) |
| DEPLOY | This document | [Deployment ROADMAP](ROADMAP.md) | [Deployment TASKS](TASKS.md) |

The accepted shared timeline design is
[Book event timeline layout](BOOKEVENT_TIMELINE_LAYOUT_PLAN.md). It replaces
the former proportional-gap and pixels-per-day slider design. Backend API
requirements are canonical in the backend SPEC; rendering requirements are
canonical in the frontend SPEC.

## DEPLOY requirements

- **DEPLOY-1:** Provide staging and production for both apps. The existing
  target is one Vercel project per app: native Next.js frontend and a Rails
  container-image function, subject to confirming current platform support.
- **DEPLOY-2:** Production deploys from `main`; staging uses Vercel Preview.
  Environment variables and Neon database branches are isolated by
  environment. Staging branch and stable preview alias remain undecided.
- **DEPLOY-3:** Rails runtime uses the pooled `DATABASE_URL`; migrations use
  the unpooled connection. Migrations run separately from application boot
  through GitHub Actions for the matching production or staging branch.
  Schema changes must remain compatible with the previously deployed app
  because migration and deployment are not atomic.
- **DEPLOY-4:** Staging loads idempotent repository seed data. Production
  data is entered through the authenticated book API. Bulk import and
  production review creation are out of scope.
- **DEPLOY-5:** Keep credentials and local environment files out of version
  control. Scope database URLs, Rails secrets, admin credentials, frontend
  origin, and frontend API configuration separately to Preview and Production.
- **DEPLOY-6:** Verify login rate limiting before production. Resolve
  backend/frontend readiness findings before publishing either environment.

## Environment baseline: observed versus proposed

Observed repository configuration:

- [Backend Gemfile](../backend/Gemfile) includes production `pg`, local/test
  `sqlite3`, and Solid Cache; Solid Queue and Solid Cable have been removed.
- [Database configuration](../backend/config/database.yml) uses one production
  Postgres database, `prepared_statements: false`, `advisory_locks: false`,
  and `idle_timeout: 60`. Solid Cache uses that primary database.
- [Generated Dockerfile](../backend/Dockerfile) is not the proposed Vercel
  image. Both apps currently have scaffold code, not the completed product.
- Runtime and framework baselines belong to the child specifications.
  Historical validation is preserved in their TASKS documents.

Proposed, not provisioned or verified by this document:

- `backend/Dockerfile.vercel` with `libpq5`, Puma listening on `$PORT`,
  no Thruster, and no migration on boot; corresponding Vercel configuration.
- Rails Vercel project rooted at `backend/`; Next.js project rooted at
  `frontend/`; Neon Marketplace integration connected to Rails.
- Environment variables: `DATABASE_URL`, `DATABASE_URL_UNPOOLED`,
  `RAILS_MASTER_KEY`, `RAILS_MAX_THREADS`, `FRONTEND_ORIGIN`,
  `ADMIN_USERNAME`, `ADMIN_PASSWORD`, and the frontend API base URL.
  Integration-provided names and the need for each variable must be confirmed.
- Migration workflow on production/staging pushes, with seeds only for staging.

No evidence of live Vercel projects, Neon branches, or deployed environments
is inferred from configuration or historical local Postgres checks.

## Acceptance criteria

- Both child subprojects have completed their independent four-stage
  lifecycles and passed required local and end-to-end checks.
- The Rails deployment image boots locally with `PORT` and a disposable
  Postgres `DATABASE_URL`; `/up` returns HTTP 200.
- Staging and production deployments succeed. Each frontend renders records
  from its matching API/database environment, with no cross-environment access.
- Migration workflows succeed and `db:migrate:status` shows migrations up
  in each environment; staging seed loading is idempotent.
- Deployment, migration, configuration, verification, update, and rollback
  procedures are documented, and relevant logs show no genuine failures.
- No provisioning, deployment, commit, push, or publication occurs without
  explicit authorization.

## Open decisions and risks

- Confirm current Vercel Rails/container support and configuration schema.
- Confirm Neon integration variables, pooled/unpooled behavior, and secret
  delivery to migration workflows.
- Choose the staging branch, stable frontend/API aliases, and CORS origins.
- Resolve browser-direct versus Next.js-proxied API access with both children.
- Define deployment rollback and migration failure recovery before execution.
- Revalidate historical dependency findings during final readiness.

## Approved changes

- 2026-10-24: Split backend and frontend planning into child document sets;
  reserve the existing top-level documents for DEPLOY after both complete.
- 2026-10-24: Adopt the shared timeline layout plan instead of the former
  proportional-gap/slider design. This does not approve a lifecycle transition.

## Learning resources

- [Vercel Rails guide](https://vercel.com/kb/guide/does-vercel-support-ruby-on-rails-applications)
- [Vercel container images](https://vercel.com/docs/functions/container-images)
- [Neon documentation](https://neon.com/docs)
