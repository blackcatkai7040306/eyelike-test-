import bcrypt from "bcryptjs";
import { v4 as uuid } from "uuid";

/** @typedef {{ id: string, username: string, passwordHash: string }} User */

/** @type {Map<string, User>} */
const usersById = new Map();
/** @type {Map<string, string>} username -> id */
const idByUsername = new Map();
/** @type {Map<string, Set<string>>} userId -> socket ids */
const socketsByUser = new Map();

export function createUser(username, password) {
  const norm = username.trim().toLowerCase();
  if (!norm || norm.length < 2) {
    throw new Error("Username too short");
  }
  if (idByUsername.has(norm)) {
    throw new Error("Username taken");
  }
  const id = uuid();
  const passwordHash = bcrypt.hashSync(password, 10);
  const user = { id, username: norm, passwordHash };
  usersById.set(id, user);
  idByUsername.set(norm, id);
  return { id, username: norm };
}

export function verifyLogin(username, password) {
  const norm = username.trim().toLowerCase();
  const id = idByUsername.get(norm);
  if (!id) return null;
  const user = usersById.get(id);
  if (!user || !bcrypt.compareSync(password, user.passwordHash)) return null;
  return { id: user.id, username: user.username };
}

export function getUserById(id) {
  const u = usersById.get(id);
  return u ? { id: u.id, username: u.username } : null;
}

export function listUsers() {
  return [...usersById.values()].map((u) => ({ id: u.id, username: u.username }));
}

export function registerSocket(userId, socketId) {
  let set = socketsByUser.get(userId);
  if (!set) {
    set = new Set();
    socketsByUser.set(userId, set);
  }
  set.add(socketId);
}

export function unregisterSocket(userId, socketId) {
  const set = socketsByUser.get(userId);
  if (!set) return;
  set.delete(socketId);
  if (set.size === 0) socketsByUser.delete(userId);
}

export function isUserOnline(userId) {
  return (socketsByUser.get(userId)?.size ?? 0) > 0;
}

export function getOnlineUserIds() {
  return [...socketsByUser.keys()];
}
