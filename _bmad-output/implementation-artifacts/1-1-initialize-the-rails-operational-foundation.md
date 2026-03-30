# Story 1.1: Initialize the Rails Operational Foundation

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want the lending system initialized with the approved secure application foundation,
so that I can use a stable, production-shaped internal workspace for lending operations.

## Acceptance Criteria

1. **Given** the project is starting from an empty implementation state  
   **When** the application is initialized  
   **Then** it uses `rails new lending_rails --database=postgresql --css=tailwind`  
   **And** the baseline project includes the approved foundational libraries and developer setup needed for authentication, authorization, UI, testing, auditability, and money-safe implementation

2. **Given** the application foundation is created  
   **When** a developer inspects the project baseline  
   **Then** the app is configured as a Rails monolith with PostgreSQL, Tailwind, Docker readiness, and HTML-first navigation  
   **And** UUID-based entity identity, RSpec, and the agreed architectural baseline are ready for future stories

3. **Given** the baseline foundation is prepared for team development  
   **When** a developer reviews the delivery setup  
   **Then** the project includes a repeatable CI path that runs the core test and quality checks  
   **And** the generated Docker and deployment-ready artifacts remain usable without extra bootstrap rework

4. **Given** the baseline app is running  
   **When** a user visits the root application shell  
   **Then** they see a working internal application frame rather than a broken or placeholder-only setup  
   **And** the foundation supports future authentication and dashboard stories without rework

## Tasks / Subtasks

- [x] Bootstrap the Rails application with the approved starter command (AC: 1, 2)
  - [x] Run `rails new lending_rails --database=postgresql --css=tailwind`
  - [x] Keep the generated Docker-ready and deployment-ready baseline artifacts (`Dockerfile`, `compose.yaml`, `bin/dev`, `config/deploy.yml`, related config files) unless a concrete incompatibility appears
  - [x] Confirm the application remains an HTML-first Rails monolith and do not introduce API-first or SPA-only scaffolding

- [x] Add the approved foundational stack and baseline configuration (AC: 1, 2)
  - [x] Add the required gems: `rspec-rails`, `pundit`, `paper_trail`, `phonelib`, `money-rails`, `double_entry`, `aasm`, and `shadcn-rails`
  - [x] Add the approved platform/operations gems and baseline wiring: `solid_queue`, `solid_cache`, and `mission_control-jobs`
  - [x] Add the recommended supporting quality/setup gems that materially reduce rework for upcoming stories: `factory_bot_rails`, `shoulda-matchers`, `rubocop-rails-omakase`, `brakeman`, and `strong_migrations`
  - [x] Add Rails built-in authentication baseline using the Rails 8 authentication generator or equivalent Rails-native setup, but keep Story 1.2 responsible for the seeded admin account and Story 1.3 responsible for the polished login flow
  - [x] Configure UUID-forward defaults for future domain entities, including Rails generator defaults for UUID primary keys and PostgreSQL support for UUID generation
  - [x] Install and minimally wire `Pundit`, `shadcn-rails`, rate limiting, structured logging, and any required initializers without prematurely building borrower/application/loan business logic

- [x] Establish the architectural baseline structure expected by later stories (AC: 1, 2, 4)
  - [x] Create the base directories and minimal scaffolding for `app/services`, `app/queries`, `app/policies`, and `app/components`
  - [x] Keep controllers thin, with business logic deferred to future domain services rather than embedded in controllers, components, Stimulus controllers, or jobs
  - [x] Preserve server-driven state as the default; use Turbo/Stimulus only if needed for local browser behavior
  - [x] Add a minimal internal application shell at the root route that replaces the default Rails placeholder and clearly establishes the product frame without pretending the dashboard is complete

- [x] Provide a repeatable developer and CI workflow (AC: 3)
  - [x] Add a GitHub Actions workflow that installs dependencies and runs the core baseline checks
  - [x] Ensure the baseline checks include `bundle exec rspec`, `bundle exec rubocop`, and `bundle exec brakeman`
  - [x] Ensure database setup for CI uses standard Rails preparation commands and remains compatible with PostgreSQL

- [x] Verify the foundation behaves as a usable baseline (AC: 2, 3, 4)
  - [x] Add baseline specs that prove the app boots, the root shell renders successfully, and the test stack is wired correctly
  - [x] Verify the generated authentication baseline, if added in this story, is not left in a broken half-installed state
  - [x] Verify the app still supports the future login-to-dashboard flow rather than locking Story 1.2-1.4 into a wrong direction

## Dev Notes

### Story Intent

This is a greenfield bootstrap exception. It is allowed to be setup-heavy because the planning artifacts explicitly designate Story `1.1` as the one story that establishes the approved Rails foundation. Do not let that exception justify extra non-user-value setup work in later stories.

### Scope Boundaries

