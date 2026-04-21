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

Set `ADMIN_PASSWORD` in `.env` before running setup or seeds. The first email in
`ADMIN_EMAIL_ADDRESSES` is used as the idempotent seeded MVP admin account.
In development and test, `.env` is loaded automatically for `bin/dev`,
`bin/rails`, and other Bundler-backed commands.

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
ADMIN_PASSWORD=
```

The local PostgreSQL container in `compose.yaml` uses the same variables, so the app and container stay aligned.

`ADMIN_EMAIL_ADDRESSES` is a comma-separated allowlist for operators who may access the protected workspace and the mounted Mission Control Jobs UI at `/jobs`.

`ADMIN_PASSWORD` should be set locally or via Rails credentials (`admin.password`) before running `bin/rails db:seed` or `bin/setup`.

## Running with Docker (for testing / handoff)

If you only need to run the application (no local Ruby/Rails install required), you just need **Docker Desktop**.

1. Start the application:

```bash
docker compose -f docker-compose.test.yml up --build
```

2. Open **http://localhost:3000** in your browser.

3. Log in with:

| Field    | Value               |
|----------|---------------------|
| Email    | `admin@example.com` |
| Password | `password123`       |

The first run takes a few minutes to build the image. Subsequent starts are fast.

### Stopping

```bash
docker compose -f docker-compose.test.yml down
```

### Full reset (wipe database and start fresh)

```bash
docker compose -f docker-compose.test.yml down -v
docker compose -f docker-compose.test.yml up --build
```

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
