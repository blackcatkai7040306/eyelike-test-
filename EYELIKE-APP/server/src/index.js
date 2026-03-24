import "dotenv/config";
import http from "http";
import express from "express";
import cors from "cors";
import { Server } from "socket.io";
import { verifyToken } from "./auth.js";
import {
  registerSocket,
  unregisterSocket,
  isUserOnline,
  getOnlineUserIds,
} from "./store.js";

const PORT = Number(process.env.PORT) || 3001;
const CORS_ORIGIN = process.env.CORS_ORIGIN || "*";

if (!process.env.SUPABASE_JWT_SECRET) {
  console.warn(
    "[eyelike] SUPABASE_JWT_SECRET is not set — Socket auth will reject all tokens."
  );
}

const app = express();
app.use(cors({ origin: CORS_ORIGIN === "*" ? true : CORS_ORIGIN }));
app.use(express.json());

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "eyelike", auth: "supabase-jwt" });
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
    const message = {
      id:
        typeof payload?.messageId === "string"
          ? payload.messageId
          : `${Date.now()}-${socket.id}`,
      fromUserId: user.id,
      fromUsername: user.username,
      toUserId,
      text: text.slice(0, 4000),
      at:
        typeof payload?.at === "string"
          ? payload.at
          : new Date().toISOString(),
      clientNonce: payload?.clientNonce,
    };
    io.to(`user:${toUserId}`).emit("chat:private", message);
    ack?.({ ok: true, message });
  });

  socket.on("webrtc:signal", (payload) => {
    const toUserId = payload?.toUserId;
    if (!toUserId || !payload?.type) return;
    io.to(`user:${toUserId}`).emit("webrtc:signal", {
      fromUserId: user.id,
      type: payload.type,
      sdp: payload.sdp,
      candidate: payload.candidate,
      sdpMid: payload.sdpMid,
      sdpMLineIndex: payload.sdpMLineIndex,
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
