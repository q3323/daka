const express = require('express');
const { randomInt, randomUUID } = require('crypto');
const pool = require('../db');
const { requireAuth, requireRole } = require('../auth');
const { asyncHandler, cleanText, createPhotoUrl, todayKey } = require('../utils');

const router = express.Router();

async function generateClassCode() {
  for (let attempt = 0; attempt < 30; attempt++) {
    const code = String(randomInt(100000, 1000000));
    const [rows] = await pool.execute(
      'SELECT id FROM classes WHERE code = ? LIMIT 1',
      [code]
    );
    if (rows.length === 0) {
      return code;
    }
  }
  throw new Error('Unable to generate a unique class code');
}

router.use(requireAuth);

router.post('/', requireRole('teacher'), asyncHandler(async (req, res) => {
  const name = cleanText(req.body.name, 100);
  if (name.length === 0) {
    return res.status(400).json({ message: '请输入班级名称' });
  }

  const id = randomUUID();
  const code = await generateClassCode();
  await pool.execute(
    'INSERT INTO classes (id, teacher_id, name, code) VALUES (?, ?, ?, ?)',
    [id, req.user.id, name, code]
  );

  return res.status(201).json({
    class: {
      id,
      name,
      code,
      memberCount: 0
    }
  });
}));

router.get('/', asyncHandler(async (req, res) => {
  if (req.user.role === 'teacher') {
    const [rows] = await pool.execute(
      `SELECT c.id, c.name, c.code, c.created_at AS createdAt,
              (SELECT COUNT(*) FROM class_members cm
               WHERE cm.class_id = c.id AND cm.deleted_at IS NULL) AS memberCount
       FROM classes c
       WHERE c.teacher_id = ? AND c.deleted_at IS NULL
       ORDER BY c.created_at DESC`,
      [req.user.id]
    );
    return res.json({
      classes: rows.map((row) => ({
        ...row,
        memberCount: Number(row.memberCount)
      }))
    });
  }

  const [rows] = await pool.execute(
    `SELECT c.id, c.name, c.code, c.created_at AS createdAt,
            (SELECT COUNT(*) FROM class_members cm2
             WHERE cm2.class_id = c.id AND cm2.deleted_at IS NULL) AS memberCount
     FROM classes c
     JOIN class_members cm ON cm.class_id = c.id
     WHERE cm.student_id = ? AND cm.deleted_at IS NULL AND c.deleted_at IS NULL
     ORDER BY cm.joined_at DESC`,
    [req.user.id]
  );
  return res.json({
    classes: rows.map((row) => ({
      ...row,
      memberCount: Number(row.memberCount)
    }))
  });
}));

router.post('/join', requireRole('student'), asyncHandler(async (req, res) => {
  const code = cleanText(req.body.code, 6);
  if (!/^[0-9]{6}$/.test(code)) {
    return res.status(400).json({ message: '班级号格式不正确' });
  }

  const [classRows] = await pool.execute(
    'SELECT id, name, code FROM classes WHERE code = ? AND deleted_at IS NULL LIMIT 1',
    [code]
  );
  const target = classRows[0];
  if (!target) {
    return res.status(404).json({ message: '班级号不存在' });
  }

  const [existingRows] = await pool.execute(
    `SELECT id, deleted_at
     FROM class_members
     WHERE class_id = ? AND student_id = ?
     LIMIT 1`,
    [target.id, req.user.id]
  );
  const existing = existingRows[0];

  if (existing && !existing.deleted_at) {
    return res.status(409).json({ message: '你已经加入该班级' });
  }

  if (existing) {
    await pool.execute(
      'UPDATE class_members SET deleted_at = NULL, joined_at = NOW(3) WHERE id = ?',
      [existing.id]
    );
  } else {
    await pool.execute(
      'INSERT INTO class_members (id, class_id, student_id) VALUES (?, ?, ?)',
      [randomUUID(), target.id, req.user.id]
    );
  }

  const [countRows] = await pool.execute(
    'SELECT COUNT(*) AS memberCount FROM class_members WHERE class_id = ? AND deleted_at IS NULL',
    [target.id]
  );

  return res.json({
    class: {
      id: target.id,
      name: target.name,
      code: target.code,
      memberCount: Number(countRows[0].memberCount)
    }
  });
}));

