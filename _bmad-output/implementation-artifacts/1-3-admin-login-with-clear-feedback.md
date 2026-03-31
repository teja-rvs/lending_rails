# Story 1.3: Admin Login with Clear Feedback

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to sign in with email and password through a focused login flow,
so that I can quickly and confidently access the lending system.

## Acceptance Criteria

1. **Given** the admin is not signed in  
   **When** they open the login page  
   **Then** they see a focused email-and-password form with the product identity clearly presented  
   **And** the page feels calm, legible, and appropriate for an internal financial operations tool

2. **Given** valid admin credentials  
   **When** the admin submits the login form  
   **Then** the system creates an authenticated session  
   **And** redirects the admin into the operational workspace

3. **Given** invalid credentials  
   **When** the admin submits the login form  
   **Then** the system does not create a session  
   **And** shows a clear recoverable error message without losing orientation

## Tasks / Subtasks

- [x] Rework the login page into a focused, product-identified entry screen (AC: 1, 3)
  - [x] Replace the bare `app/views/sessions/new.html.erb` scaffold with a restrained, desktop-first login card that clearly presents `lending_rails` as the internal lending operations system
  - [x] Keep the page free of dashboard placeholders, marketing copy, or extra navigation that dilutes the sign-in task
  - [x] Preserve a clear email field, password field, primary submit action, and password-recovery link with readable labels, spacing, and focus states
  - [x] Ensure invalid-login feedback stays visible, calm, and recoverable without making the user lose context or wonder what to do next

- [x] Align the auth feedback experience with the current Rails-native flow (AC: 2, 3)
  - [x] Reuse the existing `SessionsController#create` authentication path, admin-only gate, and signed-cookie session creation instead of replacing the auth stack
  - [x] Keep the invalid-credential copy clear and non-alarming; refine wording only if it improves recovery without leaking sensitive information
  - [x] Remove duplicated or conflicting flash presentation between the layout and the login view so failed sign-in shows one coherent message path
  - [x] Preserve `after_authentication_url` behavior so successful login still returns the admin to the intended protected destination or the current root workspace

- [x] Keep the implementation inside the Epic 1 story boundaries (AC: 1, 2, 3)
  - [x] Treat this as a login-flow polish story, not a dashboard build or logout story
  - [x] Do not change the seeded-admin-only admission rule introduced in Story `1.2`
  - [x] Do not add signup, invitation, account settings, profile management, or role-management flows
  - [x] Do not swap Rails-native auth for Devise or another authentication framework

- [x] Add focused automated coverage for the login entry and feedback behavior (AC: 1, 2, 3)
  - [x] Add or extend request specs that prove the login page renders the expected product identity and focused form elements
  - [x] Cover the happy path where a valid admin signs in and is redirected into the protected workspace
  - [x] Cover the unhappy path where invalid credentials return the user to the login screen with a clear recoverable message and without creating a session
  - [x] Keep existing workspace-access and password-reset coverage passing so UX polish does not regress the current auth baseline

### Review Findings

- [x] [Review][Patch] Add regression coverage for `after_authentication_url` return-to behavior [`spec/requests/sessions_spec.rb`]
- [x] [Review][Patch] Replace brittle raw-HTML body assertions with selector-scoped expectations in the new sessions request spec [`spec/requests/sessions_spec.rb`]

## Dev Notes

### Story Intent

Story `1.2` completed the secure access boundary, but the current login screen is still close to the Rails-generated default. This story should turn that baseline into the calm, focused entry experience described in the epic, UX requirements, and login wireframe without changing the underlying authentication model or jumping ahead to the final dashboard owned by later stories.

### Current Codebase Signals

- `app/views/sessions/new.html.erb` is still a minimal generated form. It includes page-local flash rendering even though `app/views/layouts/application.html.erb` already renders global flash banners, which risks duplicate error messaging.
- `SessionsController#create` already enforces the seeded-admin-only rule, uses Rails-native `User.authenticate_by`, rate limits sign-in attempts, and redirects successful sign-in through `after_authentication_url`.
- `Authentication#after_authentication_url` already preserves return-to behavior for protected pages. This story should not break that flow while polishing the UI.
- `root "home#index"` is currently the protected workspace shell. Story `1.4` owns making that landing experience fully intentional and adding logout behavior; Story `1.3` should only ensure the login flow sends the user there cleanly.
- Existing auth coverage lives in request specs such as `spec/requests/workspace_access_spec.rb` and `spec/requests/passwords_spec.rb`, so the implementation should extend the current testing pattern instead of inventing a brand-new test style without need.

### Scope Boundaries

- Deliver a focused sign-in experience, not the full authenticated workspace redesign.
- Keep the current single-admin MVP access model intact.
- Do not build dashboard metrics, borrower navigation, or post-login global navigation in this story.
- Do not add auth features that the PRD explicitly leaves out for MVP, such as self-service registration or in-app user management.

### Developer Guardrails