- Deliver the foundation, not the full auth experience. Story `1.2` owns the seeded admin account and protected access rules. Story `1.3` owns the focused login UX. Story `1.4` owns authenticated workspace entry and logout behavior.
- The root route in this story should be a working internal application shell, not a finished operational dashboard.
- Do not introduce borrower, application, loan, repayment, or audit domain workflows in this story beyond the minimum structural baseline needed to support future work.
- Do not switch to a React SPA, API-first architecture, Vite-based stack, Sidekiq, Redis-first background processing, or any alternative starter template.

### Developer Guardrails

- Reuse the official Rails starter and Rails-native generators where they fit. Do not hand-roll functionality already supplied by Rails 8 or by the approved libraries.
- Keep the application server-rendered and HTML-first. Turbo/Stimulus are helpers for navigation and local interaction, not replacements for server truth.
- Keep money-critical logic out of controllers, views, components, Stimulus controllers, and jobs from the start. This story should establish the folder boundaries that future stories will use.
- Treat UUID identity, auditability, safe migrations, and future locked-record rules as baseline architecture decisions that must be enabled now rather than retrofitted later.

### Technical Requirements

- The baseline must start from `rails new lending_rails --database=postgresql --css=tailwind`.
- The project must remain a Rails monolith with PostgreSQL, Tailwind, Docker readiness, and HTML-first navigation.
- The initial gem baseline must include `rspec-rails`, `pundit`, `paper_trail`, `phonelib`, `money-rails`, `double_entry`, `aasm`, and `shadcn-rails`.
- The baseline operations stack must include `Solid Queue`, `Solid Cache`, and `Mission Control Jobs`, with Docker-first and Kamal-ready defaults preserved.
- CI must be present from the start and must run the core quality checks, not only install dependencies.
- Future domain entities must default to UUID primary keys and UUID foreign keys.
- Authentication must stay Rails-native (`has_secure_password` / Rails authentication generator plus session cookies). Do not introduce Devise or another auth framework.
- Baseline security and operations wiring should preserve the architecture direction for Rails rate limiting, structured logs, and future audit/auth event coverage.

### Architecture Compliance

- Controllers: HTTP orchestration only.
- Services: future domain actions, workflow transitions, and money-safe logic.
- Queries: future dashboard/list/investigation read models.
- Policies: `Pundit` authorization layer.
- Components: reusable `ViewComponent`/`shadcn-rails` UI primitives and shared operational components.
- Jobs: delegate to services instead of owning business logic.
- State: server is source of truth; no client-side global state library.

### File Structure Requirements

Target the architecture-aligned layout from the start:

- `app/controllers` for thin Rails controllers only
- `app/models` for persistence and simple invariants
- `app/services` for domain actions
- `app/queries` for read models
- `app/policies` for `Pundit`
- `app/components` for reusable UI primitives
- `app/jobs` for asynchronous work that delegates to services
- `config/initializers` for baseline wiring such as `pundit`, `shadcn_rails`, `active_record_encryption`, `rate_limiting`, and audit-related setup as needed by the chosen libraries
- `.github/workflows/ci.yml` for baseline CI

Do not bury reusable workflow UI in ad hoc partials if the architecture expects a component boundary.

### Root Shell Expectations

The app shell should:

- Replace the default Rails welcome page
- Show the product name `lending_rails` and a credible internal-tool frame
- Feel calm, restrained, and desktop-first
- Preserve room for later login and dashboard work without forcing re-layout
- Use semantic HTML and accessible structure from the start

The app shell should not:

- Fake a finished dashboard with invented data
- Introduce final entity navigation that later stories will need to undo
- Depend on unsupported mobile/tablet layouts

### Testing Requirements

- Use `RSpec` as the primary test framework.
- Add enough baseline specs to prove the app boots and the root shell renders successfully.
- Wire `factory_bot_rails` and `shoulda-matchers` if they are added now so later stories do not need to revisit test setup.
- Add CI coverage for `rspec`, `rubocop`, and `brakeman`.
- Keep tests aligned with architecture boundaries so future services, queries, policies, and components have obvious homes.

### Previous Story Intelligence

None. This is the first story in the first epic, so there is no prior implementation to learn from yet.

### Git Intelligence Summary

Not available. The current workspace is not a git repository, so there is no commit history to mine for conventions.

### Latest Technical Information

