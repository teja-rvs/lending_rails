# Story 1.4: Authenticated Workspace Entry and Logout

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an admin operator,
I want to land on a protected workspace after login and be able to log out safely,
so that I can enter the system cleanly and end my session without retaining protected access.

## Acceptance Criteria

1. **Given** the admin has authenticated successfully  
   **When** they enter the product  
   **Then** they land on the protected authenticated workspace entry point  
   **And** the page is protected from unauthenticated access

2. **Given** the admin is in the authenticated workspace  
   **When** the page loads  
   **Then** it shows the operational workspace shell with clear orientation and sign-out access  
   **And** the experience reflects the latest committed system state

3. **Given** the admin has an active session  
   **When** they choose to log out  
   **Then** the session is ended securely  
   **And** they are returned to the login flow without retaining protected access

## Tasks / Subtasks

- [x] Turn the post-login landing into the protected authenticated workspace entry point (AC: 1, 2)
  - [x] Reuse the existing canonical post-login destination instead of introducing a parallel workspace route unless a dedicated `DashboardController#show` is the smallest coherent change
  - [x] Replace the current foundation/marketing-like shell with an authenticated workspace entry experience that clearly identifies where the admin is and what the product is ready for today
  - [x] Keep the landing server-rendered and based on real current application state; do not fake future dashboard widgets or placeholder metrics that imply unfinished capabilities
  - [x] Preserve unauthenticated blocking for the workspace entry point and keep return-to behavior intact for protected routes

- [x] Add clear, accessible sign-out access to the authenticated shell (AC: 2, 3)
  - [x] Surface a visible sign-out control in the workspace shell header or top-level navigation area
  - [x] Wire sign-out to the existing `DELETE /session` flow rather than building a second logout endpoint or custom JavaScript logout path
  - [x] Prefer `button_to` or another Rails form helper-backed control so CSRF protection remains standard and explicit
  - [x] After sign-out, ensure the user is returned to the login flow and cannot revisit protected screens with the old session

- [x] Keep the story inside the Epic 1 boundary (AC: 1, 2, 3)
  - [x] Treat this story as authenticated entry, workspace orientation, and logout completion, not the full operational dashboard build from later work
  - [x] Do not add borrower/application/loan navigation trees, filtered-list drill-ins, or full dashboard widgets unless they are required to make the shell coherent
  - [x] Do not replace Rails-native authentication, session persistence, or the seeded-admin-only MVP admission rule
  - [x] Do not introduce client-side auth state, custom session stores, or a second workspace landing page that competes with the canonical post-login entry point

- [x] Add focused automated coverage for protected entry and logout behavior (AC: 1, 2, 3)
  - [x] Extend the existing request-spec auth pattern to prove an authenticated admin reaches the workspace shell and sees clear orientation plus sign-out access
  - [x] Add request coverage for `DELETE /session` proving the persisted session is removed and protected pages redirect back to sign-in afterward
  - [x] Keep current workspace-access, return-to, and non-admin rejection coverage passing
  - [x] Reuse existing spec helpers and patterns where possible instead of copy-pasting another signed-session helper implementation

## Dev Notes

### Story Intent

Story `1.3` completed a polished login experience and already redirects successful sign-in into the protected app. Story `1.4` should make that destination feel intentional: the admin should land in a clearly authenticated workspace shell, understand that they are inside the lending operations area, and have an obvious secure way to leave the session. This story finishes the access loop without prematurely implementing the full data-rich dashboard planned for later workflows.

### Current Codebase Signals

- `root "home#index"` is the current protected post-login destination and already sits behind the global authentication and admin checks.
- `app/views/home/index.html.erb` still reads like a foundation/launch placeholder. It includes an `Operator sign in` call to action even though the route is already protected, which makes the authenticated entry experience feel inconsistent.
- `SessionsController#create` already authenticates the user, applies rate limiting, enforces the seeded-admin-only rule, and redirects through `after_authentication_url`.
- `SessionsController#destroy` already exists and calls `terminate_session`, but the current authenticated workspace does not expose a visible sign-out control and request specs do not yet cover logout.
- `Authentication#request_authentication` stores the protected URL in `session[:return_to_after_authenticating]`, so workspace-entry changes must not break return-to behavior for protected routes such as `/jobs`.

### Scope Boundaries

- Deliver a protected workspace entry shell and secure logout completion, not the full operational dashboard from later stories and epics.
- Keep the canonical landing singular. Prefer evolving the current root entry point or routing root into a dedicated dashboard page, but do not keep both a temporary workspace shell and a separate new dashboard entry alive in parallel.
- Do not add signup, invitation, account settings, multi-user admin management, or role-management workflows.
- Do not expand this story into idle-timeout redesign work. Respect the PRD's 30-minute inactivity requirement, but avoid inventing a partial client-side timeout solution if the broader session-lifecycle design is not being addressed here.

### Developer Guardrails