- Reuse the Rails 8 authentication generator structure already present in the app: `User`, `Session`, `Current`, `Authentication`, `SessionsController`, and signed cookie-backed session resumption.
- Preserve the existing admin gate and generic invalid-login posture. UX polish must not weaken the security boundary or create account-enumeration hints.
- Keep the screen HTML-first and server-rendered. Use Stimulus or Turbo only if they materially improve presentation without complicating the flow.
- Favor one clear flash/error presentation path. Do not render the same error twice in the layout and inside the page body.
- Keep the login page visually restrained and operationally serious. This is an internal financial tool, not a marketing surface.

### Technical Requirements

- The sign-in flow must remain Rails-native, using `has_secure_password`, `User.authenticate_by`, the `sessions` table, and signed cookie session identifiers.
- The page must prominently identify the product as `lending_rails` or the lending operations workspace, aligning with the UX requirement for clear product identity.
- Successful login must continue to create an authenticated session and redirect through the existing protected-entry flow.
- Invalid login must not create a session and must return the user to the login screen with a clear, recoverable message.
- The current rate limiting on `SessionsController#create` must remain intact.
- Password reset entry (`Forgot password?`) must remain available from the login experience.

### Architecture Compliance

- `app/controllers/sessions_controller.rb`: HTTP orchestration only. Keep authentication decisions and redirects thin.
- `app/controllers/concerns/authentication.rb`: preserve shared auth/session lifecycle behavior, especially `after_authentication_url`.
- `app/views/sessions/new.html.erb`: primary login-page implementation point for layout, hierarchy, and task focus.
- `app/views/layouts/application.html.erb`: likely touchpoint if flash handling needs to be normalized for auth pages.
- `app/components`: optional only if the implementation extracts a genuinely reusable auth card, alert, or form primitive. Do not create component sprawl for a one-off screen.
- `spec/requests`: primary proof surface for login-page content, redirects, and failed-login feedback.

### File Structure Requirements

Likely implementation touchpoints based on the current app state:

- `app/views/sessions/new.html.erb`
- `app/controllers/sessions_controller.rb`
- `app/views/layouts/application.html.erb`
- `app/assets/tailwind/application.css` or the app stylesheet only if a small amount of shared auth-page styling is truly needed
- `spec/requests/workspace_access_spec.rb`
- `spec/requests/root_shell_spec.rb` if the protected landing expectations need refinement
- a new or updated request spec focused on sign-in page rendering and invalid-credential feedback

Do not introduce a separate auth frontend, a client-side global state flow, or a parallel sessions controller just to improve the page presentation.

### UX Requirements to Preserve

- The login experience should feel simple, calm, and trustworthy.
- The screen should present the product name clearly, followed by a focused email-and-password form.
- The page should avoid distracting marketing content or unnecessary visual weight.
- Failed login attempts should be recoverable without confusion and should preserve orientation.
- The visual tone should use restrained surfaces, readable typography, and clear focus/feedback states suitable for dense admin work.

### Testing Requirements

- Use request specs as the default coverage style because that is the established auth-testing pattern in this repo today.
- Assert that unauthenticated users can render the login page and see the expected product identity, form fields, and recovery link.
- Assert that valid admin credentials create a session and redirect into the protected workspace.
- Assert that invalid credentials do not create a session and show the recoverable error message on the returned login experience.
- Keep password-reset access working for unauthenticated users; login-page polish must not break the current password-reset route and forms.

### Previous Story Intelligence

- Story `1.1` established the Rails monolith baseline, the root workspace shell, `Pundit`, `PaperTrail`, and the generated Rails auth structure. Reuse that baseline instead of replacing it.
- Story `1.2` already enforced the seeded-admin boundary and protected workspace admission. This story must polish the login experience on top of that rule, not relax or duplicate the security logic.
- Story `1.2` also confirmed that password reset must remain usable without an authenticated admin session, so the login page should continue to provide an obvious recovery path.

### Git Intelligence Summary

- Recent repository history shows two focused setup/auth commits: `Initialize Rails lending foundation.` and `Seed admin access and follow-up fixes.`
- Follow the same incremental pattern: keep Story `1.3` tightly scoped to login UX and auth-flow polish rather than mixing in Story `1.4` workspace-entry work.

### Latest Technical Information