- Rails 8 is the current stable Rails line and includes a built-in authentication generator. Prefer the Rails-native authentication path over third-party auth gems for this MVP baseline.
- `rspec-rails` `8.0.4` is a current stable release compatible with Rails 8-era projects. Use the latest compatible release available at implementation time instead of inventing a pinned version.
- `shadcn-rails` `0.2.1` is the latest publicly visible release found during story preparation. It is intended as a post-initialization component layer on top of Tailwind and Rails, not as a replacement starter template.
- Architecture-verified versions to preserve compatibility expectations include `turbo-rails` `2.0.23`, `ViewComponent` `4.5.0`, `Solid Queue` `1.4.0`, `Solid Cache` `1.0.10`, `Mission Control Jobs` `1.1.0`, and Kamal `2.11.0`.
- Where the package manager can resolve the current compatible version safely, prefer that over manually guessing older pins.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 1, Story 1.1, additional requirements, UX requirements
- `/_bmad-output/planning-artifacts/prd.md` - Executive Summary, Domain-Specific Requirements, Web Application Specific Requirements, Access & Session Control FRs, NFRs
- `/_bmad-output/planning-artifacts/architecture.md` - Selected Starter, Core Architectural Decisions, Implementation Patterns & Consistency Rules, Project Structure & Boundaries, Recommended Gems Stack, Implementation Handoff
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - Executive Summary, Design System Foundation, Login to Dashboard Landing, Component Strategy, UX Consistency Patterns, Accessibility Strategy
- `/_bmad-output/planning-artifacts/implementation-readiness-report-2026-03-30.md` - note that Story `1.1` is the permitted greenfield bootstrap exception

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-03-30T22:57:43+05:30
- Rails 8.1.2 baseline bootstrapped on 2026-03-31 using the official starter against the existing `lending_rails` directory from the parent path to preserve the required app name and existing BMAD artifacts.
- Approved foundational gems, Rails-native authentication, Pundit, PaperTrail, money/accounting initializers, shadcn-rails, UUID-first migrations, root shell, and CI wiring were implemented on 2026-03-31.
- Docker-backed PostgreSQL validation completed on 2026-03-31 after aligning `config/database.yml`, `compose.yaml`, `.env.example`, and `Procfile.dev` for the local development flow.

### Implementation Plan

- Preserve the official Rails monolith baseline (`PostgreSQL`, `Tailwind`, Docker/Kamal, Turbo/Stimulus, Solid adapters) and layer in only the story-approved libraries and initializers.
- Establish UUID-forward defaults, Rails-native authentication baseline, thin-controller architecture folders, and a minimal internal root shell without jumping ahead to later borrower/application/loan workflows.
- Validate the foundation with `RSpec`, `RuboCop`, `Brakeman`, and a GitHub Actions workflow that uses standard Rails database preparation.

### Completion Notes List

- Story context assembled from epics, PRD, architecture, UX, readiness report, and current live package/version research.
- No prior story file, project-context document, or git history was available.
- The project now boots as a Rails monolith with PostgreSQL/Tailwind defaults, Rails-native auth screens, UUID-forward generator defaults, baseline service/query/component directories, Mission Control Jobs mount, and a calm internal shell at the root route.
- Validation succeeded with `bin/setup --skip-server`, `bundle exec rspec`, `bundle exec rubocop`, `bundle exec brakeman --no-pager`, `bin/rails zeitwerk:check`, route verification, and a live `curl -I http://127.0.0.1:3000` check against the running dev server.
- `Procfile.dev` was updated to use `bin/rails tailwindcss:watch[always]` so `bin/dev` stays alive under Foreman instead of shutting down when the Tailwind watcher loses TTY semantics.

### File List

- `_bmad-output/implementation-artifacts/1-1-initialize-the-rails-operational-foundation.md`
- `.env.example`
- `.github/workflows/ci.yml`
- `.gitignore`
- `Gemfile`
- `Procfile.dev`
- `README.md`
- `app/components/application_component.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/home_controller.rb`
- `app/models/user.rb`
- `app/queries/application_query.rb`
- `app/services/application_service.rb`
- `app/views/home/index.html.erb`
- `app/views/layouts/application.html.erb`
- `compose.yaml`
- `config/application.rb`
- `config/ci.rb`
- `config/database.yml`
- `config/initializers/double_entry.rb`
- `config/initializers/mission_control_jobs.rb`
- `config/initializers/money.rb`
- `config/initializers/paper_trail.rb`
- `config/routes.rb`
- `db/migrate/20260330173537_create_users.rb`
- `db/migrate/20260330173538_create_sessions.rb`
- `db/migrate/20260330173541_create_versions.rb`
- `db/migrate/20260330173544_create_double_entry_tables.rb`
- `spec/factories/users.rb`
- `spec/models/user_spec.rb`
- `spec/rails_helper.rb`
- `spec/requests/health_check_spec.rb`
- `spec/requests/root_shell_spec.rb`

### Change Log

- 2026-03-31: Bootstrapped the Rails foundation, added the approved gem stack and initializers, created the root application shell and architecture scaffolding, and updated CI/test wiring.
- 2026-03-31: Completed Docker-backed local validation, documented the local setup flow, aligned `database.yml` with the Docker Postgres defaults, and fixed `bin/dev` to keep the Tailwind watcher alive under Foreman.

### Review Findings

- [x] [Review][Patch] Lock down Mission Control Jobs with explicit admin-only session authorization [app/controllers/mission_control_access_controller.rb:1]
- [x] [Review][Patch] Restore password reset token support required by the Rails-native auth flow [app/models/user.rb:1]
- [x] [Review][Patch] Add a Pundit user bridge so future `authorize` calls do not fail on missing `current_user` [app/controllers/application_controller.rb:1]
- [x] [Review][Patch] Add request coverage for the generated auth flow so CI catches half-installed auth wiring [spec/requests/passwords_spec.rb:1]
