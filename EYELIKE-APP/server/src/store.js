/** @type {Map<string, Set<string>>} userId (Supabase sub) -> socket ids */
const socketsByUser = new Map();

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
