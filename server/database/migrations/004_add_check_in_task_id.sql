-- Run this once if check_ins was created before tasks were linked to check-ins.

ALTER TABLE check_ins
  ADD COLUMN task_id VARCHAR(64) NULL AFTER plan_id,
  ADD KEY idx_check_ins_task (task_id, deleted_at),
  ADD CONSTRAINT fk_check_ins_task
    FOREIGN KEY (task_id) REFERENCES class_tasks (id);
