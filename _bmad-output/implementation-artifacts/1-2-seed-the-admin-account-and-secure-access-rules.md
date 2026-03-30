# Story 1.2: Seed the Admin Account and Secure Access Rules

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want a secure seeded admin account and protected access rules,
so that only authorized internal users can enter the lending workspace.

## Acceptance Criteria

1. **Given** the application has been initialized  
   **When** the system is set up for MVP access  
   **Then** it provides a seeded admin account for internal use  
   **And** there is no in-app user-management workflow exposed in MVP

2. **Given** the seeded admin account exists  
   **When** account credentials are stored and verified  
   **Then** passwords are handled securely and never stored in plain text  
   **And** the authentication design uses secure server-managed sessions

3. **Given** an unauthenticated visitor accesses a protected page  
   **When** they attempt to open the lending workspace  
   **Then** the system blocks access  
   **And** redirects them to the login flow

## Tasks / Subtasks

- [x] Add an idempotent seeded admin account flow (AC: 1, 2)
  - [x] Implement `db/seeds.rb` so it creates or updates the MVP admin user idempotently instead of leaving seed data empty
  - [x] Source the seeded admin identity and initial secret from environment variables or Rails credentials rather than committing plaintext credentials to the repository
  - [x] Reuse the existing `User` model, email normalization, and `has_secure_password` flow so password hashing stays Rails-native and secure
  - [x] Ensure the seed path does not create duplicate admin records when `db:seed` or `db:setup` is re-run

- [x] Enforce admin-only access at the server boundary (AC: 2, 3)
  - [x] Tighten sign-in so a persisted but non-authorized user cannot create or retain an authenticated session for the protected workspace
  - [x] Reuse the existing admin allowlist concept in `User#admin?` as the single source of truth for who may enter the MVP workspace
  - [x] Keep unauthenticated requests redirected to `new_session_path` through the existing Rails-native authentication concern
  - [x] Ensure protected app pages and the mounted Mission Control Jobs UI both require an authorized admin user, not merely any authenticated user

- [x] Preserve MVP scope boundaries for access control (AC: 1, 2, 3)
  - [x] Do not add registration, invitation, profile-editing, or in-app user-management screens
  - [x] Do not replace the Rails-native authentication generator output with Devise or another auth framework
  - [x] Keep the login UX intentionally simple here; Story `1.3` owns the refined login experience and Story `1.4` owns the authenticated workspace landing and logout flow

- [x] Add focused test coverage for the admin boundary (AC: 1, 2, 3)
  - [x] Add request coverage proving unauthenticated visitors are redirected away from protected pages
  - [x] Add request coverage proving a valid non-admin user cannot sign in to or retain access to the protected workspace
  - [x] Add coverage for the seeded admin path or its extracted helper/service so the seed remains idempotent and secure
  - [x] Keep or extend Mission Control Jobs access coverage so admin-only protection remains enforced

## Dev Notes

### Story Intent

Story `1.1` installed the Rails-native authentication baseline, but the workspace is not yet restricted to a seeded MVP admin. This story turns that baseline into the actual single-admin access boundary required by `FR1`, `FR2`, `FR77`, and the Epic 1 access-control intent without prematurely building the polished login or dashboard flows owned by Stories `1.3` and `1.4`.

### Current Codebase Signals

- `db/seeds.rb` is still the default placeholder and does not create the required admin account.
- `User#admin?` already derives authorization from `ADMIN_EMAIL_ADDRESSES`, so there is an existing allowlist concept to reuse instead of inventing a second admin source.
- `SessionsController#create` currently authenticates any persisted user with valid credentials, which is broader than the MVP seeded-admin-only requirement.
- `ApplicationController` already includes the generated Rails authentication concern, so protected-page redirects for unauthenticated visitors already exist and should be preserved.
- `MissionControlAccessController` already requires `Current.user.admin?`, which provides a concrete pattern for admin-only access checks and should stay aligned with the broader workspace rule.

### Scope Boundaries

- Deliver seeded admin access and protected-entry rules, not the final polished sign-in experience.
- Keep the app in the current single-admin MVP model. Future multi-user or role expansion is out of scope here even though `Pundit` is already installed.
- Do not expose user CRUD, settings, invitations, or registration flows.
- Do not redesign the root shell into the final operational dashboard in this story.

### Developer Guardrails