router.get('/:classId/students', requireRole('teacher'), asyncHandler(async (req, res) => {
  const [classRows] = await pool.execute(
    `SELECT id, name, code
     FROM classes
     WHERE id = ? AND teacher_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [req.params.classId, req.user.id]
  );
  if (classRows.length === 0) {
    return res.status(404).json({ message: '班级不存在或无权查看' });
  }

  const key = todayKey();
  const [rows] = await pool.execute(
    `SELECT cm.id AS memberId, u.id AS userId, u.nickname,
            cm.joined_at AS joinedAt,
            COUNT(ci.id) AS totalCount,
            COUNT(CASE WHEN ci.day_key = ? THEN ci.id END) AS todayCount,
            MAX(ci.checkin_time) AS lastCheckInAt
     FROM class_members cm
     JOIN users u ON u.id = cm.student_id
     LEFT JOIN check_ins ci
       ON ci.user_id = u.id AND ci.kind = 'add' AND ci.deleted_at IS NULL
     WHERE cm.class_id = ? AND cm.deleted_at IS NULL
     GROUP BY cm.id, u.id, u.nickname, cm.joined_at
     ORDER BY cm.joined_at ASC`,
    [key, req.params.classId]
  );

  return res.json({
    class: classRows[0],
    todayKey: key,
    students: rows.map((row) => ({
      memberId: row.memberId,
      userId: row.userId,
      name: row.nickname,
      joinedAt: row.joinedAt,
      todayCount: Number(row.todayCount),
      totalCount: Number(row.totalCount),
      lastCheckInAt: row.lastCheckInAt
    }))
  });
}));

router.post('/:classId/tasks', requireRole('teacher'), asyncHandler(async (req, res) => {
  const content = cleanText(req.body.content, 1000);
  const requiresPhoto = req.body.requiresPhoto !== false;
  if (content.length === 0) {
    return res.status(400).json({ message: '请输入任务内容' });
  }

  const [classRows] = await pool.execute(
    `SELECT id
     FROM classes
     WHERE id = ? AND teacher_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [req.params.classId, req.user.id]
  );
  if (classRows.length === 0) {
    return res.status(404).json({ message: '班级不存在或无权发布任务' });
  }

  const id = randomUUID();
  await pool.execute(
    `INSERT INTO class_tasks (id, class_id, teacher_id, content, requires_photo)
     VALUES (?, ?, ?, ?, ?)`,
    [id, req.params.classId, req.user.id, content, requiresPhoto ? 1 : 0]
  );
  const [countRows] = await pool.execute(
    'SELECT COUNT(*) AS memberCount FROM class_members WHERE class_id = ? AND deleted_at IS NULL',
    [req.params.classId]
  );
  return res.status(201).json({
    task: {
      id,
      classId: req.params.classId,
      content,
      requiresPhoto,
      completedCount: 0,
      memberCount: Number(countRows[0].memberCount),
      createdAt: new Date().toISOString()
    }
  });
}));

router.get('/:classId/tasks', asyncHandler(async (req, res) => {
  let allowed = false;
  if (req.user.role === 'teacher') {
    const [rows] = await pool.execute(
      `SELECT id FROM classes
       WHERE id = ? AND teacher_id = ? AND deleted_at IS NULL
       LIMIT 1`,
      [req.params.classId, req.user.id]
    );
    allowed = rows.length > 0;
  } else {
    const [rows] = await pool.execute(
      `SELECT c.id
       FROM classes c
       JOIN class_members cm ON cm.class_id = c.id
       WHERE c.id = ? AND cm.student_id = ?
         AND cm.deleted_at IS NULL AND c.deleted_at IS NULL
       LIMIT 1`,
      [req.params.classId, req.user.id]
    );
    allowed = rows.length > 0;
  }
  if (!allowed) {
    return res.status(404).json({ message: '班级不存在或无权查看' });
  }

  const [rows] = await pool.execute(
    `SELECT t.id, t.class_id AS classId, t.content,
            t.requires_photo AS requiresPhoto, t.created_at AS createdAt,
            (SELECT COUNT(*) FROM class_members cm
             WHERE cm.class_id = t.class_id AND cm.deleted_at IS NULL) AS memberCount,
            (SELECT COUNT(DISTINCT ci.user_id) FROM check_ins ci
             WHERE ci.task_id = t.id AND ci.kind = 'add' AND ci.deleted_at IS NULL)
              AS completedCount
     FROM class_tasks t
     WHERE t.class_id = ? AND t.deleted_at IS NULL
     ORDER BY t.created_at DESC`,
    [req.params.classId]
  );
  return res.json({
    tasks: rows.map((row) => ({
      id: row.id,
      classId: row.classId,
      content: row.content,
      requiresPhoto: Boolean(row.requiresPhoto),
      completedCount: Number(row.completedCount),
      memberCount: Number(row.memberCount),
      createdAt: row.createdAt
    }))
  });
}));

