import 'dotenv/config';
import bcrypt from 'bcryptjs';
import cors from 'cors';
import express from 'express';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 3000);
const jwtSecret = process.env.JWT_SECRET || 'development-only-change-me-before-deploying';
const dataPath = path.join(__dirname, 'data', 'store.json');
const uploadPath = path.join(__dirname, 'uploads');
const maxRecordingSize = Number(process.env.MAX_RECORDING_SIZE_MB || 25) * 1024 * 1024;

await mkdir(path.dirname(dataPath), { recursive: true });
await mkdir(uploadPath, { recursive: true });

async function loadStore() {
  try {
    return JSON.parse(await readFile(dataPath, 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    return { users: [], contacts: [], calls: [], recordings: [], spamReports: [], notifications: [] };
  }
}

let store = await loadStore();
let saving = Promise.resolve();
function persist() {
  saving = saving.then(async () => {
    const temporaryPath = `${dataPath}.${randomUUID()}.tmp`;
    await writeFile(temporaryPath, JSON.stringify(store, null, 2));
    await rename(temporaryPath, dataPath);
  });
  return saving;
}

const app = express();
app.disable('x-powered-by');
app.use(cors());
app.use(express.json({ limit: '1mb' }));

function publicUser(user) {
  return { id: user.id, email: user.email, name: user.name, createdAt: user.createdAt };
}
function tokenFor(user) {
  return jwt.sign({ sub: user.id, email: user.email }, jwtSecret, { expiresIn: '7d' });
}
function authenticate(req, res, next) {
  const token = req.get('authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return res.status(401).json({ error: 'Authentication is required.' });
  try {
    const payload = jwt.verify(token, jwtSecret);
    req.user = store.users.find((user) => user.id === payload.sub);
    if (!req.user) return res.status(401).json({ error: 'Session is no longer valid.' });
    return next();
  } catch (_) {
    return res.status(401).json({ error: 'Session is invalid or expired.' });
  }
}
function own(items, userId) { return items.filter((item) => item.userId === userId); }
function validateCall(body) {
  const name = String(body.name || '').trim();
  const phone = String(body.phone || '').trim();
  const type = String(body.type || 'incoming');
  const durationSeconds = Number(body.durationSeconds || 0);
  const date = new Date(body.date || Date.now());
  if (!name || !phone || !['incoming', 'outgoing', 'missed'].includes(type)) return 'Provide a name, phone number, and valid call type.';
  if (!Number.isInteger(durationSeconds) || durationSeconds < 0 || Number.isNaN(date.valueOf())) return 'Provide a valid duration and call date.';
  return null;
}
function dateRange(value, end = false) {
  if (!value) return null;
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.valueOf())) return null;
  if (end) date.setUTCDate(date.getUTCDate() + 1);
  return date;
}

app.get('/health', (_, res) => res.json({ ok: true }));
app.post('/api/auth/register', async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  const name = String(req.body.name || '').trim();
  const password = String(req.body.password || '');
  if (!/^\S+@\S+\.\S+$/.test(email) || !name || password.length < 8) return res.status(400).json({ error: 'Use a name, valid email, and password of at least 8 characters.' });
  if (store.users.some((user) => user.email === email)) return res.status(409).json({ error: 'An account with that email already exists.' });
  const user = { id: randomUUID(), email, name, passwordHash: await bcrypt.hash(password, 12), createdAt: new Date().toISOString() };
  store.users.push(user);
  await persist();
  return res.status(201).json({ token: tokenFor(user), user: publicUser(user) });
});
app.post('/api/auth/login', async (req, res) => {
  const email = String(req.body.email || '').trim().toLowerCase();
  const user = store.users.find((candidate) => candidate.email === email);
  if (!user || !(await bcrypt.compare(String(req.body.password || ''), user.passwordHash))) return res.status(401).json({ error: 'Invalid email or password.' });
  return res.json({ token: tokenFor(user), user: publicUser(user) });
});
app.get('/api/auth/me', authenticate, (req, res) => res.json({ user: publicUser(req.user) }));