- Reuse the Rails 8 authentication generator structure already present in the app: `User`, `Session`, `Current`, `Authentication`, `SessionsController`, and signed cookie-backed session resumption.
- Do not store committed plaintext credentials in source control, seed files, fixtures, or README examples. Configuration may name required environment variables, but real secrets must remain external.
- Keep access control server-enforced. Hiding links is not sufficient; non-admin users must be unable to enter protected pages even if they know the URLs.
- Prefer one shared admin authorization seam for protected workspace access rather than duplicating ad hoc checks across unrelated controllers.
- Keep controllers thin. If seed setup or admin admission logic becomes non-trivial, extract support code without moving business or security rules into views or JavaScript.

### Technical Requirements

- The seeded admin account must be created through an idempotent bootstrap path, most likely `db/seeds.rb`, so local setup and environment provisioning remain repeatable.
- Passwords must continue to be handled through `has_secure_password` and bcrypt-backed hashing. No custom password crypto or plaintext persistence is acceptable.
- Session handling must remain server-managed and Rails-native, using the existing `sessions` table plus signed cookie session identifiers.
- The admin allowlist should remain a single source of truth across seed creation and request admission. Reuse `ADMIN_EMAIL_ADDRESSES` or a tightly aligned equivalent rather than creating competing admin selectors.
- Unauthorized users must not be able to reach the protected workspace after authentication, and unauthenticated users must still be redirected to the login route.
- Mission Control Jobs must stay behind the same admin boundary already configured via `MissionControl::Jobs.base_controller_class`.

### Architecture Compliance

- `app/models/user.rb`: owns admin predicate, authentication helpers, and simple invariants only.
- `db/seeds.rb`: owns idempotent bootstrap data creation for the MVP admin account.
- `app/controllers` and `app/controllers/concerns`: own HTTP/session orchestration and shared access filters, not ad hoc business logic.
- `app/policies`: do not need broad new role logic yet unless a small future-safe policy hook is required by the chosen admission approach.
- `app/views`: should not implement security decisions.
- `spec/requests` and `spec/models` (or `spec/services` if extraction occurs): should verify the server-side access boundary and seed behavior.

### File Structure Requirements

Likely implementation touchpoints based on the current app state:

- `db/seeds.rb`
- `app/models/user.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/application_controller.rb` or `app/controllers/concerns/authentication.rb`
- `app/controllers/mission_control_access_controller.rb`
- `spec/requests/mission_control_jobs_access_spec.rb`
- new or updated request specs covering protected-page admission
- `.env.example`
- `README.md`

Do not introduce a parallel authentication stack, a separate admin engine, or a user-management area just to satisfy seeded access.

### Testing Requirements

- Use request specs as the primary proof for redirect and admission behavior.
- Cover the unhappy path where valid credentials belong to a non-admin user; that user must not be able to enter the protected workspace.
- Cover the happy path where the seeded admin can authenticate and retain access to protected pages.
- Cover seed idempotence so re-running `db:seed` does not create duplicate users or regress the admin bootstrap path.
- Keep existing password-reset and Mission Control Jobs request coverage passing; they are part of the current auth baseline established in Story `1.1`.

### Previous Story Intelligence

- Story `1.1` already installed the Rails-native authentication generator output, request throttling, `Pundit`, `PaperTrail`, and the root shell. Reuse that baseline instead of replacing it.
- A review finding from Story `1.1` already locked down Mission Control Jobs behind `MissionControlAccessController`, so this story should extend that same admin-only posture to the main workspace instead of creating a conflicting access rule.
- Another Story `1.1` review finding restored password reset token support on `User`, so this story must not break the generated password-reset flow while tightening workspace access.

### Git Intelligence Summary

Not available. The current workspace is not a git repository, so there is no commit history to mine for conventions.

### Latest Technical Information

