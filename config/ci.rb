# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bundle exec rubocop"

  step "Security: Brakeman code analysis", "bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: Prepare database", "env RAILS_ENV=test bin/rails db:prepare"
  step "Tests: RSpec", "bundle exec rspec"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