- Reuse the Rails 8 generated auth stack already present: `User`, `Session`, `Current`, `Authentication`, `SessionsController`, signed cookie session persistence, and server-managed redirects.
- Keep controllers thin. Workspace-entry presentation belongs in the view layer or reusable components, while session lifecycle behavior should continue to live in the existing auth concern and controller flow.
- The shell must reflect real current state on page load. Prefer honest orientation content such as current workspace context, authenticated-user presence, and today's available system surfaces over speculative metrics or fake dashboard cards.
- Avoid duplicating auth/session logic in the view. The shell should consume `authenticated?`, `Current.user`, route helpers, and the existing logout action rather than re-deriving session state.
- Keep the experience HTML-first and desktop-first. Use Stimulus or Turbo only if they reduce friction without obscuring the conventional request/response auth flow.

### Technical Requirements

- The post-login entry point must remain protected from unauthenticated access through the existing authentication boundary.
- Successful admin login must continue to land on the canonical authenticated workspace entry point through `after_authentication_url`.
- The authenticated shell must show clear orientation, such as product identity, workspace purpose, or current section context, plus an obvious sign-out control.
- Sign-out must use the existing `SessionsController#destroy` flow, remove the persisted session, clear the signed session cookie, and return the user to the login screen.
- After logout, previously protected pages must require re-authentication rather than rendering from stale session state.
- Preserve the existing login rate limiting and generic auth-failure posture; this story must not weaken the security model introduced in Stories `1.2` and `1.3`.

### Architecture Compliance

- `app/controllers/application_controller.rb`: keep the global auth/admin boundary intact.
- `app/controllers/concerns/authentication.rb`: preserve `after_authentication_url`, `request_authentication`, `start_new_session_for`, and `terminate_session` as the canonical session lifecycle hooks.
- `app/controllers/sessions_controller.rb`: reuse the existing `destroy` action; touch only if a small UX-facing change is truly required.
- `app/controllers/home_controller.rb` and `app/views/home/index.html.erb`: current default implementation point for the authenticated entry shell if root remains the workspace entry.
- `app/controllers/dashboard_controller.rb` and `app/views/dashboard/show.html.erb`: acceptable alternative implementation point if the story promotes the root entry into the architecture-aligned dashboard shell.
- `app/views/layouts/application.html.erb`: likely touchpoint if sign-out or authenticated-shell chrome should live at layout level instead of page-local level.
- `app/components/shared/*`: optional only if the implementation extracts a genuinely reusable shell/header primitive. Avoid component sprawl for a single page.
- `spec/requests`: primary proof surface for login redirect, protected entry, sign-out access, logout behavior, and post-logout protection.

### File Structure Requirements

Likely implementation touchpoints based on the current app state:

- `config/routes.rb`
- `app/controllers/home_controller.rb`
- `app/views/home/index.html.erb`
- `app/views/layouts/application.html.erb`
- optionally `app/controllers/dashboard_controller.rb`
- optionally `app/views/dashboard/show.html.erb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/concerns/authentication.rb`
- `spec/requests/sessions_spec.rb`
- `spec/requests/workspace_access_spec.rb`
- `spec/requests/root_shell_spec.rb`

Do not introduce a parallel auth frontend, a JavaScript-only logout flow, or a second long-lived landing page whose purpose overlaps with the authenticated workspace entry point.

### UX Requirements to Preserve

- Successful sign-in should land the admin somewhere that immediately feels like the daily operational starting point.
- The authenticated shell should feel calm, structured, serious, and desktop-first rather than promotional or decorative.
- Orientation should be obvious on first paint through clear headings, product identity, and stable layout structure.
- Sign-out access should be visible, explicitly labeled, keyboard reachable, and consistent with the product's action hierarchy.
- The page should remain focused: one strong primary orientation, clear supporting actions, and no clutter that competes with the core entry experience.
- Use semantic headings, readable contrast, visible focus states, and labels or text that do not rely on color alone.

### Testing Requirements

- Use request specs as the default proof style because that is the established auth-testing pattern in this repo.
- Assert that unauthenticated users are redirected away from the protected workspace entry point.
- Assert that an authenticated admin can reach the workspace shell and see clear orientation plus sign-out access.
- Assert that `DELETE /session` removes the server-side session and redirects back to `new_session_path`.
- Assert that a user who has logged out cannot revisit the protected workspace without re-authenticating.
- Keep the return-to redirect behavior for protected routes passing, especially around `/jobs`.
- If touching multiple request specs that need a signed session cookie helper, prefer consolidating shared support instead of creating a third copy.

### Previous Story Intelligence

- Story `1.3` deliberately kept the login work scoped to sign-in UX and left the authenticated landing and logout affordance for this story. Build on that handoff instead of reworking the login page again.
- Story `1.3` confirmed the existing auth flow, admin-only gate, and `after_authentication_url` behavior are worth preserving. This story should add workspace clarity and logout access on top of that baseline.
- Story `1.3` also cleaned up duplicate flash behavior on the login page, so this story should avoid reintroducing fragmented feedback between the layout and authenticated shell.

### Git Intelligence Summary