- Rails 8's built-in `rails generate authentication` flow is intentionally convention-led: it creates `User`, `Session`, `Current`, controller scaffolding, and signed cookie plus database-backed session handling. Reuse that structure rather than swapping to a third-party auth library.
- The Rails-native authentication generator intentionally does not create self-service signup, which aligns well with this MVP's seeded-admin-only access model.
- `mission_control-jobs` `1.1.0` supports a custom `base_controller_class` for application-managed authentication. The current app already uses that path, so keeping admin-only access in the shared session boundary is a better fit than adding a second auth mechanism.
- Mission Control Jobs documentation still treats the UI as closed-by-default and suitable for explicit protection. Do not loosen that boundary while broadening the main workspace protections.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 1, Story 1.2, Epic 1 objectives, additional requirements, UX design requirements
- `/_bmad-output/planning-artifacts/prd.md` - Access & Session Control FRs, Record Integrity FR77, Security NFRs, Web Application Specific Requirements, Security Architecture Expectations
- `/_bmad-output/planning-artifacts/architecture.md` - Authentication & Security, API & Communication Patterns, Structure Patterns, Requirements-to-Structure Mapping, Implementation Handoff
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - Login to Dashboard Landing, Experience Principles, Feedback Patterns, Accessibility Strategy
- `/_bmad-output/implementation-artifacts/1-1-initialize-the-rails-operational-foundation.md` - Dev Notes, Review Findings, Completion Notes List, File List
- `app/models/user.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/concerns/authentication.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/mission_control_access_controller.rb`
- `db/seeds.rb`
- `README.md`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-03-31T00:02:46+05:30
- BMad init helper could not be used directly in this workspace because its Python runtime dependency `yaml` is missing; existing `_bmad` config artifacts were loaded directly instead
- No `project-context.md` file or git history was available during story preparation
- 2026-03-31T00:09:19+05:30: Implemented shared admin admission in `ApplicationController`, tightened `SessionsController#create`, and moved seed bootstrap logic into `AdminBootstrap`
- 2026-03-31T00:09:19+05:30: Fixed Mission Control redirect handling to use `main_app` route helpers so engine requests still land on `/session/new`
- 2026-03-31T00:09:19+05:30: Validation passed with `bundle exec rspec`, `bundle exec rubocop`, and `bundle exec brakeman --no-pager`

### Implementation Plan

- Add an idempotent admin seed path that uses externalized secrets, the existing `User` model, and the current `ADMIN_EMAIL_ADDRESSES` allowlist semantics.
- Tighten workspace admission so only seeded/authorized admin users can create or retain sessions for protected routes, while preserving the generated unauthenticated redirect flow.
- Add focused request and seed coverage so the single-admin boundary stays enforceable as later auth and dashboard stories build on top of it.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story context assembled from epics, PRD, architecture, UX, previous story learnings, current auth code, and targeted latest-tech research.
- Current implementation gap is clear: admin allowlisting exists, but seed creation is missing and session admission is still broader than MVP requirements.
- Added `AdminBootstrap` plus `db/seeds.rb` wiring so the first configured admin email is seeded idempotently using `ADMIN_PASSWORD` or Rails credentials instead of committed credentials.
- Protected the workspace and Mission Control behind the same shared admin boundary, rejected non-admin sign-in attempts, and cleared legacy non-admin sessions on protected requests.
- Added focused request and service coverage for unauthenticated redirects, non-admin rejection, admin admission, and idempotent admin bootstrap behavior; full validation passed.

### File List

- `_bmad-output/implementation-artifacts/1-2-seed-the-admin-account-and-secure-access-rules.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `.env.example`
- `README.md`
- `app/controllers/application_controller.rb`
- `app/controllers/concerns/authentication.rb`
- `app/controllers/home_controller.rb`
- `app/controllers/mission_control_access_controller.rb`
- `app/controllers/passwords_controller.rb`
- `app/controllers/sessions_controller.rb`
- `app/services/admin_bootstrap.rb`
- `db/seeds.rb`
- `spec/requests/mission_control_jobs_access_spec.rb`
- `spec/requests/root_shell_spec.rb`
- `spec/requests/workspace_access_spec.rb`
- `spec/services/admin_bootstrap_spec.rb`

### Change Log

- 2026-03-31: Added an idempotent seeded admin bootstrap path, tightened the Rails-native session boundary to admin-only workspace access, updated environment/documentation guidance, and added focused admin access coverage.

### Review Findings

- [x] [Review][Patch] Preserve password reset changes across future `db:seed` runs by treating the configured admin secret as bootstrap-only after the initial admin user exists [`app/services/admin_bootstrap.rb:9`]
- [x] [Review][Patch] Add password reset regression coverage for the admin-gated app boundary [`spec/requests/passwords_spec.rb:3`]
- [x] [Review][Defer] Case-insensitive email uniqueness is not enforced at the database layer [`db/schema.rb:66`] — deferred, pre-existing
