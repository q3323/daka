const express = require('express');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { requireAuth } = require('../auth');
const {
  asyncHandler,
  cleanText,
  createPhotoUrl,
  dayKeyOf,
  verifyPhotoSignature
} = require('../utils');

const router = express.Router();
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const MAX_BASE64_LENGTH = Math.ceil(MAX_PHOTO_BYTES * 4 / 3) + 2048;

function parsePhoto(body) {
  const raw = typeof body.photoBase64 === 'string' ? body.photoBase64.trim() : '';
  if (raw.length === 0) {
    return { mimeType: '', buffer: null };
  }
  if (raw.length > MAX_BASE64_LENGTH) {
    return { error: '照片不能超过 5MB' };
  }

  let mimeType = cleanText(body.photoMimeType, 100) || 'image/jpeg';
  let base64 = raw;
  const dataUrl = raw.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.*)$/s);
  if (dataUrl) {
    mimeType = dataUrl[1];
    base64 = dataUrl[2];
  }
  if (!mimeType.startsWith('image/')) {
    return { error: '只支持图片文件' };
  }

  const buffer = Buffer.from(base64, 'base64');
  if (buffer.length === 0) {
    return { error: '照片数据为空' };
  }
  if (buffer.length > MAX_PHOTO_BYTES) {
    return { error: '照片不能超过 5MB' };
  }
  return { mimeType, buffer };
}

function mapCheckIn(row) {
  return {
    id: row.id,
    planId: row.planId,
    taskId: row.taskId,
    planName: row.planName,
    clientRecordId: row.clientRecordId,
    checkinTime: row.checkinTime,
    dayKey: row.dayKey,
    photoUrl: row.photoUrl ? createPhotoUrl(row.id) : '',
    content: row.content,
    point: Number(row.point),
    kind: row.kind
  };
}

router.use((req, res, next) => {
  if (req.method === 'GET' && /^\/[^/]+\/photo$/.test(req.path)) {
    const expires = req.query.expires;
    const signature = req.query.signature;
    const match = req.path.match(/^\/([^/]+)\/photo$/);
    if (match && verifyPhotoSignature(match[1], expires, signature)) {
      req.photoAccess = true;
      return next();
    }
  }
  return requireAuth(req, res, next);
});