app.get('/api/calls', authenticate, (req, res) => {
  const query = String(req.query.query || '').trim().toLowerCase();
  const type = String(req.query.type || 'all');
  const start = dateRange(req.query.from);
  const end = dateRange(req.query.to, true);
  const calls = own(store.calls, req.user.id).filter((call) => {
    const callDate = new Date(call.date);
    return (type === 'all' || call.type === type)
      && (!query || `${call.name} ${call.phone}`.toLowerCase().includes(query))
      && (!start || callDate >= start) && (!end || callDate < end);
  }).sort((a, b) => new Date(b.date) - new Date(a.date));
  res.json({ calls });
});
app.post('/api/calls', authenticate, async (req, res) => {
  const error = validateCall(req.body);
  if (error) return res.status(400).json({ error });
  const call = { id: randomUUID(), userId: req.user.id, name: req.body.name.trim(), phone: req.body.phone.trim(), type: req.body.type, durationSeconds: Number(req.body.durationSeconds), date: new Date(req.body.date || Date.now()).toISOString(), isSpam: Boolean(req.body.isSpam), source: req.body.source === 'provider' ? 'provider' : 'manual', createdAt: new Date().toISOString() };
  store.calls.push(call);
  await persist();
  return res.status(201).json({ call });
});
app.delete('/api/calls/:id', authenticate, async (req, res) => {
  const index = store.calls.findIndex((call) => call.id === req.params.id && call.userId === req.user.id);
  if (index < 0) return res.status(404).json({ error: 'Call not found.' });
  store.calls.splice(index, 1);
  store.recordings = store.recordings.filter((recording) => recording.callId !== req.params.id);
  await persist();
  return res.status(204).end();
});

app.get('/api/contacts', authenticate, (req, res) => {
  const query = String(req.query.query || '').trim().toLowerCase();
  const contacts = own(store.contacts, req.user.id).filter((contact) => !query || `${contact.name} ${contact.phone}`.toLowerCase().includes(query)).sort((a, b) => a.name.localeCompare(b.name));
  res.json({ contacts });
});
app.post('/api/contacts', authenticate, async (req, res) => {
  const name = String(req.body.name || '').trim();
  const phone = String(req.body.phone || '').trim();
  const tag = String(req.body.tag || 'Contact').trim().slice(0, 40) || 'Contact';
  if (!name || !phone) return res.status(400).json({ error: 'Name and phone number are required.' });
  const existing = store.contacts.find((contact) => contact.userId === req.user.id && contact.phone === phone);
  if (existing) { existing.name = name; existing.tag = tag; await persist(); return res.json({ contact: existing }); }
  const contact = { id: randomUUID(), userId: req.user.id, name, phone, tag, createdAt: new Date().toISOString() };
  store.contacts.push(contact); await persist(); return res.status(201).json({ contact });
});
app.delete('/api/contacts/:id', authenticate, async (req, res) => {
  const index = store.contacts.findIndex((contact) => contact.id === req.params.id && contact.userId === req.user.id);
  if (index < 0) return res.status(404).json({ error: 'Contact not found.' });
  store.contacts.splice(index, 1); await persist(); return res.status(204).end();
});

