-- Daka cloud schema for MySQL 8.0+.
-- The application writes data through the backend API, not directly from the client.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(64) NOT NULL,
  login_id VARCHAR(16) NOT NULL,
  nickname VARCHAR(50) NOT NULL DEFAULT '',
  role VARCHAR(16) NOT NULL DEFAULT 'student',
  avatar_url VARCHAR(1024) NOT NULL DEFAULT '',
  timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Shanghai',
  status TINYINT NOT NULL DEFAULT 1,
  last_login_at DATETIME(3) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_users_login_id (login_id),
  CONSTRAINT chk_users_role CHECK (role IN ('student', 'teacher'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS plans (
  id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  name VARCHAR(100) NOT NULL,
  times_per_day INT UNSIGNED NOT NULL DEFAULT 1,
  total_days INT UNSIGNED NOT NULL DEFAULT 7,
  remark VARCHAR(500) NOT NULL DEFAULT '',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  KEY idx_plans_user (user_id, deleted_at),
  CONSTRAINT fk_plans_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT chk_plans_times CHECK (times_per_day BETWEEN 1 AND 20),
  CONSTRAINT chk_plans_days CHECK (total_days BETWEEN 1 AND 365)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS classes (
  id VARCHAR(64) NOT NULL,
  teacher_id VARCHAR(64) NOT NULL,
  name VARCHAR(100) NOT NULL,
  code CHAR(6) NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_classes_code (code),
  KEY idx_classes_teacher (teacher_id, deleted_at),
  CONSTRAINT fk_classes_teacher FOREIGN KEY (teacher_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS class_members (
  id VARCHAR(64) NOT NULL,
  class_id VARCHAR(64) NOT NULL,
  student_id VARCHAR(64) NOT NULL,
  joined_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_class_members (class_id, student_id),
  KEY idx_class_members_student (student_id, deleted_at),
  CONSTRAINT fk_class_members_class FOREIGN KEY (class_id) REFERENCES classes (id),
  CONSTRAINT fk_class_members_student FOREIGN KEY (student_id) REFERENCES users (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS check_ins (
  id VARCHAR(64) NOT NULL,
  user_id VARCHAR(64) NOT NULL,
  plan_id VARCHAR(64) NOT NULL,
  task_id VARCHAR(64) NULL,
  plan_name VARCHAR(100) NOT NULL,
  client_record_id VARCHAR(64) NULL,
  checkin_time DATETIME(3) NOT NULL,
  day_key CHAR(10) NOT NULL,
  photo_url VARCHAR(1024) NOT NULL DEFAULT '',
  content VARCHAR(500) NOT NULL DEFAULT '',
  point DECIMAL(8, 2) NOT NULL DEFAULT 0,
  kind VARCHAR(16) NOT NULL DEFAULT 'add',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at DATETIME(3) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_check_ins_client (user_id, client_record_id),
  KEY idx_check_ins_task (task_id, deleted_at),
  KEY idx_check_ins_user_day (user_id, day_key, deleted_at),
  KEY idx_check_ins_plan (plan_id, deleted_at),
  KEY idx_check_ins_time (user_id, checkin_time),
  CONSTRAINT fk_check_ins_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_check_ins_plan FOREIGN KEY (plan_id) REFERENCES plans (id),
  CONSTRAINT fk_check_ins_task FOREIGN KEY (task_id) REFERENCES class_tasks (id),
  CONSTRAINT chk_check_ins_kind CHECK (kind IN ('add', 'cut'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS check_in_photos (
  id VARCHAR(64) NOT NULL,
  check_in_id VARCHAR(64) NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  data LONGBLOB NOT NULL,
  object_key VARCHAR(512) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_check_in_photos_check_in (check_in_id),
  CONSTRAINT fk_check_in_photos_check_in
    FOREIGN KEY (check_in_id) REFERENCES check_ins (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