- Rails 8's built-in authentication generator remains the right baseline for this story. It provides the current `User`, `Session`, `Current`, `SessionsController`, and password-reset structure already present in the app.
- Rails `authenticate_by` is designed to support secure credential verification without replacing the existing server-rendered flow. Keep using it rather than introducing custom auth logic.
- The Rails-native auth generator intentionally persists sessions in the database and resumes them from a signed cookie, which fits the current admin-only internal app model and should not be rewritten for this story.
- `shadcn-rails` continues to be a Rails-friendly way to own copied component primitives if the implementation needs a reusable card, alert, button, or input treatment. Use generated/app-owned primitives only if they materially improve reuse; otherwise a focused Tailwind-first ERB implementation is acceptable.
- Turbo/Rails auth redirects can be sensitive if an auth form is forced into partial-page behavior. Keep this flow conventional and full-page oriented unless there is a clear reason to add richer behavior.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 1, Story 1.3, Story 1.4, non-functional requirements, UX design requirements
- `/_bmad-output/planning-artifacts/prd.md` - Persona: Admin Operator, Journey 1, Journey Requirements Summary, Security Architecture Expectations
- `/_bmad-output/planning-artifacts/architecture.md` - Core Architectural Decisions, Authentication & Security, Frontend Architecture, Decision Impact Analysis
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - Login to Dashboard Landing, Experience Principles, Flow Optimization Principles, Accessibility Considerations
- `/_bmad-output/planning-artifacts/ux-wireframes-pages/01-1-login.html` - Login page wireframe and annotation
- `/_bmad-output/implementation-artifacts/1-1-initialize-the-rails-operational-foundation.md` - Dev Notes, Review Findings, File List
- `/_bmad-output/implementation-artifacts/1-2-seed-the-admin-account-and-secure-access-rules.md` - Current Codebase Signals, Developer Guardrails, Completion Notes List
- `app/views/sessions/new.html.erb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/concerns/authentication.rb`
- `app/views/layouts/application.html.erb`
- `spec/requests/workspace_access_spec.rb`
- `spec/requests/passwords_spec.rb`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-03-31T11:27:36+05:30
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `1-3-admin-login-with-clear-feedback` as the first backlog story
- No `project-context.md` file was found during story preparation
- Sprint status updated to `in-progress` on 2026-03-31T11:32:48+05:30 before implementation work began
- Added focused request coverage in `spec/requests/sessions_spec.rb` for login-page identity, admin sign-in redirect, and single-message invalid-credential feedback
- Reworked `app/views/sessions/new.html.erb` into a product-identified login card and removed page-local flash rendering so auth feedback has one presentation path
- Validation is currently blocked locally because the test suite cannot connect to PostgreSQL and Docker is not running (`Cannot connect to the Docker daemon`)
- Local PostgreSQL became available after starting `docker compose` and the validation blocker was cleared
- `RAILS_ENV=test bin/rails db:prepare` completed successfully
- `bundle exec rspec spec/requests/sessions_spec.rb` passed after tightening a brittle title/button text assertion
- Full regression validation passed with `bundle exec rspec` (21 examples, 0 failures)
- `bundle exec rubocop` still reports a pre-existing unrelated style offense in `Gemfile` for `Layout/SpaceInsideArrayLiteralBrackets`

### Implementation Plan

- Replace the generated-looking login page with a calm, product-identified sign-in experience that matches the UX direction and wireframe.
- Preserve the existing Rails-native auth flow, admin-only admission rule, return-to behavior, and password-reset path while normalizing error/flash presentation.
- Extend the current request-spec coverage so login rendering, successful sign-in, and recoverable invalid-credential behavior are all proven before Story `1.4` builds on this entry point.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story context assembled from epics, PRD, architecture, UX specification, login wireframe, previous story learnings, current auth code, and recent git history.
- The current implementation gap is narrow and well-defined: secure admin login already works, but the sign-in screen still needs the focused product identity, calm presentation, and cohesive feedback expected by the planning artifacts.
- Duplicate flash rendering is a likely cleanup point during implementation because the layout and login page currently both render alert/notice content.
- Story `1.4` should inherit a polished login flow from this story rather than bundling sign-in-page polish together with dashboard/workspace-entry work.
- Implemented the server-rendered login-page refresh in `app/views/sessions/new.html.erb` with clear product identity, labeled fields, a restrained admin-only tone, and the existing password-recovery entry point.
- Added `spec/requests/sessions_spec.rb` to prove the focused login entry experience, successful admin redirect into the workspace, and recoverable invalid-credential feedback without duplicate messaging.
- Validation was briefly blocked while PostgreSQL was unavailable locally, but the blocker was cleared once Docker/Postgres came up and the story could be fully verified.
- Completed the validation loop once PostgreSQL was available: prepared the test database, passed the new sessions request spec, and passed the full RSpec suite without regressions.
- Left the application controller/auth stack unchanged because the existing Rails-native session flow, admin gate, and return-to behavior already satisfied the story requirements.
- RuboCop still reports an unrelated pre-existing formatting issue in `Gemfile`, so the story is moving to review with that residual repo-level lint noise noted rather than silently changing unrelated code.

### File List

- `app/views/sessions/new.html.erb`
- `spec/requests/sessions_spec.rb`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-3-admin-login-with-clear-feedback.md`

### Change Log

- 2026-03-31: Reworked the admin login page into a focused product-identified entry screen, removed duplicate auth-page flash rendering, added request coverage for login rendering and feedback, and validated the full RSpec suite before moving the story to review.
