---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
inputDocuments:
  - /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/planning-artifacts/prd.md
  - /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/planning-artifacts/ux-design-specification.md
  - /Users/rajanavenkatasuryateja/nearform/spike/lending_rails/_bmad-output/planning-artifacts/research/domain-lending management platform-research-2026-03-30.md
documentCounts:
  productBriefs: 0
  prd: 1
  uxDesign: 1
  research: 1
  projectDocs: 0
  projectContext: 0
workflowType: 'architecture'
projectName: 'lending_rails'
author: 'RVS'
initializedAt: '2026-03-30 16:18:31 IST'
lastStep: 8
status: 'complete'
completedAt: '2026-03-30 17:36:19 IST'
workflowCompleted: true
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
The project defines 77 functional requirements spanning seven capability groups: access/session control, borrower management, application management and review, loan setup/documentation/disbursement, repayment tracking and portfolio control, dashboard/search/investigation, and record integrity/auditability.

Architecturally, these requirements indicate a workflow-centric system with tightly linked domain entities rather than a collection of independent CRUD modules. More precisely, this should be treated as a stateful financial workflow system with admin interfaces on top, not a generic admin panel. The core domain flow runs from borrower intake to application review, then to loan creation, documentation, disbursement, repayment tracking, overdue handling, and automatic closure. This creates strong dependencies between borrower, application, loan, payment, disbursement, and invoice records.

Several requirements imply system-controlled lifecycle orchestration rather than user-controlled state mutation. Application statuses, review-step statuses, loan lifecycle states, overdue conditions, and closure conditions all need to be derived and enforced consistently. The architecture will therefore need a canonical domain model and explicit state-transition rules as a primary foundation so that dashboards, detail views, and future reporting all resolve from the same truth.

The functional requirements also show meaningful cross-entity visibility needs. The dashboard, linked record investigation, borrower history, searchable operational lists, and auditability requirements all imply that record lineage and traceability are first-class product concerns, not secondary reporting features. The architecture should therefore account for operational read/query surfaces as first-class concerns alongside transactional write logic.

**Non-Functional Requirements:**
The non-functional requirements are modest in scale but strict in trust expectations. Core authenticated flows should complete within 2 seconds under expected MVP conditions. Security requirements are basic but important: authenticated-only access, secure password handling, protected transport, and basic session security for financial records.

Reliability requirements are more architecturally significant than the raw uptime target. Each page load must reflect the latest committed system state, and money-state transitions must remain internally consistent across approval, documentation, disbursement, repayment, overdue, and closure stages. Post-money records must remain locked after commitment. This reinforces that correctness and consistency are the primary non-functional drivers.

From an architectural quality perspective, testability is part of the requirement, not just a delivery concern. Repayment generation, overdue derivation, late fees, record locking, and closure logic should be implemented in deterministic, independently testable domain services rather than being distributed across UI logic or incidental persistence hooks.

Scalability requirements are intentionally narrow: the MVP is optimized for a single-admin internal operating model. There is no requirement for broad concurrency, multi-tenancy, realtime collaboration, or premature scale optimization. Data management constraints also explicitly exclude backup/recovery automation in MVP, which should be treated as an acknowledged operational risk rather than a solved concern.

From the UX specification, additional architecture-shaping constraints include desktop-first design, latest-Chrome-only support, desktop-only MVP scope, MPA-style navigation, no realtime requirements, no offline support, predictable page-load refresh behavior, and a minimum auditable WCAG 2.1 Level A accessibility target for core workflows.

**Scale & Complexity:**
This project is high complexity, not because of user volume or integrations, but because of domain correctness requirements and workflow breadth. The system spans multiple tightly coupled lifecycle stages with financial consequences, immutable historical records, derived statuses, and audit expectations.

The project should be treated as a full-stack internal web application with a moderate number of major architectural areas but high domain sensitivity inside the money-related paths.

- Primary domain: internal fintech lending operations web application
- Complexity level: high
- Estimated architectural components: 8-10 major logical components

### Technical Constraints & Dependencies

Known constraints and dependencies already established by the project context include:

- Internal authenticated admin-facing web application
- Desktop-first user experience
- Latest Chrome only for MVP
- MPA interaction model preferred over SPA complexity
- No realtime updates required in MVP
- No offline capability required
- No external integrations in MVP
- Seeded admin-only access, with no in-app user management
- Full-payment-only repayment handling in MVP
- Supported repayment frequencies limited to weekly, bi-weekly, and monthly
- Interest input allowed by rate or total interest amount, but not both
- Post-disbursement loan data must become non-editable
- Completed payment records must become non-editable
- Borrower data must be snapshotted onto applications and loans
- Reuploads must preserve historical document context instead of overwriting it
- No hard deletion of operational or financial records
- Audit trail required for key operational and financial actions
- Backup/recovery automation is out of scope for MVP and should be tracked as an explicit operational risk

### Cross-Cutting Concerns Identified

Several concerns will affect nearly every architectural decision in this project:

- Financial correctness and deterministic calculation logic for repayment schedules, overdue detection, late fees, totals, and closure conditions
- Workflow and lifecycle orchestration across application, documentation, disbursement, repayment, and closure stages
- Immutable history and record locking after money-significant events
- Auditability, including actor/time visibility for key actions
- Linked record lineage across borrowers, applications, loans, payments, disbursements, and invoices
- Searchability and operational investigation flows across all major record types
- Operational read/query surfaces for dashboard triage, filtered lists, and linked investigation
- Clear separation between pre-money editable states and post-money locked states
- Strong validation and blocked-state handling to prevent invalid progression
- Consistent page-load freshness and state derivation without realtime infrastructure
- Accessibility, clarity, and predictable interaction patterns for high-stakes admin workflows
- Testability of financial rules and state transitions as a core architectural quality attribute

## Starter Template Evaluation

### Primary Technology Domain

Full-stack Ruby on Rails monolith based on project requirements analysis.

This domain is the best fit because the product is an internal, desktop-first, workflow-heavy web application with no realtime requirement, no offline requirement, and a deliberate MPA/server-rendered interaction model. The preferred stack is Rails-first with PostgreSQL, Tailwind, Docker, and light Hotwire-style interactivity.

### Starter Options Considered

**1. Official Rails application generator**
This is the strongest fit for the current project direction.

What it aligns with:
- Ruby on Rails monolith architecture
- Server-rendered HTML with Hotwire-compatible patterns
- PostgreSQL support at project creation time
- Tailwind CSS setup at project creation time
- Docker support included by default in current Rails app generation unless explicitly skipped
- Minimal opinionation beyond standard Rails conventions

