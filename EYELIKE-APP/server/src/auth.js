import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET || "dev-only-change-me";

export function signToken(user) {
  return jwt.sign(
    { sub: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: "7d" }
  );
}

export function verifyToken(token) {
  if (!token || typeof token !== "string") return null;
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    return { id: payload.sub, username: payload.username };
  } catch {
    return null;
  }
}
