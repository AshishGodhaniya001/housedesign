require("dotenv").config();

const crypto = require("crypto");
const express = require("express");
const cors = require("cors");
const nodemailer = require("nodemailer");
const { db, dbPath } = require("./db");

const app = express();
const PORT = Number(process.env.PORT || 8000);
const SESSION_TTL_DAYS = 30;
const PASSWORD_RESET_TTL_MINUTES = 10;
const PASSWORD_RESET_OTP_TTL_MINUTES = 10;
const MAIL_MODE = String(process.env.MAIL_MODE || "log").trim().toLowerCase();
const SMTP_HOST = String(process.env.SMTP_HOST || "").trim();
const SMTP_PORT = Number(process.env.SMTP_PORT || 587);
const SMTP_SECURE = String(process.env.SMTP_SECURE || "false") === "true";
const SMTP_USER = String(process.env.SMTP_USER || "").trim();
const SMTP_PASS = String(process.env.SMTP_PASS || "").trim();
const SMTP_FROM = String(process.env.SMTP_FROM || SMTP_USER).trim();

const mailTransport =
  MAIL_MODE === "smtp" && SMTP_HOST && SMTP_USER && SMTP_PASS && SMTP_FROM
    ? nodemailer.createTransport({
        host: SMTP_HOST,
        port: SMTP_PORT,
        secure: SMTP_SECURE,
        auth: {
          user: SMTP_USER,
          pass: SMTP_PASS,
        },
      })
    : null;

app.use(cors());
app.use(express.json({ limit: "2mb" }));

app.get("/", (_, res) => {
  res.json({
    ok: true,
    service: "floor-planner-backend",
    docs: [
      "/health",
      "/api/auth/register",
      "/api/auth/login",
      "/api/auth/forgot-password/send-otp",
      "/api/auth/forgot-password/verify-otp",
      "/api/auth/forgot-password/reset",
      "/api/layouts",
    ],
  });
});

function parseList(value, fieldName) {
  if (!Array.isArray(value)) {
    throw new Error(`${fieldName} must be an array`);
  }
  return value;
}

function sanitizeLayoutBody(body) {
  const name =
    typeof body?.name === "string" && body.name.trim().length > 0
      ? body.name.trim()
      : "Untitled Layout";

  const floors = Math.max(1, Number(body?.floors || 1) || 1);
  const rooms = parseList(body?.rooms ?? [], "rooms");
  const structures = parseList(body?.structures ?? [], "structures");

  return { name, floors, rooms, structures };
}

function normalizeEmail(email) {
  if (typeof email !== "string") return "";
  return email.trim().toLowerCase();
}

function hashPassword(password, salt) {
  return crypto
    .pbkdf2Sync(password, salt, 100000, 64, "sha512")
    .toString("hex");
}

function createSession(userId) {
  const token = crypto.randomBytes(48).toString("hex");
  const expiresAt = new Date(
    Date.now() + SESSION_TTL_DAYS * 24 * 60 * 60 * 1000
  ).toISOString();

  db.prepare(
    `
    INSERT INTO sessions (token, user_id, expires_at)
    VALUES (?, ?, ?)
    `
  ).run(token, userId, expiresAt);

  return { token, expiresAt };
}

function createPasswordResetToken(userId) {
  const token = crypto.randomBytes(32).toString("hex");
  const expiresAt = new Date(
    Date.now() + PASSWORD_RESET_TTL_MINUTES * 60 * 1000
  ).toISOString();

  db.prepare("DELETE FROM password_reset_tokens WHERE user_id = ?").run(userId);
  db.prepare(
    `
    INSERT INTO password_reset_tokens (token, user_id, expires_at)
    VALUES (?, ?, ?)
    `
  ).run(token, userId, expiresAt);

  return { token, expiresAt };
}

function createPasswordResetOtp(userId) {
  const code = String(Math.floor(100000 + Math.random() * 900000));
  const expiresAt = new Date(
    Date.now() + PASSWORD_RESET_OTP_TTL_MINUTES * 60 * 1000
  ).toISOString();

  db.prepare("DELETE FROM password_reset_otps WHERE user_id = ?").run(userId);
  db.prepare(
    `
    INSERT INTO password_reset_otps (user_id, code, expires_at)
    VALUES (?, ?, ?)
    `
  ).run(userId, code, expiresAt);

  return { code, expiresAt };
}

function clearExpiredSessions() {
  db.prepare("DELETE FROM sessions WHERE datetime(expires_at) <= datetime('now')").run();
}

function clearExpiredPasswordResetTokens() {
  db.prepare(
    "DELETE FROM password_reset_tokens WHERE datetime(expires_at) <= datetime('now')"
  ).run();
}

