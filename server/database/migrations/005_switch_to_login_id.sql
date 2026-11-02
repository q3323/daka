-- Run once when upgrading a users table that still uses phone/password login.
-- The old phone/password columns are left untouched for data safety, but the
-- application no longer reads them.

ALTER TABLE users
  ADD COLUMN login_id VARCHAR(16) NULL AFTER id,
  ADD UNIQUE KEY uk_users_login_id (login_id);