Why it fits:
- Matches the PRD and UX preference for an MPA-style internal system
- Avoids introducing unnecessary moving parts for MVP
- Preserves flexibility for domain-driven architecture decisions later
- Keeps authentication, auditability, workflow logic, and record locking inside one coherent application boundary

Trade-off:
- Does not include RSpec or a shadcn-style component layer out of the box, so those should be added immediately after initialization.

**2. Templatus Hotwire**
This is a maintained and modern Hotwire-oriented starter, but it is significantly more opinionated than this project currently needs.

What it includes:
- Hotwire-first setup
- Tailwind CSS
- PostgreSQL
- RSpec and richer testing support
- Additional choices such as TypeScript, ViewComponent, Vite, Redis, and Sidekiq

Why it was not selected:
- It bakes in more infrastructure and frontend tooling than the MVP requires
- It would make several architectural decisions prematurely
- It is a better fit for teams that already want a batteries-included Rails platform rather than a simpler monolith baseline

**3. shadcn/ui on Rails (`shadcn-rails`)**
This is not a full starter template, but it is the best fit for the stated `Tailwind + shadcn/ui` preference without switching the project to a React-based frontend.

What it provides:
- Rails-native component generation
- Tailwind-based component styling
- Hotwire/Stimulus-friendly approach
- A copy-into-your-app ownership model similar in spirit to original shadcn/ui

Why it matters:
- It resolves the mismatch between wanting Rails monolith + light Hotwire interactions and also wanting the shadcn design language
- It should be treated as a post-initialization component layer, not the base starter itself

### Selected Starter: Official Rails application generator

**Rationale for Selection:**
The official Rails starter is the best match for the product's architecture and the user's technical preferences. It supports a Rails monolith directly, keeps the stack simple, aligns with the PRD's MPA-style operational model, and avoids locking the MVP into infrastructure or tooling that is not yet justified.

It also leaves room to add only the specific layers the project wants:
- built-in Rails authentication using `has_secure_password`
- `RSpec` as the preferred unit/integration testing framework
- `shadcn-rails` for a Rails-native shadcn-style component system
- Hotwire/Stimulus only where interaction complexity actually requires it

This keeps the architectural baseline boring, stable, and well matched to a money-sensitive internal product.

**Initialization Command:**

```bash
rails new lending_rails --database=postgresql --css=tailwind
```

**Architectural Decisions Provided by Starter:**

**Language & Runtime:**
- Ruby on Rails monolith
- Conventional Rails server-rendered application structure
- Default Rails JavaScript approach, which is currently importmap-based unless changed later
- Strong fit for mostly server-rendered pages with selective Hotwire enhancements

**Styling Solution:**
- Tailwind CSS integrated at project creation time
- Good foundation for adding `shadcn-rails` components afterward
- Supports the UX direction without requiring a React frontend

**Build Tooling:**
- Standard Rails application tooling
- Docker artifacts included by default in current Rails app generation unless explicitly skipped
- Minimal frontend build complexity compared with Vite/Webpack-style starters

**Testing Framework:**
- Official Rails starter does not select `RSpec` by default
- This should be followed immediately by adding `RSpec` as an explicit project choice
- The starter therefore provides a clean base, while testing standardization remains a first implementation task

**Code Organization:**
- Conventional Rails monolith structure
- Clear fit for domain-driven organization around borrowers, applications, loans, payments, disbursements, invoices, and audit history
- Keeps domain logic, authentication, workflow orchestration, and operational query surfaces inside one application boundary

**Development Experience:**
- Standard Rails developer workflow
- Tailwind-ready local development flow
- Docker-ready baseline
- Easy path to add:
  - `bin/rails generate authentication` for Rails-native bcrypt-backed auth
  - `rspec-rails` for testing
  - `rails generate shadcn:install` after adding `shadcn-rails`

**Note:** Project initialization using this command should be the first implementation story. Immediately after initialization, the project should add `RSpec`, Rails built-in authentication, and `shadcn-rails` as explicit follow-up setup decisions.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- Rails monolith with PostgreSQL, Tailwind, Docker, and the official Rails starter
- Active Record for persistence plus explicit domain/service objects for money-critical logic and lifecycle transitions
- Rails-native authentication with `has_secure_password`, `Pundit` for authorization, and Rails session/cookie-based auth
- HTML-first RESTful Rails controllers with Turbo/Hotwire enhancements rather than an API-first architecture
- Frontend structured around `ViewComponent`, `Turbo`, `Stimulus`, `Tailwind`, and `shadcn-rails`
- Docker-first deployment shape, `GitHub Actions`, and Rails-native operational tooling (`Solid Cache`, `Solid Queue`, `Mission Control Jobs`)

**Important Decisions (Shape Architecture):**
- Database constraints for hard invariants and model/domain validations for workflow rules
- Query objects or scoped read services for dashboard, list, and investigation views
- `Solid Cache` as the default cache backend and `Solid Queue` as the default background-job backend
- Selective PII encryption with Rails Active Record Encryption
- Rails 8 built-in rate limiting for login/session/password flows
- Audit trail coverage for business-critical actions and key auth/security events
- Lean MVP ops posture with structured logs and deferred APM vendor selection

**Deferred Decisions (Post-MVP):**
- Final hosting provider selection
- Advanced monitoring/APM vendor choice
- Broader rate limiting beyond auth-sensitive and abuse-prone endpoints
- Expanded authorization roles beyond the seeded admin model
- Formal internal API documentation tooling unless a larger JSON surface emerges
- Advanced scaling patterns beyond simple web/job process separation

### Data Architecture

- **Database:** PostgreSQL as the primary relational database, with current stable family verified as PostgreSQL 18.x. Rails should target a modern supported PostgreSQL version available in the chosen environment.
- **Modeling approach:** Use Active Record models for persistence, associations, and basic invariants, while placing financial calculations, lifecycle transitions, and lock-state enforcement in explicit domain/service objects.
- **Domain logic boundaries:** Create dedicated service boundaries for repayment schedule generation, overdue derivation, disbursement completion, payment completion, and loan closure. Controllers and UI components must not mutate money-critical state directly.
- **Validation strategy:** Enforce hard invariants with database constraints and use model/domain validations for workflow rules and user-facing errors.
- **Read model strategy:** Use query objects or scoped read services for dashboard widgets, filtered lists, borrower history, and investigation flows to avoid mixing operational query logic into write-side domain services.
- **Migration strategy:** Use standard Rails migrations, but follow safe expand/migrate/contract patterns for risky schema changes and keep large data/backfill work separate from structural migrations.
- **Caching strategy:** Use `Solid Cache` as the default cache backend, but apply caching selectively to read-heavy views and derived operational summaries where stale data will not create workflow confusion. Money-sensitive views should prioritize correctness over cache aggressiveness.

