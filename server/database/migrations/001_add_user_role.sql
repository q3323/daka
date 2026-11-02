-- Run this once only if the users table was created before the role field existed.
-- Fresh databases should use database/schema.sql directly.

ALTER TABLE users
  ADD COLUMN role VARCHAR(16) NOT NULL DEFAULT 'student' AFTER nickname,
  ADD CONSTRAINT chk_users_role CHECK (role IN ('student', 'teacher'));