const upload = multer({ storage: multer.diskStorage({ destination: uploadPath, filename: (_, file, callback) => callback(null, `${randomUUID()}${path.extname(file.originalname).toLowerCase()}`) }), limits: { fileSize: maxRecordingSize }, fileFilter: (_, file, callback) => callback(null, ['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/wav', 'audio/aac'].includes(file.mimetype)) });
app.get('/api/recordings', authenticate, (req, res) => res.json({ recordings: own(store.recordings, req.user.id).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt)) }));
app.post('/api/recordings', authenticate, upload.single('recording'), async (req, res) => {
  if (!req.file || req.body.consent !== 'true') return res.status(400).json({ error: 'An audio file and explicit recording consent are required.' });
  const call = store.calls.find((item) => item.id === req.body.callId && item.userId === req.user.id);
  if (!call) return res.status(404).json({ error: 'Select one of your calls before uploading a recording.' });
  const recording = { id: randomUUID(), userId: req.user.id, callId: call.id, name: String(req.body.name || call.name).slice(0, 120), fileName: req.file.filename, mimeType: req.file.mimetype, size: req.file.size, consentedAt: new Date().toISOString(), source: 'authorized-provider', createdAt: new Date().toISOString() };
  store.recordings.push(recording); await persist(); return res.status(201).json({ recording });
});
app.get('/api/recordings/:id/file', authenticate, (req, res) => {
  const recording = store.recordings.find((item) => item.id === req.params.id && item.userId === req.user.id);
  if (!recording) return res.status(404).json({ error: 'Recording not found.' });
  return res.type(recording.mimeType).sendFile(path.join(uploadPath, recording.fileName));
});

app.post('/api/spam-reports', authenticate, async (req, res) => {
  const phone = String(req.body.phone || '').trim();
  const reason = String(req.body.reason || '').trim().slice(0, 300);
  if (!phone || !reason) return res.status(400).json({ error: 'Phone number and report reason are required.' });
  store.spamReports.push({ id: randomUUID(), userId: req.user.id, phone, reason, createdAt: new Date().toISOString() }); await persist(); return res.status(201).json({ ok: true });
});
app.get('/api/analytics', authenticate, (req, res) => {
  const now = new Date();
  const calls = own(store.calls, req.user.id);
  const start = dateRange(req.query.from) || new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const end = dateRange(req.query.to, true) || new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));
  const relevant = calls.filter((call) => new Date(call.date) >= start && new Date(call.date) < end);
  const totals = relevant.reduce((value, call) => ({ total: value.total + 1, incoming: value.incoming + (call.type === 'incoming' ? 1 : 0), outgoing: value.outgoing + (call.type === 'outgoing' ? 1 : 0), missed: value.missed + (call.type === 'missed' ? 1 : 0), durationSeconds: value.durationSeconds + call.durationSeconds }), { total: 0, incoming: 0, outgoing: 0, missed: 0, durationSeconds: 0 });
  const buckets = new Map();
  for (const call of relevant) { const key = call.date.slice(0, 10); buckets.set(key, (buckets.get(key) || 0) + 1); }
  res.json({ totals, series: [...buckets.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([date, count]) => ({ date, count })) });
});
app.get('/api/dashboard', authenticate, (req, res) => {
  const calls = own(store.calls, req.user.id).sort((a, b) => new Date(b.date) - new Date(a.date));
  const today = new Date().toISOString().slice(0, 10);
  const metrics = calls.reduce((value, call) => ({ total: value.total + 1, incoming: value.incoming + (call.type === 'incoming' ? 1 : 0), outgoing: value.outgoing + (call.type === 'outgoing' ? 1 : 0), missed: value.missed + (call.type === 'missed' ? 1 : 0), durationSeconds: value.durationSeconds + call.durationSeconds, today: value.today + (call.date.startsWith(today) ? 1 : 0) }), { total: 0, incoming: 0, outgoing: 0, missed: 0, durationSeconds: 0, today: 0 });
  res.json({ metrics, recent: calls.slice(0, 5) });
});

app.use((error, _, res, __) => {
  if (error instanceof multer.MulterError) return res.status(400).json({ error: error.code === 'LIMIT_FILE_SIZE' ? 'Recording exceeds the configured file-size limit.' : error.message });
  if (error.message === 'Origin is not permitted.') return res.status(403).json({ error: error.message });
  console.error(error); return res.status(500).json({ error: 'Unexpected server error.' });
});
app.listen(port, () => console.log(`Call Monitor API listening on port ${port}`));