### Authentication & Security

- **Authentication method:** Use Rails-native authentication with `has_secure_password` and session cookies as the default auth model for the internal monolith.
- **Authorization:** Use `Pundit` policies as the application authorization layer. Even though MVP begins with a seeded admin model, policy objects should be adopted now so future role expansion does not require structural rewrites.
- **PII protection:** Use Rails Active Record Encryption for selected PII fields in the database. Password hashing remains handled separately by `bcrypt` via `has_secure_password`.
- **Searchable encrypted fields:** Borrower lookup fields such as phone number require explicit design for searchability. Search-critical identifiers should use deterministic encryption or a separate normalized/indexed strategy instead of naive opaque encryption.
- **Rate limiting:** Use Rails 8 built-in `rate_limit` support for login, session, and password-related flows first, with room to extend to sensitive mutation endpoints later if needed.
- **Audit trail:** Maintain audit coverage for key operational and financial actions as well as key auth/security events such as successful login, failed login, and password reset actions.
- **Security enforcement boundary:** Authorization and audit checks should be enforced around domain actions and critical services, not only at controller entry points.

### API & Communication Patterns

- **Primary communication pattern:** HTML-first RESTful Rails controllers.
- **Response strategy:** Prefer standard HTML responses and server-rendered flows, using Turbo Frames and Turbo-driven partial updates where useful. JSON should be introduced only for narrow internal endpoints if a concrete need appears.
- **Routing approach:** Use resource-oriented Rails routing for borrowers, applications, loans, payments, invoices, and related workflow actions.
- **Service communication:** Keep business communication in-process inside the monolith through service/domain calls. No service mesh, external event bus, or separate internal API layer is required for MVP.
- **Error handling standard:** Keep controllers thin and delegate domain actions to services that return consistent result objects or explicit error contracts. HTML flows should surface errors through form messages, blocked-state explanations, and render/redirect outcomes; future JSON endpoints should reuse the same domain services and error semantics.
- **Documentation strategy:** Defer OpenAPI tooling such as `rswag` or schema-validation middleware such as `committee` unless the app develops a meaningful internal JSON API surface.

### Frontend Architecture

- **Component architecture:** Use `ViewComponent` as the reusable UI component and page-primitive layer. Current stable version verified: `4.5.0`.
- **Interaction model:** Use `Turbo` for navigation, frames, and selective server-driven updates. Current stable `turbo-rails` version verified: `2.0.23`.
- **Behavior layer:** Use `Stimulus` for local interactive behavior, guarded dialogs, and workflow-enhancing UI interactions. Stimulus controllers should remain focused on browser behavior, not business logic.
- **Design system foundation:** Use `Tailwind CSS` plus `shadcn-rails` as the design-system/component base. Verified `shadcn-rails` version seen in current sources: `0.2.1`.
- **State management:** Default to server-driven state. Do not introduce a client-side global state library. Local component state may exist inside Stimulus only where it reduces friction.
- **UI primitive strategy:** Establish a small reusable UI primitive set early, including status badges, shared table wrappers, filter bars, entity headers, guarded confirmation dialogs, and blocked-state callouts.
- **Boundary rule:** Money-critical actions must always round-trip through server-side domain services, even when initiated by a richer component interaction.

### Infrastructure & Deployment

- **Deployment shape:** Docker-first Rails monolith deployment.
- **Deployment readiness:** Keep the application `Kamal`-ready without committing to a final hosting provider yet. Current stable Kamal version verified: `2.11.0`.
- **CI/CD:** Use `GitHub Actions` for build, test, and image-oriented CI/CD workflows.
- **Configuration and secrets:** Use Rails credentials plus environment variables/secrets for deployment-specific configuration.
- **Background jobs:** Use `Solid Queue` as the default Active Job backend. Verified current stable version: `1.4.0`.
- **Cache backend:** Use `Solid Cache` as the default cache backend. Verified recent stable version: `1.0.10`.
- **Job operations:** Use `Mission Control Jobs` for Solid Queue visibility and troubleshooting. Verified current stable version seen in sources: `1.1.0`.
- **Observability baseline:** Start with structured Rails logs and defer vendor-specific APM/error-tracking selection until post-MVP or later operational validation.
- **Scaling strategy:** Assume a lean MVP operating posture with simple web/job process separation when needed. Avoid advanced autoscaling or distributed-systems assumptions at this stage.

### Decision Impact Analysis

**Implementation Sequence:**
1. Initialize the Rails application with PostgreSQL and Tailwind using the official starter.
2. Add `RSpec`, Rails built-in authentication, `Pundit`, and `shadcn-rails`.
3. Establish the base project structure for domain services, policies, query objects, components, and audit logging.
4. Implement core domain entities and database constraints for borrowers, applications, loans, payments, disbursements, invoices, and audit records.
5. Implement money-critical domain services and their tests before building the related UI workflows.
6. Build the shared frontend primitives and then compose page flows for dashboard, lists, detail views, and guarded actions.
7. Add `Solid Queue`, `Solid Cache`, and `Mission Control Jobs` operational wiring as part of the application baseline.
8. Add CI/CD and Docker deployment workflows, keeping the app Kamal-ready.

**Cross-Component Dependencies:**
- Domain services become the central seam between controllers, jobs, policies, audit logging, and future internal endpoints.
- Searchable encrypted PII requires coordination between data modeling, encryption choices, and borrower lookup flows.
- HTML-first communication and server-driven UI reinforce the decision to keep business logic out of Stimulus and inside services.
- `Solid Queue` and audit/event workflows interact with domain services for asynchronous tasks such as document processing, recurring checks, and operational side effects.
- The component architecture depends on having shared state/status semantics from the domain layer so statuses, lock states, and blocked states render consistently across the UI.

## Implementation Patterns & Consistency Rules

### Pattern Categories Defined

**Critical Conflict Points Identified:**
The main conflict risks for AI agents in this codebase are naming drift, misplaced business logic, inconsistent component boundaries, divergent error/result handling, inconsistent audit placement, and test location inconsistency.

### Naming Patterns

