-- Remove all application data while keeping the database schema intact.
-- Run only against the Daka development database.

START TRANSACTION;

DELETE FROM check_in_photos;
DELETE FROM check_ins;
DELETE FROM class_members;
DELETE FROM class_tasks;
DELETE FROM classes;
DELETE FROM plans;
DELETE FROM users;

COMMIT;
