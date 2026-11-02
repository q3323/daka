-- Run this once if class_tasks does not exist yet.

CREATE TABLE IF NOT EXISTS class_tasks (
  id VARCHAR(64) NOT NULL,
  class_id VARCHAR(64) NOT NULL,
  teacher_id VARCHAR(64) NOT NULL,
  content VARCHAR(1000) NOT NULL,
  requires_photo TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY idx_class_tasks_class (class_id, deleted_at),
  KEY idx_class_tasks_teacher (teacher_id, deleted_at),
  CONSTRAINT fk_class_tasks_class FOREIGN KEY (class_id) REFERENCES classes (id),
  CONSTRAINT fk_class_tasks_teacher FOREIGN KEY (teacher_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