**Database Naming Conventions:**
- Use Rails-standard lowercase plural table names: `borrowers`, `loan_applications`, `loans`, `payments`, `disbursements`, `invoices`, `audit_logs`.
- Use `snake_case` for all columns: `phone_number`, `approved_amount`, `payment_due_date`.
- Use standard foreign keys in `snake_case`: `borrower_id`, `loan_application_id`, `loan_id`.
- Use Rails-standard timestamp fields: `created_at`, `updated_at`.
- Use Rails-standard index naming unless a custom name is necessary.
- Use enum/status values in lowercase `snake_case`: `in_progress`, `waiting_for_details`, `ready_for_disbursement`.

**API Naming Conventions:**
- Use plural REST resources: `/borrowers`, `/loan_applications`, `/loans`, `/payments`.
- Use Rails route parameters in standard form: `:id`.
- Use `snake_case` for params and query keys: `borrower_id`, `status`, `due_before`.
- Keep controller/action naming RESTful by default; use explicit member actions only for meaningful domain actions such as `disburse`, `approve`, or `mark_completed`.
- Prefer standard Rails headers and avoid custom headers unless there is a clear technical need.

**Code Naming Conventions:**
- Use Ruby class/module naming in `PascalCase`.
- Use file naming in `snake_case`.
- Use namespaced domain service names for business actions:
  - `Loans::Disburse`
  - `Payments::MarkCompleted`
  - `Applications::Approve`
  - `Loans::GenerateRepaymentSchedule`
- Use namespaced query names for read models:
  - `Dashboard::OverduePaymentsQuery`
  - `Borrowers::HistoryQuery`
- Use component names ending in `Component`:
  - `Loans::StatusBadgeComponent`
  - `Shared::FilterBarComponent`
- Use policy names in standard `Pundit` form:
  - `LoanPolicy`
  - `PaymentPolicy`

### Structure Patterns

**Project Organization:**
- `app/models`: persistence, associations, enums, simple invariants, encrypted attributes
- `app/services`: domain actions, calculators, workflow transitions, audit-aware application services
- `app/queries`: dashboard queries, filtered list queries, investigation/read-model queries
- `app/policies`: `Pundit` authorization policies
- `app/components`: `ViewComponent` primitives and workflow-significant components
- `app/controllers`: HTTP concerns only, thin orchestration layer
- `app/jobs`: background jobs that delegate to services
- `app/lib` or `lib`: only for cross-cutting framework-neutral support code if needed

**File Structure Patterns:**
- Mirror namespace to directory structure:
  - `app/services/loans/disburse.rb`
  - `app/services/payments/mark_completed.rb`
  - `app/queries/dashboard/overdue_payments_query.rb`
  - `app/components/loans/status_badge_component.rb`
- Keep reusable UI primitives under shared or domain namespaces rather than flat global files.
- Keep docs and architecture artifacts outside runtime code directories.
- Keep environment-specific settings in Rails conventions: credentials, environment configs, initializers.

### Format Patterns

**API Response Formats:**
- Primary application flow is HTML-first, so standard Rails render/redirect conventions apply.
- For any internal JSON endpoints introduced later:
  - use `snake_case` JSON keys
  - use ISO 8601 timestamps
  - prefer direct resource payloads for simple reads
  - use a consistent error envelope for failures:
    - `{ error: { code: "validation_error", message: "..." } }`
- Do not invent multiple JSON response shapes across endpoints.

**Data Exchange Formats:**
- Use `snake_case` for all Rails params, hashes, symbols, and JSON fields.
- Use ISO 8601 strings for serialized dates/times.
- Use true booleans, never `1/0` booleans in externalized data structures.
- Represent missing optional values as `nil`/`null`, not sentinel strings.
- Keep single resources as objects, collections as arrays.

### Communication Patterns

**Event System Patterns:**
- Internal domain events, if introduced, should use lowercase namespaced `snake_case` naming:
  - `loan.disbursed`
  - `payment.completed`
  - `application.approved`
- Event payloads should include:
  - entity identifier
  - event name
  - actor identifier if applicable
  - occurred-at timestamp
  - minimal relevant metadata
- Do not introduce a distributed event architecture for MVP; domain events are internal consistency tools only.

**State Management Patterns:**
- Server is the source of truth for state.
- `Stimulus` may manage only local interaction state such as dialog open/close, tabs, inline reveal/hide, or optimistic UX hints that do not redefine business truth.
- Do not place domain workflow state in JavaScript.
- Canonical statuses and state transitions come from the domain layer and must not be recreated independently in components.

### Process Patterns

**Error Handling Patterns:**
- Domain services should return one consistent result object pattern, not a mix of booleans, raw hashes, and ad hoc exceptions.
- Preferred service result semantics:
  - `success?`
  - `value` or returned entity/context
  - `error_code`
  - `message`
  - optional structured `details`
- Use exceptions only for truly exceptional or infrastructural failures, not normal business-rule failures.
- Controllers translate service results into:
  - redirects for successful mutations
  - re-rendered forms for validation failures
  - blocked-state or flash messaging for workflow/precondition failures
- User-facing messages should be clear, calm, and action-oriented.
- Logs and audit records should contain technical detail; user-facing messages should not.

**Loading State Patterns:**
- Default to full-page or frame-level server-driven loading behavior.
- Use Turbo-driven pending states and component-level loading indicators only where they improve clarity.
- Avoid bespoke loading state systems in JavaScript.
- For long-running actions, move work to jobs and show explicit queued/in-progress state from the server.

### Enforcement Guidelines

**All AI Agents MUST:**
- Keep money-critical workflow logic inside domain services, never in controllers, components, or jobs.
- Use canonical domain statuses and names exactly as defined by the product vocabulary.
- Mirror runtime structure in tests so every service, query, policy, and component has an obvious testing location.

**Pattern Enforcement:**
- Verify new code against directory responsibility rules before merge.
- Treat deviations from naming, result-object, or state-boundary patterns as architectural inconsistencies, not stylistic preferences.
- Update architecture rules intentionally in the architecture document before introducing new cross-cutting patterns.

### Pattern Examples

**Good Examples:**
- `Loans::Disburse` service performs authorization-aware disbursement orchestration and emits audit records.
- `Payments::MarkCompleted` service updates payment state and delegates any follow-up side effects consistently.
- `Dashboard::OverduePaymentsQuery` encapsulates the overdue-payment read model.
- `Loans::StatusBadgeComponent` renders a status using canonical domain vocabulary.
- `MarkPaymentCompletedJob` delegates to `Payments::MarkCompleted` instead of implementing business logic itself.