- Recent commits show a tight auth-focused sequence: `Seed admin access and follow-up fixes.`, `Polish admin login flow and review coverage.`, and `Tighten login form spacing.`.
- Follow the same incremental approach here: finish authenticated entry and logout cleanly without bundling later dashboard widgets or unrelated navigation work.
- Recent changes also show the app already accepts small, focused view and request-spec updates for auth stories; lean on that pattern before introducing larger structural changes.

### Latest Technical Information

- Rails 8's built-in authentication generator remains the correct baseline for this story: `has_secure_password`, a `Session` model persisted in the database, and signed cookie-backed session resumption are still the current Rails-native approach.
- Rails form helpers remain the safest default for logout actions in server-rendered apps because they carry CSRF protection automatically on non-GET requests; prefer that over a plain link that simulates deletion.
- Keep the auth flow conventional and full-page oriented. Turbo or Stimulus enhancements are optional, but they should not obscure the straightforward request/redirect session lifecycle that Rails already provides.

### Project Context Reference

No `project-context.md` file was found in the workspace during story preparation.

### References

- `/_bmad-output/planning-artifacts/epics.md` - Epic 1, Story 1.4, Epic 1 scope
- `/_bmad-output/planning-artifacts/prd.md` - Persona: Admin Operator, Journey 1, Journey 4, FR1-FR3, FR57-FR64, performance and security requirements
- `/_bmad-output/planning-artifacts/architecture.md` - Authentication & Security, Frontend Architecture, Project Structure & Boundaries, Requirements to Structure Mapping
- `/_bmad-output/planning-artifacts/ux-design-specification.md` - Login to Dashboard Landing, Flow Optimization Principles, Button Hierarchy, Navigation Patterns, Accessibility Strategy
- `/_bmad-output/planning-artifacts/ux-wireframes-pages/02-2-dashboard.html` - dashboard shell and top-level orientation reference
- `/_bmad-output/implementation-artifacts/1-3-admin-login-with-clear-feedback.md` - current handoff notes, developer guardrails, and prior auth-story learnings
- `config/routes.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/concerns/authentication.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/home_controller.rb`
- `app/views/home/index.html.erb`
- `app/views/layouts/application.html.erb`
- `spec/requests/sessions_spec.rb`
- `spec/requests/workspace_access_spec.rb`
- `spec/requests/root_shell_spec.rb`
- `spec/requests/mission_control_jobs_access_spec.rb`

## Dev Agent Record

### Agent Model Used

GPT-5.4

### Debug Log References

- Story created from BMad create-story workflow on 2026-03-31T13:01:29+0530
- BMad config loaded from `_bmad/bmm/config.yaml`
- Sprint auto-discovery selected `1-4-authenticated-workspace-entry-and-logout` as the first backlog story
- No `project-context.md` file was found during story preparation
- Prior-story intelligence loaded from `1-3-admin-login-with-clear-feedback.md`
- Planning context gathered from epic, PRD, architecture, UX specification, dashboard wireframe, current auth/workspace code, and recent git history
- Updated sprint tracking to `in-progress` before implementation and to `review` after completion
- Red phase established with focused request specs covering workspace orientation, visible sign-out access, and post-logout protection
- Validation completed with `bundle exec rspec` (23 examples, 0 failures) and targeted auth request-spec runs
- `bundle exec rubocop` reported one pre-existing formatting offense in `Gemfile` unrelated to this story

### Implementation Plan

- Keep the protected `root "home#index"` entry point as the canonical post-login destination and replace the placeholder shell in `app/views/home/index.html.erb`.
- Surface authenticated orientation using real server state (`Current.user`, current date, real available surfaces) and add a visible `button_to` sign-out control backed by `DELETE /session`.
- Extend request coverage for workspace rendering, logout teardown, post-logout protection, and shared signed-session helper reuse without altering the existing auth lifecycle.

### Completion Notes List

- Replaced the protected root placeholder page with a calm authenticated workspace shell that identifies the signed-in admin, exposes current real surfaces, and avoids speculative dashboard metrics.
- Added a visible Rails-native sign-out control using `button_to` and the existing `DELETE /session` route without introducing a competing workspace route or custom logout flow.
- Added focused request coverage for authenticated workspace orientation, visible sign-out access, logout teardown, post-logout protection, and shared signed-session helper reuse.
- Full regression validation passed with `bundle exec rspec`; RuboCop surfaced one unrelated pre-existing Gemfile formatting offense.

### File List

- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/1-4-authenticated-workspace-entry-and-logout.md`
- `app/views/home/index.html.erb`
- `spec/rails_helper.rb`
- `spec/requests/mission_control_jobs_access_spec.rb`
- `spec/requests/root_shell_spec.rb`
- `spec/requests/sessions_spec.rb`
- `spec/requests/workspace_access_spec.rb`
- `spec/support/request_auth_helpers.rb`

## Change Log

- 2026-03-31: Replaced the protected root placeholder with an authenticated workspace shell, added visible sign-out access, consolidated request-session test helpers, and expanded logout/protection request coverage.
