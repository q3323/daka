let config;
try {
  config = require('./config');
} catch (err) {
  console.error(`[config] ${err.message}`);
  process.exit(1);
}

const express = require('express');
const cors = require('cors');
const authRoutes = require('./routes/auth');
const classRoutes = require('./routes/classes');
const checkInRoutes = require('./routes/checkIns');

const app = express();
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '12mb' }));

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.use('/api/auth', authRoutes);
app.use('/api/classes', classRoutes);
app.use('/api/check-ins', checkInRoutes);

app.use((req, res) => {
  res.status(404).json({ message: '接口不存在' });
});

app.use((err, req, res, next) => {
  console.error(err);
  if (res.headersSent) {
    return next(err);
  }
  return res.status(500).json({ message: '服务器内部错误' });
});

const server = app.listen(config.port, config.bindHost, () => {
  console.log(`Daka API listening on ${config.bindHost}:${config.port}`);
});

function shutdown(signal) {
  console.log(`Received ${signal}, shutting down`);
  server.close(() => process.exit(0));
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