**Anti-Patterns:**
- Calculating repayment schedules inside a controller action.
- Reimplementing overdue logic inside a job or component.
- Using different status strings in UI than in domain enums.
- Putting reusable workflow UI inside ad hoc ERB partials with duplicated logic everywhere.
- Returning booleans from one service, hashes from another, and exceptions from a third for ordinary business failures.
- Encrypting searchable borrower identifiers without an explicit search strategy.

## Project Structure & Boundaries

### Complete Project Directory Structure
```text
lending_rails/
├── .dockerignore
├── .gitattributes
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
├── .gitignore
├── .kamal/
│   └── hooks/
├── .ruby-version
├── Dockerfile
├── Gemfile
├── Gemfile.lock
├── Procfile.dev
├── README.md
├── Rakefile
├── config.ru
├── compose.yaml
├── config/
│   ├── application.rb
│   ├── boot.rb
│   ├── cable.yml
│   ├── credentials.yml.enc
│   ├── database.yml
│   ├── deploy.yml
│   ├── environment.rb
│   ├── importmap.rb
│   ├── puma.rb
│   ├── queue.yml
│   ├── recurring.yml
│   ├── routes.rb
│   ├── storage.yml
│   ├── cache.yml
│   ├── locales/
│   │   └── en.yml
│   ├── environments/
│   │   ├── development.rb
│   │   ├── production.rb
│   │   └── test.rb
│   └── initializers/
│       ├── assets.rb
│       ├── content_security_policy.rb
│       ├── filter_parameter_logging.rb
│       ├── inflections.rb
│       ├── permissions_policy.rb
│       ├── pundit.rb
│       ├── shadcn_rails.rb
│       ├── active_record_encryption.rb
│       ├── audit_logging.rb
│       ├── rate_limiting.rb
│       └── mission_control_jobs.rb
├── db/
│   ├── seeds.rb
│   ├── migrate/
│   ├── schema.rb
│   ├── cache_schema.rb
│   └── queue_schema.rb
├── lib/
│   ├── tasks/
│   └── support/
│       ├── result.rb
│       ├── domain_error.rb
│       └── audit_context.rb
├── app/
│   ├── assets/
│   │   ├── builds/
│   │   ├── images/
│   │   └── stylesheets/
│   ├── channels/
│   ├── components/
│   │   ├── shared/
│   │   │   ├── app_shell_component.rb
│   │   │   ├── app_shell_component.html.erb
│   │   │   ├── filter_bar_component.rb
│   │   │   ├── filter_bar_component.html.erb
│   │   │   ├── data_table_component.rb
│   │   │   ├── data_table_component.html.erb
│   │   │   ├── status_badge_component.rb
│   │   │   ├── status_badge_component.html.erb
│   │   │   ├── blocked_state_callout_component.rb
│   │   │   ├── blocked_state_callout_component.html.erb
│   │   │   ├── guarded_confirmation_dialog_component.rb
│   │   │   └── guarded_confirmation_dialog_component.html.erb
│   │   ├── dashboard/
│   │   │   ├── triage_widget_component.rb
│   │   │   └── triage_widget_component.html.erb
│   │   ├── borrowers/
│   │   │   ├── summary_header_component.rb
│   │   │   └── summary_header_component.html.erb
│   │   ├── loan_applications/
│   │   │   ├── review_step_timeline_component.rb
│   │   │   └── review_step_timeline_component.html.erb
│   │   ├── loans/
│   │   │   ├── summary_header_component.rb
│   │   │   ├── summary_header_component.html.erb
│   │   │   ├── lifecycle_badge_component.rb
│   │   │   └── lifecycle_badge_component.html.erb
│   │   └── payments/
│   │       ├── summary_header_component.rb
│   │       └── summary_header_component.html.erb
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── concerns/
│   │   │   ├── authenticated.rb
│   │   │   ├── audit_tracked.rb
│   │   │   └── paginated.rb
│   │   ├── sessions_controller.rb
│   │   ├── passwords_controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── borrowers_controller.rb
│   │   ├── loan_applications_controller.rb
│   │   ├── review_steps_controller.rb
│   │   ├── loans_controller.rb
│   │   ├── disbursements_controller.rb
│   │   ├── payments_controller.rb
│   │   ├── invoices_controller.rb
│   │   ├── documents_controller.rb
│   │   └── admin/
│   │       ├── audit_logs_controller.rb
│   │       └── job_monitoring_controller.rb
│   ├── helpers/
│   ├── javascript/
│   │   ├── application.js
│   │   └── controllers/
│   │       ├── application.js
│   │       ├── index.js
│   │       ├── filter_bar_controller.js
│   │       ├── guarded_confirmation_controller.js
│   │       ├── modal_controller.js
│   │       ├── status_badge_controller.js
│   │       └── upload_controller.js
│   ├── jobs/
│   │   ├── application_job.rb
│   │   ├── audit_log_write_job.rb
│   │   ├── overdue_recalculation_job.rb
│   │   ├── loan_status_refresh_job.rb
│   │   ├── document_processing_job.rb
│   │   └── recurring/
│   │       ├── mark_overdue_payments_job.rb
│   │       └── refresh_dashboard_snapshots_job.rb
│   ├── mailers/
│   │   ├── application_mailer.rb
│   │   └── passwords_mailer.rb
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── current.rb
│   │   ├── user.rb
│   │   ├── session.rb
│   │   ├── borrower.rb
│   │   ├── borrower_snapshot.rb
│   │   ├── loan_application.rb
│   │   ├── review_step.rb
│   │   ├── loan.rb
│   │   ├── disbursement.rb
│   │   ├── payment.rb
│   │   ├── invoice.rb
│   │   ├── document_upload.rb
│   │   └── audit_log.rb
│   ├── policies/
│   │   ├── application_policy.rb
│   │   ├── borrower_policy.rb
│   │   ├── dashboard_policy.rb
│   │   ├── disbursement_policy.rb
│   │   ├── document_upload_policy.rb
│   │   ├── invoice_policy.rb
│   │   ├── loan_application_policy.rb
│   │   ├── loan_policy.rb
│   │   ├── payment_policy.rb
│   │   ├── review_step_policy.rb
│   │   └── user_policy.rb
│   ├── queries/
│   │   ├── dashboard/
│   │   │   ├── overdue_payments_query.rb
│   │   │   ├── upcoming_payments_query.rb
│   │   │   ├── open_applications_query.rb
│   │   │   ├── active_loans_query.rb
│   │   │   └── portfolio_summary_query.rb
│   │   ├── borrowers/
│   │   │   ├── lookup_query.rb
│   │   │   └── history_query.rb
│   │   ├── loan_applications/
│   │   │   └── filtered_list_query.rb
│   │   ├── loans/
│   │   │   ├── filtered_list_query.rb
│   │   │   └── overdue_query.rb
│   │   └── payments/
│   │       ├── filtered_list_query.rb
│   │       └── overdue_query.rb
│   ├── services/
│   │   ├── application_service.rb
│   │   ├── audit_logs/
│   │   │   └── record_event.rb
│   │   ├── authentication/
│   │   │   ├── sign_in.rb
│   │   │   └── sign_out.rb
│   │   ├── borrowers/
│   │   │   ├── create.rb
│   │   │   ├── update.rb
│   │   │   └── snapshot_for_lending.rb
│   │   ├── loan_applications/
│   │   │   ├── create.rb
│   │   │   ├── approve.rb
│   │   │   ├── reject.rb
│   │   │   ├── cancel.rb
│   │   │   └── initialize_review_steps.rb
│   │   ├── review_steps/
│   │   │   ├── approve.rb
│   │   │   ├── reject.rb
│   │   │   └── request_details.rb
│   │   ├── loans/
│   │   │   ├── create_from_application.rb
│   │   │   ├── finalize_documentation.rb
│   │   │   ├── disburse.rb
│   │   │   ├── generate_repayment_schedule.rb
│   │   │   ├── mark_overdue.rb
│   │   │   ├── close.rb
│   │   │   └── refresh_status.rb
│   │   ├── payments/
│   │   │   ├── mark_completed.rb
│   │   │   ├── apply_late_fee.rb
│   │   │   └── mark_overdue.rb
│   │   ├── invoices/
│   │   │   ├── issue_disbursement_invoice.rb
│   │   │   └── issue_payment_invoice.rb
│   │   └── documents/
│   │       ├── upload.rb
│   │       └── replace_active_version.rb
│   ├── validators/
│   │   ├── interest_input_validator.rb
│   │   ├── borrower_uniqueness_validator.rb
│   │   └── loan_editability_validator.rb
│   └── views/
│       ├── layouts/
│       │   └── application.html.erb
│       ├── dashboard/
│       │   └── show.html.erb
│       ├── sessions/
│       ├── passwords/
│       ├── borrowers/
│       ├── loan_applications/
│       ├── review_steps/
│       ├── loans/
│       ├── payments/
│       ├── invoices/
│       ├── disbursements/
│       └── documents/
├── bin/
│   ├── brakeman
│   ├── dev
│   ├── docker-entrypoint
│   ├── kamal
│   ├── rails
│   ├── rake
│   ├── rubocop
│   └── setup
├── public/
│   ├── 404.html
│   ├── 422.html
│   ├── 500.html
│   └── icon.png
├── script/
├── storage/
├── test/
├── tmp/
├── vendor/
└── spec/
    ├── components/
    │   ├── dashboard/
    │   ├── loans/
    │   ├── payments/
    │   └── shared/
    ├── factories/
    │   ├── borrowers.rb
    │   ├── loan_applications.rb
    │   ├── loans.rb
    │   ├── payments.rb
    │   ├── invoices.rb
    │   └── users.rb
    ├── fixtures/
    ├── jobs/
    ├── models/
    ├── policies/
    ├── queries/
    ├── requests/
    │   ├── dashboard_spec.rb
    │   ├── borrowers_spec.rb
    │   ├── loan_applications_spec.rb
    │   ├── loans_spec.rb
    │   ├── payments_spec.rb
    │   └── sessions_spec.rb
    ├── services/
    │   ├── borrowers/
    │   ├── loan_applications/
    │   ├── loans/
    │   ├── payments/
    │   ├── invoices/
    │   └── documents/
    ├── support/
    │   ├── authentication_helpers.rb
    │   ├── component_helpers.rb
    │   ├── encryption_helpers.rb
    │   └── result_matchers.rb
    ├── system/
    │   ├── authentication/
    │   ├── dashboard/
    │   ├── loan_applications/
    │   ├── loans/
    │   └── payments/
    ├── rails_helper.rb
    └── spec_helper.rb
```