function clearExpiredPasswordResetOtps() {
  db.prepare(
    "DELETE FROM password_reset_otps WHERE datetime(expires_at) <= datetime('now')"
  ).run();
}

async function sendPasswordResetOtpEmail(email, code) {
  if (MAIL_MODE === "smtp") {
    if (!mailTransport) {
      throw new Error("SMTP is not configured");
    }

    await mailTransport.sendMail({
      from: SMTP_FROM,
      to: email,
      subject: "RoyalNest Planner password reset code",
      text: `Your RoyalNest Planner password reset code is ${code}. It expires in ${PASSWORD_RESET_OTP_TTL_MINUTES} minutes.`,
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.5;color:#1f2933">
          <h2 style="margin-bottom:8px;">Password Reset Code</h2>
          <p>Use this code to continue resetting your password:</p>
          <div style="font-size:28px;font-weight:700;letter-spacing:6px;margin:18px 0;color:#17324a;">
            ${code}
          </div>
          <p>This code expires in ${PASSWORD_RESET_OTP_TTL_MINUTES} minutes.</p>
        </div>
      `,
    });
    return "smtp";
  }

  console.log(`[mail:password-reset] email=${email} otp=${code}`);
  return "log";
}

function toLayoutResponse(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    name: row.name,
    floors: row.floors,
    rooms: JSON.parse(row.rooms_json || "[]"),
    structures: JSON.parse(row.structures_json || "[]"),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function authRequired(req, res, next) {
  clearExpiredSessions();

  const header = req.headers.authorization || "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    return res.status(401).json({ error: "Missing bearer token" });
  }

  const token = match[1].trim();
  if (!token) {
    return res.status(401).json({ error: "Invalid bearer token" });
  }

  const session = db
    .prepare(
      `
      SELECT s.token, s.user_id, s.expires_at, u.name, u.email
      FROM sessions s
      INNER JOIN users u ON u.id = s.user_id
      WHERE s.token = ?
      `
    )
    .get(token);

  if (!session) {
    return res.status(401).json({ error: "Session not found" });
  }

  if (new Date(session.expires_at).getTime() <= Date.now()) {
    db.prepare("DELETE FROM sessions WHERE token = ?").run(token);
    return res.status(401).json({ error: "Session expired" });
  }

  req.auth = {
    token,
    userId: session.user_id,
    user: {
      id: session.user_id,
      name: session.name,
      email: session.email,
    },
  };
  return next();
}

app.get("/health", (_, res) => {
  res.json({
    ok: true,
    db: dbPath,
    auth: true,
    timestamp: new Date().toISOString(),
  });
});

app.post("/api/auth/register", (req, res) => {
  try {
    const name =
      typeof req.body?.name === "string" && req.body.name.trim().length > 0
        ? req.body.name.trim()
        : "Planner User";
    const email = normalizeEmail(req.body?.email);
    const password = String(req.body?.password || "").trim();

    if (!email || !email.includes("@")) {
      return res.status(400).json({ error: "Valid email is required" });
    }
    if (password.length < 6) {
      return res
        .status(400)
        .json({ error: "Password must be at least 6 characters" });
    }

    const existing = db.prepare("SELECT id FROM users WHERE email = ?").get(email);
    if (existing) {
      return res.status(409).json({ error: "Email already registered" });
    }

    const salt = crypto.randomBytes(16).toString("hex");
    const passwordHash = hashPassword(password, salt);

    const result = db
      .prepare(
        `
        INSERT INTO users (name, email, password_hash, salt)
        VALUES (?, ?, ?, ?)
        `
      )
      .run(name, email, passwordHash, salt);

    const userId = Number(result.lastInsertRowid);
    const session = createSession(userId);

    return res.status(201).json({
      token: session.token,
      expiresAt: session.expiresAt,
      user: { id: userId, name, email },
    });
  } catch (error) {
    return res.status(400).json({ error: error.message || "Invalid request" });
  }
});

app.post("/api/auth/login", (req, res) => {
  const email = normalizeEmail(req.body?.email);
  const password = String(req.body?.password || "").trim();

  if (!email || !password) {
    return res.status(400).json({ error: "Email and password are required" });
  }

  const user = db
    .prepare(
      `
      SELECT id, name, email, password_hash, salt
      FROM users
      WHERE email = ?
      `
    )
    .get(email);

  if (!user) {
    return res.status(401).json({ error: "Invalid credentials" });
  }

  const computed = hashPassword(password, user.salt);
  if (computed !== user.password_hash) {
    return res.status(401).json({ error: "Invalid credentials" });
  }

  const session = createSession(user.id);

  return res.json({
    token: session.token,
    expiresAt: session.expiresAt,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
    },
  });
});

app.post("/api/auth/forgot-password/send-otp", async (req, res) => {
  clearExpiredPasswordResetOtps();
  clearExpiredPasswordResetTokens();

  const email = normalizeEmail(req.body?.email);

  if (!email || !email.includes("@")) {
    return res.status(400).json({ error: "Valid email is required" });
  }

  const user = db
    .prepare(
      `
      SELECT id, email
      FROM users
      WHERE email = ?
      `
    )
    .get(email);

  if (!user) {
    return res.status(404).json({ error: "Email not found" });
  }

  const otp = createPasswordResetOtp(user.id);

  try {
    const deliveryMode = await sendPasswordResetOtpEmail(user.email, otp.code);

    return res.json({
      ok: true,
      email: user.email,
      expiresAt: otp.expiresAt,
      deliveryMode,
      message:
        deliveryMode === "smtp"
          ? "OTP sent to your email."
          : "OTP generated. Check backend logs in local mode.",
    });
  } catch (error) {
    db.prepare("DELETE FROM password_reset_otps WHERE user_id = ?").run(user.id);
    return res
      .status(500)
      .json({ error: error.message || "Failed to send OTP email" });
  }
});

app.post("/api/auth/forgot-password/verify-otp", (req, res) => {
  clearExpiredPasswordResetOtps();
  clearExpiredPasswordResetTokens();

  const email = normalizeEmail(req.body?.email);
  const otp = String(req.body?.otp || "").trim();

  if (!email || !email.includes("@")) {
    return res.status(400).json({ error: "Valid email is required" });
  }
  if (!/^\d{6}$/.test(otp)) {
    return res.status(400).json({ error: "Enter a valid 6-digit OTP" });
  }

  const user = db
    .prepare(
      `
      SELECT id, email
      FROM users
      WHERE email = ?
      `
    )
    .get(email);

  if (!user) {
    return res.status(404).json({ error: "Email not found" });
  }

  const otpRecord = db
    .prepare(
      `
      SELECT user_id, code, expires_at
      FROM password_reset_otps
      WHERE user_id = ? AND code = ?
      `
    )
    .get(user.id, otp);

  if (!otpRecord) {
    return res.status(401).json({ error: "Invalid OTP" });
  }

  if (new Date(otpRecord.expires_at).getTime() <= Date.now()) {
    db.prepare("DELETE FROM password_reset_otps WHERE user_id = ?").run(user.id);
    return res.status(401).json({ error: "OTP expired" });
  }

  const reset = createPasswordResetToken(user.id);
  db.prepare("DELETE FROM password_reset_otps WHERE user_id = ?").run(user.id);

  return res.json({
    ok: true,
    email: user.email,
    resetToken: reset.token,
    expiresAt: reset.expiresAt,
    message: "Email verified. You can now set a new password.",
  });
});

app.post("/api/auth/forgot-password/reset", (req, res) => {
  clearExpiredPasswordResetTokens();

  const email = normalizeEmail(req.body?.email);
  const resetToken = String(req.body?.resetToken || "").trim();
  const newPassword = String(req.body?.newPassword || "").trim();

  if (!email || !email.includes("@")) {
    return res.status(400).json({ error: "Valid email is required" });
  }
  if (!resetToken) {
    return res.status(400).json({ error: "Verification is required first" });
  }
  if (newPassword.length < 6) {
    return res
      .status(400)
      .json({ error: "New password must be at least 6 characters" });
  }

  const user = db
    .prepare(
      `
      SELECT id
      FROM users
      WHERE email = ?
      `
    )
    .get(email);

  if (!user) {
    return res.status(404).json({ error: "Email not found" });
  }

  const resetRecord = db
    .prepare(
      `
      SELECT token, user_id, expires_at
      FROM password_reset_tokens
      WHERE token = ? AND user_id = ?
      `
    )
    .get(resetToken, user.id);

  if (!resetRecord) {
    return res.status(401).json({ error: "Email verification expired" });
  }

  if (new Date(resetRecord.expires_at).getTime() <= Date.now()) {
    db.prepare("DELETE FROM password_reset_tokens WHERE token = ?").run(resetToken);
    return res.status(401).json({ error: "Email verification expired" });
  }

  const salt = crypto.randomBytes(16).toString("hex");
  const passwordHash = hashPassword(newPassword, salt);

  db.prepare(
    `
    UPDATE users
    SET password_hash = ?, salt = ?
    WHERE id = ?
    `
  ).run(passwordHash, salt, user.id);

  db.prepare("DELETE FROM sessions WHERE user_id = ?").run(user.id);
  db.prepare("DELETE FROM password_reset_tokens WHERE user_id = ?").run(user.id);

  return res.json({
    ok: true,
    message: "Password updated. Please login again.",
  });
});

app.get("/api/auth/me", authRequired, (req, res) => {
  return res.json({
    user: req.auth.user,
  });
});

app.post("/api/auth/logout", authRequired, (req, res) => {
  db.prepare("DELETE FROM sessions WHERE token = ?").run(req.auth.token);
  return res.status(204).send();
});

app.get("/api/layouts", authRequired, (req, res) => {
  const rows = db
    .prepare(
      `
      SELECT id, user_id, name, floors, rooms_json, structures_json, created_at, updated_at
      FROM layouts
      WHERE user_id = ?
      ORDER BY datetime(updated_at) DESC, id DESC
      `
    )
    .all(req.auth.userId);

  res.json(
    rows.map((row) => {
      const layout = toLayoutResponse(row);
      return {
        id: layout.id,
        userId: layout.userId,
        name: layout.name,
        floors: layout.floors,
        roomsCount: layout.rooms.length,
        structuresCount: layout.structures.length,
        createdAt: layout.createdAt,
        updatedAt: layout.updatedAt,
      };
    })
  );
});

app.get("/api/layouts/:id", authRequired, (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: "Invalid layout id" });
  }

  const row = db
    .prepare(
      `
      SELECT id, user_id, name, floors, rooms_json, structures_json, created_at, updated_at
      FROM layouts
      WHERE id = ? AND user_id = ?
      `
    )
    .get(id, req.auth.userId);

  if (!row) {
    return res.status(404).json({ error: "Layout not found" });
  }

  return res.json(toLayoutResponse(row));
});

app.post("/api/layouts", authRequired, (req, res) => {
  try {
    const payload = sanitizeLayoutBody(req.body);
    const now = new Date().toISOString();
    const result = db
      .prepare(
        `
        INSERT INTO layouts (user_id, name, floors, rooms_json, structures_json, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        `
      )
      .run(
        req.auth.userId,
        payload.name,
        payload.floors,
        JSON.stringify(payload.rooms),
        JSON.stringify(payload.structures),
        now,
        now
      );

    const row = db
      .prepare(
        `
        SELECT id, user_id, name, floors, rooms_json, structures_json, created_at, updated_at
        FROM layouts
        WHERE id = ? AND user_id = ?
        `
      )
      .get(result.lastInsertRowid, req.auth.userId);

    res.status(201).json(toLayoutResponse(row));
  } catch (error) {
    res.status(400).json({ error: error.message || "Invalid payload" });
  }
});

app.put("/api/layouts/:id", authRequired, (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: "Invalid layout id" });
  }

  const existing = db
    .prepare("SELECT id FROM layouts WHERE id = ? AND user_id = ?")
    .get(id, req.auth.userId);
  if (!existing) {
    return res.status(404).json({ error: "Layout not found" });
  }

  try {
    const payload = sanitizeLayoutBody(req.body);
    const now = new Date().toISOString();

    db.prepare(
      `
      UPDATE layouts
      SET name = ?, floors = ?, rooms_json = ?, structures_json = ?, updated_at = ?
      WHERE id = ? AND user_id = ?
      `
    ).run(
      payload.name,
      payload.floors,
      JSON.stringify(payload.rooms),
      JSON.stringify(payload.structures),
      now,
      id,
      req.auth.userId
    );

    const row = db
      .prepare(
        `
        SELECT id, user_id, name, floors, rooms_json, structures_json, created_at, updated_at
        FROM layouts
        WHERE id = ? AND user_id = ?
        `
      )
      .get(id, req.auth.userId);

    res.json(toLayoutResponse(row));
  } catch (error) {
    res.status(400).json({ error: error.message || "Invalid payload" });
  }
});

app.delete("/api/layouts/:id", authRequired, (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ error: "Invalid layout id" });
  }

  const result = db
    .prepare("DELETE FROM layouts WHERE id = ? AND user_id = ?")
    .run(id, req.auth.userId);
  if (result.changes === 0) {
    return res.status(404).json({ error: "Layout not found" });
  }

  return res.status(204).send();
});

// Compatibility endpoint for existing generate API calls.
app.post("/api/generate", (req, res) => {
  res.json({
    ok: true,
    message: "Use /api/layouts endpoints for database persistence.",
    input: req.body ?? {},
  });
});

app.use((error, _, res, __) => {
  console.error(error);
  res.status(500).json({ error: "Internal server error" });
});

app.listen(PORT, () => {
  console.log(`Backend API listening on http://localhost:${PORT}`);
});
