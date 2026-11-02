-- Run this once only if check_ins was created before the content field existed.

ALTER TABLE check_ins
  ADD COLUMN content VARCHAR(500) NOT NULL DEFAULT '' AFTER photo_url;