### Architectural Boundaries

**API Boundaries:**
- No separate public API layer in MVP.
- Primary boundary is HTML-first Rails controllers calling domain services.
- Controllers own HTTP concerns only:
  - parameter extraction
  - authorization invocation
  - render/redirect selection
  - flash/message translation
- Domain services own business mutations.
- Future JSON endpoints, if added, must reuse the same services and result patterns.

**Component Boundaries:**
- `ViewComponent` is used for reusable or workflow-significant UI only.
- Simple page composition remains in normal Rails views.
- `Stimulus` handles local interaction behavior only.
- `Turbo` handles navigation, frames, and partial server-driven updates.
- UI components must never become a second business-rules layer.

**Service Boundaries:**
- `app/services` is the canonical home for:
  - lifecycle transitions
  - repayment calculations
  - overdue derivation
  - audit-aware domain actions
- Jobs, controllers, and future scripts must delegate to services.
- Query objects live separately in `app/queries` and must not perform mutations.
- Policies live separately in `app/policies` and must not contain workflow logic.

**Data Boundaries:**
- `app/models` owns persistence, associations, enums, encrypted attributes, and simple invariants.
- Database constraints enforce hard invariants.
- Searchable encrypted fields require explicit design, especially borrower phone lookup.
- `Solid Cache` is used selectively for safe read-heavy paths.
- `Solid Queue` owns async work, but not business-rule duplication.

### Requirements to Structure Mapping

**Feature/Epic Mapping:**
- Access & session control:
  - `app/controllers/sessions_controller.rb`
  - `app/models/user.rb`
  - `app/models/session.rb`
  - `app/services/authentication/*`
  - `app/policies/user_policy.rb`
  - `spec/requests/sessions_spec.rb`
  - `spec/system/authentication/*`
- Borrower management:
  - `app/models/borrower.rb`
  - `app/controllers/borrowers_controller.rb`
  - `app/services/borrowers/*`
  - `app/queries/borrowers/*`
  - `app/components/borrowers/*`
  - `spec/services/borrowers/*`
- Application review workflow:
  - `app/models/loan_application.rb`
  - `app/models/review_step.rb`
  - `app/controllers/loan_applications_controller.rb`
  - `app/controllers/review_steps_controller.rb`
  - `app/services/loan_applications/*`
  - `app/services/review_steps/*`
  - `app/components/loan_applications/*`