router.post('/', asyncHandler(async (req, res) => {
  const body = req.body || {};
  const plan = body.plan || {};
  const planId = cleanText(plan.id, 64);
  const planName = cleanText(plan.name, 100);
  const taskId = cleanText(body.taskId, 64);
  const timesPerDay = Number(plan.timesPerDay);
  const totalDays = Number(plan.totalDays);
  const remark = cleanText(plan.remark, 500);
  const clientRecordId = cleanText(body.clientRecordId, 64);
  const content = cleanText(body.content, 500);
  const checkinTime = Number(body.checkinTime) || Date.now();
  const kind = body.kind === 'cut' ? 'cut' : 'add';

  if (!planId || !planName) {
    return res.status(400).json({ message: '缺少计划信息' });
  }
  if (!Number.isInteger(timesPerDay) || timesPerDay < 1 || timesPerDay > 20) {
    return res.status(400).json({ message: '每天打卡次数不正确' });
  }
  if (!Number.isInteger(totalDays) || totalDays < 1 || totalDays > 365) {
    return res.status(400).json({ message: '打卡天数不正确' });
  }
  if (!clientRecordId) {
    return res.status(400).json({ message: '缺少客户端记录号' });
  }
  if (!Number.isFinite(checkinTime)) {
    return res.status(400).json({ message: '打卡时间不正确' });
  }

  const photo = parsePhoto(body);
  if (photo.error) {
    return res.status(413).json({ message: photo.error });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const [existingRows] = await connection.execute(
      `SELECT id, plan_id AS planId, task_id AS taskId, plan_name AS planName,
              client_record_id AS clientRecordId, checkin_time AS checkinTime,
              day_key AS dayKey, photo_url AS photoUrl, content, point, kind
       FROM check_ins
       WHERE user_id = ? AND client_record_id = ?
       LIMIT 1`,
      [req.user.id, clientRecordId]
    );
    if (existingRows.length > 0) {
      await connection.commit();
      return res.json({ checkIn: mapCheckIn(existingRows[0]), duplicated: true });
    }

    if (taskId.length > 0) {
      const [taskRows] = await connection.execute(
        `SELECT t.id
         FROM class_tasks t
         JOIN class_members cm ON cm.class_id = t.class_id
         WHERE t.id = ? AND cm.student_id = ?
           AND t.deleted_at IS NULL AND cm.deleted_at IS NULL
         LIMIT 1`,
        [taskId, req.user.id]
      );
      if (taskRows.length === 0) {
        await connection.rollback();
        return res.status(403).json({ message: '任务不存在或无权提交' });
      }
      const [taskRecordRows] = await connection.execute(
        `SELECT id
         FROM check_ins
         WHERE user_id = ? AND task_id = ? AND kind = 'add' AND deleted_at IS NULL
         LIMIT 1`,
        [req.user.id, taskId]
      );
      if (taskRecordRows.length > 0) {
        await connection.rollback();
        return res.status(409).json({ message: '这个任务已经提交过了' });
      }
    }

    const [planOwnerRows] = await connection.execute(
      'SELECT user_id FROM plans WHERE id = ? LIMIT 1',
      [planId]
    );
    if (planOwnerRows.length > 0 && planOwnerRows[0].user_id !== req.user.id) {
      await connection.rollback();
      return res.status(409).json({ message: '计划编号冲突' });
    }

    await connection.execute(
      `INSERT INTO plans (id, user_id, name, times_per_day, total_days, remark)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE
         name = VALUES(name),
         times_per_day = VALUES(times_per_day),
         total_days = VALUES(total_days),
         remark = VALUES(remark),
         deleted_at = NULL`,
      [planId, req.user.id, planName, timesPerDay, totalDays, remark]
    );

    let point = Number(body.point);
    if (!Number.isFinite(point)) {
      const [requiredRows] = await connection.execute(
        `SELECT COALESCE(SUM(times_per_day * total_days), 0) AS required
         FROM plans
         WHERE user_id = ? AND deleted_at IS NULL`,
        [req.user.id]
      );
      const required = Number(requiredRows[0].required);
      point = required > 0 ? Math.round((100 / required) * 100) / 100 : 0;
    }
    if (kind === 'cut') {
      point = -Math.abs(point);
    } else {
      point = Math.abs(point);
    }
    point = Math.round(point * 100) / 100;

    const checkInId = randomUUID();
    const dayKey = dayKeyOf(checkinTime);
    await connection.execute(
      `INSERT INTO check_ins
       (id, user_id, plan_id, task_id, plan_name, client_record_id, checkin_time,
        day_key, photo_url, content, point, kind)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        checkInId,
        req.user.id,
        planId,
        taskId.length > 0 ? taskId : null,
        planName,
        clientRecordId,
        new Date(checkinTime),
        dayKey,
        '',
        content,
        point,
        kind
      ]
    );

    let photoUrl = '';
    if (photo.buffer) {
      await connection.execute(
        `INSERT INTO check_in_photos (id, check_in_id, mime_type, data)
         VALUES (?, ?, ?, ?)`,
        [randomUUID(), checkInId, photo.mimeType, photo.buffer]
      );
      photoUrl = `/api/check-ins/${checkInId}/photo`;
      await connection.execute(
        'UPDATE check_ins SET photo_url = ? WHERE id = ?',
        [photoUrl, checkInId]
      );
    }

    await connection.commit();
    return res.status(201).json({
      checkIn: {
        id: checkInId,
        planId,
        taskId,
        planName,
        clientRecordId,
        checkinTime: new Date(checkinTime).toISOString(),
        dayKey,
        photoUrl: photoUrl.length > 0 ? createPhotoUrl(checkInId) : '',
        content,
        point,
        kind
      }
    });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}));

router.get('/', asyncHandler(async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT id, plan_id AS planId, task_id AS taskId, plan_name AS planName,
            client_record_id AS clientRecordId, checkin_time AS checkinTime,
            day_key AS dayKey, photo_url AS photoUrl, content, point, kind
     FROM check_ins
     WHERE user_id = ? AND deleted_at IS NULL
     ORDER BY checkin_time DESC
     LIMIT 200`,
    [req.user.id]
  );
  return res.json({ checkIns: rows.map(mapCheckIn) });
}));

router.get('/:checkInId/photo', asyncHandler(async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT p.mime_type, p.data, ci.user_id
     FROM check_in_photos p
     JOIN check_ins ci ON ci.id = p.check_in_id
     WHERE p.check_in_id = ?
     LIMIT 1`,
    [req.params.checkInId]
  );
  if (rows.length === 0) {
    return res.status(404).json({ message: '照片不存在' });
  }

  const photo = rows[0];
  if (!req.photoAccess && photo.user_id !== req.user.id) {
    if (req.user.role !== 'teacher') {
      return res.status(403).json({ message: '无权查看该照片' });
    }
    const [accessRows] = await pool.execute(
      `SELECT 1
       FROM class_members cm
       JOIN classes c ON c.id = cm.class_id
       WHERE cm.student_id = ?
         AND c.teacher_id = ?
         AND cm.deleted_at IS NULL
         AND c.deleted_at IS NULL
       LIMIT 1`,
      [photo.user_id, req.user.id]
    );
    if (accessRows.length === 0) {
      return res.status(403).json({ message: '无权查看该照片' });
    }
  }

  res.setHeader('Content-Type', photo.mime_type);
  res.setHeader('Cache-Control', 'private, max-age=3600');
  return res.send(photo.data);
}));

module.exports = router;
