const crypto = require('crypto');
const config = require('./config');

function asyncHandler(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

/** The app currently treats China Standard Time as the day boundary. */
function dayKeyOf(value) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(new Date(value));
  const values = {};
  for (const part of parts) {
    if (part.type !== 'literal') {
      values[part.type] = part.value;
    }
  }
  return `${values.year}-${values.month}-${values.day}`;
}

function todayKey() {
  return dayKeyOf(Date.now());
}

function cleanText(value, maxLength) {
  if (typeof value !== 'string') {
    return '';
  }
  return value.trim().slice(0, maxLength);
}

const PHOTO_URL_TTL_MS = 60 * 60 * 1000;

function photoSignature(checkInId, expires) {
  return crypto
    .createHmac('sha256', config.jwtSecret)
    .update(`${checkInId}:${expires}`)
    .digest('hex');
}

function createPhotoUrl(checkInId) {
  if (!checkInId) {
    return '';
  }
  // Keep the URL stable inside each hour so client refreshes do not refetch the image.
  const expires = Math.ceil((Date.now() + 5 * 60 * 1000) / PHOTO_URL_TTL_MS) * PHOTO_URL_TTL_MS;
  const signature = photoSignature(checkInId, expires);
  return `/api/check-ins/${checkInId}/photo?expires=${expires}&signature=${signature}`;
}

function verifyPhotoSignature(checkInId, expiresValue, signatureValue) {
  const expires = Number(expiresValue);
  const signature = typeof signatureValue === 'string' ? signatureValue : '';
  if (!Number.isFinite(expires) || expires < Date.now() || !signature) {
    return false;
  }
  const expected = photoSignature(checkInId, expires);
  const providedBuffer = Buffer.from(signature);
  const expectedBuffer = Buffer.from(expected);
  return providedBuffer.length === expectedBuffer.length
    && crypto.timingSafeEqual(providedBuffer, expectedBuffer);
}

module.exports = {
  asyncHandler,
  dayKeyOf,
  todayKey,
  cleanText,
  createPhotoUrl,
  verifyPhotoSignature
};