- Loan setup, documentation, and disbursement:
  - `app/models/loan.rb`
  - `app/models/disbursement.rb`
  - `app/controllers/loans_controller.rb`
  - `app/controllers/disbursements_controller.rb`
  - `app/services/loans/*`
  - `spec/services/loans/*`
- Repayment tracking and overdue control:
  - `app/models/payment.rb`
  - `app/models/invoice.rb`
  - `app/controllers/payments_controller.rb`
  - `app/services/payments/*`
  - `app/services/invoices/*`
  - `app/jobs/overdue_recalculation_job.rb`
  - `app/jobs/recurring/mark_overdue_payments_job.rb`
  - `app/queries/payments/*`
- Dashboard and operational investigation:
  - `app/controllers/dashboard_controller.rb`
  - `app/queries/dashboard/*`
  - `app/components/dashboard/*`
  - `app/components/shared/*`
- Documents and uploads:
  - `app/models/document_upload.rb`
  - `app/controllers/documents_controller.rb`
  - `app/services/documents/*`
  - `app/jobs/document_processing_job.rb`

**Cross-Cutting Concerns:**
- Authentication:
  - `app/controllers/concerns/authenticated.rb`
  - `app/services/authentication/*`
  - `app/models/current.rb`
- Authorization:
  - `app/policies/*`
  - controller `authorize` calls
  - service/domain boundary checks for critical actions
- Audit logging:
  - `app/models/audit_log.rb`
  - `app/services/audit_logs/record_event.rb`
  - `app/controllers/concerns/audit_tracked.rb`
  - `app/jobs/audit_log_write_job.rb`
- Encryption:
  - model-level encrypted attributes
  - `config/initializers/active_record_encryption.rb`
- Rate limiting:
  - `config/initializers/rate_limiting.rb`
  - auth-sensitive controller actions first
- Shared UI primitives:
  - `app/components/shared/*`

### Integration Points

**Internal Communication:**
- Controllers -> Policies -> Services -> Models
- Jobs -> Services -> Models
- Queries -> Models / read-side joins/scopes
- Components -> controller/view-assigned data only
- Components/Stimulus -> controller actions via forms/links/Turbo

**External Integrations:**
- None required for MVP business workflows.
- Infrastructure integrations only:
  - PostgreSQL
  - Solid Cache database store
  - Solid Queue database-backed jobs
  - Docker/Kamal deployment path
  - GitHub Actions CI

**Data Flow:**
- User action -> Rails controller -> `Pundit` authorization -> domain service -> model/database transaction -> audit event -> render/redirect
- Recurring checks -> Solid Queue job -> domain service -> state refresh -> audit event -> dashboard queries reflect updated state
- Dashboard/list screens -> query objects -> components/views -> Turbo/HTML response

### File Organization Patterns

**Configuration Files:**
- Rails configuration stays under `config/`.
- Deployment configuration stays in `config/deploy.yml` and `.kamal/`.
- CI lives in `.github/workflows/`.
- Queue/cache setup lives in Rails-native config files.

**Source Organization:**
- Organize by responsibility first, then namespace by domain.
- Domain mutations in `app/services/<domain>/`.
- Read models in `app/queries/<domain>/` or `app/queries/dashboard/`.
- Shared UI primitives under `app/components/shared/`.
- Workflow-significant UI under domain component namespaces.

**Test Organization:**
- Mirror runtime structure in `spec/`.
- Money-critical services get first-class service specs.
- Controllers are primarily covered with request specs.
- Reusable components get component specs.
- End-to-end business flows live in `spec/system/`.

**Asset Organization:**
- Tailwind and Rails asset outputs remain under Rails defaults.
- Stimulus controllers stay in `app/javascript/controllers/`.
- Static images and public assets stay under `app/assets` and `public/`.

### Development Workflow Integration

**Development Server Structure:**
- `bin/dev` runs the Rails app and frontend watchers using the Rails/Tailwind local workflow.
- Developers work primarily through:
  - controllers/views/components for UI
  - services for business rules
  - queries for dashboard/list reads
  - specs mirroring each layer

**Build Process Structure:**
- CI validates:
  - bundle install
  - database setup
  - RSpec suite
  - lint/security checks
  - Docker image build
- The project structure supports independent testing of services, queries, policies, requests, and system flows.

**Deployment Structure:**
- Docker image is the main deployment artifact.
- Kamal readiness is preserved without requiring immediate host commitment.
- Web and job processes can be separated cleanly because controller traffic and recurring/background work already have different runtime homes.

## Architecture Validation Results

### Coherence Validation ✅

**Decision Compatibility:**
The architecture is coherent as a Rails monolith built on PostgreSQL, Tailwind, Docker, `ViewComponent`, `Turbo`, `Stimulus`, `shadcn-rails`, `Pundit`, `Solid Cache`, and `Solid Queue`. These choices align well with the HTML-first MPA interaction model and the internal lending workflow defined in the PRD and UX specification.

The late refinements also fit together cleanly:
- `roles` + `user_roles` make `Pundit` future-safe
- `paper_trail` provides model-change auditing without forcing custom bookkeeping-style audit code everywhere
- minimal explicit auth/security event logging fills the gap for non-model security events
- `phonelib` supports borrower phone normalization and validation
- `money-rails` provides safe single-currency amount handling
- `double_entry` provides a proper accounting ledger without overloading operational models
- `aasm` provides an explicit state-machine layer for workflow entities without replacing service-led domain orchestration
- UUID primary keys and UUID foreign keys strengthen identity handling without conflicting with Rails or PostgreSQL conventions

**Pattern Consistency:**
The implementation patterns support the architecture effectively:
- service objects remain the canonical home for money-critical business rules
- query objects support dashboard/list/investigation reads cleanly
- `ViewComponent` patterns match the repeatable admin UI needs
- jobs delegate to services, preserving a single source of business truth
- naming, result-object, and test-location rules are now specific enough to reduce multi-agent drift
- UUID, money, phone, authorization, and workflow-state concerns now have explicit implementation direction rather than being left to agent interpretation

**Structure Alignment:**
The project structure supports the selected stack and boundaries. Runtime responsibilities, tests, components, services, policies, and query objects are all explicitly placed. The structure also remains coherent after the added authorization, auditing, phone, money, bookkeeping, and UUID refinements.

