import "dotenv/config";
import http from "http";
import express from "express";
import cors from "cors";
import { Server } from "socket.io";
import { signToken, verifyToken } from "./auth.js";
import {
  createUser,
  verifyLogin,
  getUserById,
  listUsers,
  registerSocket,
  unregisterSocket,
  isUserOnline,
  getOnlineUserIds,
} from "./store.js";

const PORT = Number(process.env.PORT) || 3001;
const CORS_ORIGIN = process.env.CORS_ORIGIN || "*";

const app = express();
app.use(cors({ origin: CORS_ORIGIN === "*" ? true : CORS_ORIGIN }));
app.use(express.json());

function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  const token = header?.startsWith("Bearer ") ? header.slice(7) : null;
  const user = verifyToken(token);
  if (!user) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }
  req.user = user;
  next();
}

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "eyelike" });
});

app.post("/api/auth/register", (req, res) => {
  try {
    const { username, password } = req.body || {};
    if (!username || !password) {
      res.status(400).json({ error: "username and password required" });
      return;
    }
    const user = createUser(String(username), String(password));
    const token = signToken(user);
    res.status(201).json({ user, token });
  } catch (e) {
    res.status(400).json({ error: e.message || "register failed" });
  }
});

app.post("/api/auth/login", (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    res.status(400).json({ error: "username and password required" });
    return;
  }
  const user = verifyLogin(String(username), String(password));
  if (!user) {
    res.status(401).json({ error: "Invalid credentials" });
    return;
  }
  res.json({ user, token: signToken(user) });
});

app.get("/api/users", authMiddleware, (req, res) => {
  const others = listUsers()
    .filter((u) => u.id !== req.user.id)
    .map((u) => ({
      ...u,
      online: isUserOnline(u.id),
    }));
  res.json({ users: others, onlineIds: getOnlineUserIds() });
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: CORS_ORIGIN === "*" ? true : CORS_ORIGIN,
    methods: ["GET", "POST"],
  },
});

io.use((socket, next) => {
  const token =
    socket.handshake.auth?.token ||
    socket.handshake.query?.token ||
    null;
  const user = verifyToken(typeof token === "string" ? token : null);
  if (!user) {
    next(new Error("auth"));
    return;
  }
  socket.data.user = user;
  next();
});

io.on("connection", (socket) => {
  const user = socket.data.user;
  registerSocket(user.id, socket.id);
  socket.join(`user:${user.id}`);

  io.emit("presence:update", {
    userId: user.id,
    online: true,
    onlineIds: getOnlineUserIds(),
  });

  socket.on("chat:private", (payload, ack) => {
    const toUserId = payload?.toUserId;
    const text = typeof payload?.text === "string" ? payload.text.trim() : "";
    if (!toUserId || !text) {
      ack?.({ ok: false, error: "invalid" });
      return;
    }
    const peer = getUserById(toUserId);
    if (!peer) {
      ack?.({ ok: false, error: "user not found" });
      return;
    }
    const message = {
      id: `${Date.now()}-${socket.id}`,
      fromUserId: user.id,
      fromUsername: user.username,
      toUserId,
      text: text.slice(0, 4000),
      at: new Date().toISOString(),
      clientNonce: payload?.clientNonce,
    };
    io.to(`user:${toUserId}`).emit("chat:private", message);
    ack?.({ ok: true, message });
  });

  socket.on("webrtc:signal", (payload) => {
    const toUserId = payload?.toUserId;
    if (!toUserId || !payload?.type) return;
    if (!getUserById(toUserId)) return;
    io.to(`user:${toUserId}`).emit("webrtc:signal", {
      fromUserId: user.id,
      type: payload.type,
      sdp: payload.sdp,
      candidate: payload.candidate,
    });
  });

  socket.on("disconnect", () => {
    unregisterSocket(user.id, socket.id);
    io.emit("presence:update", {
      userId: user.id,
      online: isUserOnline(user.id),
      onlineIds: getOnlineUserIds(),
    });
  });
});

server.listen(PORT, () => {
  console.log(`EyeLike server http://localhost:${PORT}`);
});
