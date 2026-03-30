# lending_rails

Rails 8 lending operations foundation with PostgreSQL, Tailwind, Rails-native authentication, `Pundit`, `PaperTrail`, `Solid Queue`, `Solid Cache`, and `shadcn-rails`.

## Prerequisites

- Ruby `4.0.1`
- Bundler
- Docker with Docker Compose available

## Local Setup

1. Create a local env file from the example:

```bash
cp .env.example .env
```

2. Start PostgreSQL:

```bash
docker compose up -d postgres
```

3. Install gems and prepare the database:

```bash
bin/setup --skip-server
```

4. Start the Rails app:

```bash
bin/dev
```

## Database Configuration

The app reads local database settings from environment variables, with Docker-friendly defaults documented in `.env.example`:

```bash
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
DB_NAME=lending_rails_development
DB_TEST_NAME=lending_rails_test
ADMIN_EMAIL_ADDRESSES=admin@example.com
```

The local PostgreSQL container in `compose.yaml` uses the same variables, so the app and container stay aligned.

`ADMIN_EMAIL_ADDRESSES` is a comma-separated allowlist for operators who may access the mounted Mission Control Jobs UI at `/jobs`.

## Common Commands

Prepare the database:

```bash
bin/rails db:prepare
```

Run the test suite:

```bash
bundle exec rspec
```

Run linting:

```bash
bundle exec rubocop
```

Run the security scan:

```bash
bundle exec brakeman --no-pager
```

Run the consolidated CI-style local check:

```bash
bin/ci
```