The main structure changes to apply during implementation bootstrap are:
- add `app/models/role.rb`
- add `app/models/user_role.rb`
- add `paper_trail` configuration and model versioning setup
- add a lightweight auth/security event path for non-versioned events
- add `phonelib`, `money-rails`, `double_entry`, and `aasm` initializers/configuration
- enforce UUID-by-default migrations across all domain entities

### Requirements Coverage Validation ✅

**Feature Coverage:**
All major product capability areas are architecturally supported:
- authentication and session handling
- borrower intake and lookup
- application review and decision workflow
- loan setup, documentation, and disbursement
- repayment tracking, overdue control, and loan closure
- dashboard triage and operational investigation
- document handling
- auditability, bookkeeping, and financial traceability

**Functional Requirements Coverage:**
All major FR categories are supported by the architecture:
- access/session control via Rails-native auth, sessions, rate limiting, roles, and policies
- borrower management via borrower models, queries, services, phone normalization, and lookup strategy
- application management via application/review-step models and services
- loan setup/disbursement via loan/disbursement services and guarded actions
- repayment tracking via payment/invoice models, money-safe services, overdue jobs, and queries
- dashboard/search via query objects, shared components, and HTML-first flows
- record integrity via immutable post-money rules, model version history, service-led mutations, and double-entry posting boundaries

**Non-Functional Requirements Coverage:**
- performance is supported through HTML-first rendering, query-object boundaries, selective caching, and a lean monolith
- security is supported through Rails-native auth, bcrypt, `Pundit`, role tables, Active Record Encryption, rate limiting, and auditing
- reliability is supported through deterministic domain services, explicit transitions, `aasm`-guarded state machines, server-side source of truth, and ledger-backed accounting
- scalability is appropriately handled for MVP with a lean monolith and separate web/job evolution path
- audit/compliance-readiness is strengthened by combining `paper_trail`, auth event logging, service boundaries, `money-rails`, and `double_entry`

### Implementation Readiness Validation ✅

**Decision Completeness:**
Critical architectural decisions are now explicit enough for consistent implementation:
- stack and architectural style
- auth and authorization shape
- UUID identity strategy
- workflow state-machine strategy
- auditing approach
- phone normalization/validation
- amount handling
- bookkeeping boundary
- frontend structure
- infrastructure and project organization

**Structure Completeness:**
The structure is concrete and specific, not generic. It includes clear homes for models, services, queries, policies, components, jobs, specs, configuration, and deployment artifacts.

**Pattern Completeness:**
The patterns are strong enough to prevent common agent conflicts:
- canonical naming
- clear service/query/component boundaries
- jobs delegating to services
- consistent result-object handling
- mirrored test structure
- canonical domain vocabulary for statuses and transitions
- UUID and money-safe modeling rules

### Gap Analysis Results

**Critical Gaps:**
- None blocking implementation.

**Important Gaps:**
- The exact searchable-encryption strategy for borrower phone lookup should be specified early in implementation.
- The initial role/capability matrix should be defined before implementing broader policy checks.
- The exact `double_entry` account definitions and posting rules should be finalized before disbursement and repayment workflows are built.
- The exact set of versioned models under `paper_trail` should be explicitly listed during implementation bootstrap.

**Nice-to-Have Gaps:**
- Final hosting provider selection is intentionally deferred.
- APM/error-tracking vendor is intentionally deferred.
- Formal JSON/OpenAPI tooling is intentionally deferred unless a larger JSON surface emerges.
- Additional UI primitive examples can be added later if the component layer expands.

### Validation Issues Addressed

- Resolved the admin-only MVP vs future-safe authorization tension by introducing `roles` and `user_roles`.
- Replaced custom-first record auditing with `paper_trail` for model history, while keeping minimal explicit auth/security event logging.
- Strengthened borrower identity handling through `phonelib` normalization and validation.
- Standardized amount handling with `money-rails` in a single-currency model.
- Added `double_entry` to separate operational workflow records from bookkeeping truth.
- Added `aasm` to formalize valid workflow states and transitions for lifecycle-driven entities.
- Added a recommended supporting-gem layer so implementation quality is improved without changing architecture.
- Locked UUID primary keys and UUID foreign keys as the default identity convention for all domain entities.
- Confirmed that only money-moving domain services should create `double_entry` postings.

### Architecture Completeness Checklist

**✅ Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**✅ Architectural Decisions**
- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance and security considerations addressed

**✅ Implementation Patterns**
- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**✅ Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements-to-structure mapping completed

### Architecture Readiness Assessment

**Overall Status:** READY FOR IMPLEMENTATION

**Confidence Level:** High

**Key Strengths:**
- Strong alignment between product needs and Rails monolith architecture
- Clear money-critical service boundaries
- Explicit separation between workflow state and accounting ledger
- Future-safe authorization model
- Strong multi-agent implementation consistency rules
- Rails-native ops story with low infrastructure complexity

**Areas for Future Enhancement:**
- Formalize role/capability matrix
- Finalize searchable encrypted phone strategy
- Finalize `double_entry` chart of accounts and posting rules
- Add richer observability after MVP stabilization
- Expand authorization/reporting if multi-user complexity grows

### Recommended Gems Stack

**Core Architectural Gems:**
- `pundit`
- `paper_trail`
- `phonelib`
- `money-rails`
- `double_entry`
- `aasm`
- `shadcn-rails`

**Core Operational/Platform Gems:**
- `solid_cache`
- `solid_queue`
- `mission_control-jobs`

**Recommended Supporting Gems:**
- `rspec-rails`
- `factory_bot_rails`
- `shoulda-matchers`
- `rubocop-rails-omakase`
- `brakeman`
- `pagy`
- `strong_migrations`
- `active_storage_validations` for document uploads

### Implementation Handoff

**AI Agent Guidelines:**
- Follow all architectural decisions exactly as documented
- Use implementation patterns consistently across all components
- Respect project structure and boundaries
- Route all money-critical mutations through domain services
- Use `paper_trail` for record-history auditing and minimal explicit logging only for auth/security events
- Use `money-rails` for amount modeling, `double_entry` for ledger postings, and `aasm` for canonical workflow state transitions
- Implement authorization through `roles`, `user_roles`, and `Pundit` policies
- Use UUID primary keys and UUID foreign keys consistently for domain entities

**First Implementation Priority:**
Initialize the Rails application with the official starter, then immediately add:
- `RSpec`
- Rails built-in authentication
- `Pundit`
- `roles` and `user_roles`
- `paper_trail`
- `phonelib`
- `money-rails`
- `double_entry`
- `aasm`
- `shadcn-rails`
- base service/query/component structure
