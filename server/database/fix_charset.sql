-- Convert the Daka database and all text columns to utf8mb4.
-- Back up the database before running this script.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

ALTER DATABASE daka
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

ALTER TABLE users
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE plans
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE classes
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE class_members
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE class_tasks
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE check_ins
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE check_in_photos
  CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
