# Daka Backend

Node.js + Express + MySQL backend for the Daka HarmonyOS app.

## Requirements

- Node.js 20 or newer
- MySQL 8.0 or newer
- The database schema in `database/schema.sql`

## Configuration

1. Copy `.env.example` to `.env`.
2. Fill in the values on the Linux server.
3. Do not commit `.env` or expose the database port publicly.

The API port and address are intentionally left blank. They are deployment
values and must not be hardcoded in the client.

## Database

Run the schema against the selected database:

```bash
mysql -u <user> -p <database> < database/schema.sql
```

The app should connect to the API, not directly to MySQL.

If `users` was created from an older schema and does not have a `role` column,
run `database/migrations/001_add_user_role.sql` once before using the API.
If `check_ins` was created before the content field, run
`database/migrations/002_add_check_in_content.sql` once as well.
Run `database/migrations/003_add_class_tasks.sql` if class tasks do not exist.
Run `database/migrations/004_add_check_in_task_id.sql` if check-ins do not have
the task link yet.
Run `database/migrations/005_switch_to_login_id.sql` before switching an old
database to ID-only login.

## Start

```bash
npm install
npm run check
npm start
```

For production, run the service with PM2 or systemd, put Nginx in front of it,
and serve the API over HTTPS.

See `deploy/HTTPS_DEPLOY.md` for domain, Nginx, certificate, and security-group
steps. In production set `BIND_HOST=127.0.0.1` so Node is not exposed directly.

## API

```text
POST   /api/auth/register-id
POST   /api/auth/login-id
GET    /api/auth/me
PUT    /api/auth/me
GET    /api/classes
POST   /api/classes
POST   /api/classes/join
GET    /api/classes/:classId/students
POST   /api/classes/:classId/tasks
GET    /api/classes/:classId/tasks
GET    /api/classes/:classId/tasks/:taskId/submissions
DELETE /api/classes/:classId/tasks/:taskId
DELETE /api/classes/:classId
DELETE /api/classes/:classId/members/:memberId
POST   /api/check-ins
GET    /api/check-ins
GET    /api/check-ins/:checkInId/photo
```

Authentication uses `Authorization: Bearer <token>`.

ID-only login is a temporary development mode. Anyone who knows a login ID can
log in, so add a password, device binding, or another verification factor before
production release.

The first backend version stores check-in photos in MySQL as `LONGBLOB` so the
upload flow can be tested before OBS is ready. Move photo bytes to OBS and keep
only the object key in MySQL before production traffic grows.