router.get('/:classId/tasks/:taskId/submissions', requireRole('teacher'), asyncHandler(async (req, res) => {
  const [classRows] = await pool.execute(
    `SELECT id, name, code
     FROM classes
     WHERE id = ? AND teacher_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [req.params.classId, req.user.id]
  );
  if (classRows.length === 0) {
    return res.status(404).json({ message: '班级不存在或无权查看' });
  }

  const [taskRows] = await pool.execute(
    `SELECT id, class_id AS classId, content,
            requires_photo AS requiresPhoto, created_at AS createdAt
     FROM class_tasks
     WHERE id = ? AND class_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [req.params.taskId, req.params.classId]
  );
  if (taskRows.length === 0) {
    return res.status(404).json({ message: '任务不存在' });
  }

  const [rows] = await pool.execute(
    `SELECT cm.id AS memberId, u.id AS userId, u.nickname AS name,
            cm.joined_at AS joinedAt,
            ci.id AS checkInId, ci.checkin_time AS checkinTime,
            ci.day_key AS dayKey, ci.content, ci.photo_url AS photoUrl
     FROM class_members cm
     JOIN users u ON u.id = cm.student_id
     LEFT JOIN check_ins ci ON ci.id = (
       SELECT ci2.id
       FROM check_ins ci2
       WHERE ci2.user_id = u.id
         AND ci2.task_id = ?
         AND ci2.kind = 'add'
         AND ci2.deleted_at IS NULL
       ORDER BY ci2.checkin_time DESC
       LIMIT 1
     )
     WHERE cm.class_id = ? AND cm.deleted_at IS NULL
     ORDER BY (ci.id IS NULL) DESC, cm.joined_at ASC`,
    [req.params.taskId, req.params.classId]
  );

  return res.json({
    class: classRows[0],
    task: {
      id: taskRows[0].id,
      classId: taskRows[0].classId,
      content: taskRows[0].content,
      requiresPhoto: Boolean(taskRows[0].requiresPhoto),
      createdAt: taskRows[0].createdAt
    },
    members: rows.map((row) => ({
      memberId: row.memberId,
      userId: row.userId,
      name: row.name,
      completed: Boolean(row.checkInId),
      checkInId: row.checkInId || '',
      checkinTime: row.checkinTime,
      dayKey: row.dayKey || '',
      content: row.content || '',
      photoUrl: row.photoUrl ? createPhotoUrl(row.checkInId) : '',
      joinedAt: row.joinedAt
    }))
  });
}));

router.delete('/:classId/tasks/:taskId', requireRole('teacher'), asyncHandler(async (req, res) => {
  const [classRows] = await pool.execute(
    `SELECT id
     FROM classes
     WHERE id = ? AND teacher_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [req.params.classId, req.user.id]
  );
  if (classRows.length === 0) {
    return res.status(404).json({ message: '班级不存在或无权删除任务' });
  }

  const [result] = await pool.execute(
    `UPDATE class_tasks
     SET deleted_at = NOW(3)
     WHERE id = ? AND class_id = ? AND deleted_at IS NULL`,
    [req.params.taskId, req.params.classId]
  );
  if (result.affectedRows === 0) {
    return res.status(404).json({ message: '任务不存在' });
  }
  return res.json({ ok: true });
}));

router.delete('/:classId', requireRole('teacher'), asyncHandler(async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();
    const [classRows] = await connection.execute(
      `SELECT id
       FROM classes
       WHERE id = ? AND teacher_id = ? AND deleted_at IS NULL
       FOR UPDATE`,
      [req.params.classId, req.user.id]
    );
    if (classRows.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: '班级不存在或无权删除' });
    }

    await connection.execute(
      `UPDATE class_members
       SET deleted_at = NOW(3)
       WHERE class_id = ? AND deleted_at IS NULL`,
      [req.params.classId]
    );
    await connection.execute(
      `UPDATE class_tasks
       SET deleted_at = NOW(3)
       WHERE class_id = ? AND deleted_at IS NULL`,
      [req.params.classId]
    );
    await connection.execute(
      'UPDATE classes SET deleted_at = NOW(3) WHERE id = ?',
      [req.params.classId]
    );
    await connection.commit();
    return res.json({ ok: true });
  } catch (err) {
    await connection.rollback();
    throw err;
  } finally {
    connection.release();
  }
}));

router.delete('/:classId/members/:memberId', requireRole('teacher'), asyncHandler(async (req, res) => {
  const [classRows] = await pool.execute(
    `SELECT id
     FROM classes
     WHERE id = ? AND teacher_id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [req.params.classId, req.user.id]
  );
  if (classRows.length === 0) {
    return res.status(404).json({ message: '班级不存在或无权操作' });
  }

  const [result] = await pool.execute(
    `UPDATE class_members
     SET deleted_at = NOW(3)
     WHERE id = ? AND class_id = ? AND deleted_at IS NULL`,
    [req.params.memberId, req.params.classId]
  );
  if (result.affectedRows === 0) {
    return res.status(404).json({ message: '学生不存在' });
  }

  return res.json({ ok: true });
}));

module.exports = router;
