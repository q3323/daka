const express = require('express');
const { randomUUID } = require('crypto');
const pool = require('../db');
const { signToken, requireAuth } = require('../auth');
const { asyncHandler, cleanText } = require('../utils');

const router = express.Router();
const LOGIN_ID_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const LOGIN_ID_PATTERN = /^DK-[A-Z2-9]{6}$/;

function createLoginIdCandidate() {
  let value = 'DK-';
  for (let i = 0; i < 6; i++) {
    value += LOGIN_ID_CHARS.charAt(Math.floor(Math.random() * LOGIN_ID_CHARS.length));
  }
  return value;
}

async function generateLoginId() {
  for (let attempt = 0; attempt < 30; attempt++) {
    const candidate = createLoginIdCandidate();
    const [rows] = await pool.execute(
      'SELECT id FROM users WHERE login_id = ? LIMIT 1',
      [candidate]
    );
    if (rows.length === 0) {
      return candidate;
    }
  }
  throw new Error('Unable to generate a unique login ID');
}

router.post('/register-id', asyncHandler(async (req, res) => {
  const nickname = cleanText(req.body.nickname, 50);
  const role = req.body.role === 'teacher' ? 'teacher' : 'student';
  if (nickname.length === 0) {
    return res.status(400).json({ message: '请输入昵称' });
  }

  const id = randomUUID();
  const loginId = await generateLoginId();
  await pool.execute(
    'INSERT INTO users (id, login_id, nickname, role) VALUES (?, ?, ?, ?)',
    [id, loginId, nickname, role]
  );

  return res.status(201).json({
    token: signToken({ id, role }),
    user: { id, loginId, nickname, role }
  });
}));

router.post('/login-id', asyncHandler(async (req, res) => {
  const loginId = cleanText(req.body.loginId, 16).toUpperCase();
  if (!LOGIN_ID_PATTERN.test(loginId)) {
    return res.status(400).json({ message: '登录 ID 格式不正确' });
  }

  const [rows] = await pool.execute(
    `SELECT id, login_id AS loginId, nickname, role, status, deleted_at
     FROM users
     WHERE login_id = ?
     LIMIT 1`,
    [loginId]
  );
  const user = rows[0];
  if (!user || user.status !== 1 || user.deleted_at) {
    return res.status(401).json({ message: 'ID 不存在' });
  }

  await pool.execute(
    'UPDATE users SET last_login_at = NOW(3) WHERE id = ?',
    [user.id]
  );

  return res.json({
    token: signToken({ id: user.id, role: user.role }),
    user: {
      id: user.id,
      loginId: user.loginId,
      nickname: user.nickname,
      role: user.role
    }
  });
}));

router.get('/me', requireAuth, asyncHandler(async (req, res) => {
  const [rows] = await pool.execute(
    `SELECT id, login_id AS loginId, nickname, role, avatar_url, created_at
     FROM users
     WHERE id = ? AND deleted_at IS NULL
     LIMIT 1`,
    [req.user.id]
  );
  if (rows.length === 0) {
    return res.status(404).json({ message: '用户不存在' });
  }
  return res.json({ user: rows[0] });
}));

router.put('/me', requireAuth, asyncHandler(async (req, res) => {
  const nickname = cleanText(req.body.nickname, 50);
  if (nickname.length === 0) {
    return res.status(400).json({ message: '请输入昵称' });
  }
  const [result] = await pool.execute(
    'UPDATE users SET nickname = ? WHERE id = ? AND deleted_at IS NULL',
    [nickname, req.user.id]
  );
  if (result.affectedRows === 0) {
    return res.status(404).json({ message: '用户不存在' });
  }
  return res.json({ user: { id: req.user.id, nickname: nickname } });
}));

module.exports = router;
