import jwt from "jsonwebtoken";

const SUPABASE_JWT_SECRET = process.env.SUPABASE_JWT_SECRET;
const rawUrl = process.env.SUPABASE_URL?.replace(/\/$/, "") || "";
const VERIFY_ISSUER = process.env.SUPABASE_VERIFY_ISSUER !== "false";

/** Expected JWT issuer for Supabase access tokens */
const SUPABASE_ISSUER = rawUrl ? `${rawUrl}/auth/v1` : null;

/**
 * Verify Supabase access_token (HS256). Returns { id, username, email } or null.
 */
export function verifyToken(token) {
  if (!token || typeof token !== "string" || !SUPABASE_JWT_SECRET) {
    return null;
  }
  try {
    const payload = jwt.verify(token, SUPABASE_JWT_SECRET, {
      algorithms: ["HS256"],
      audience: "authenticated",
      ...(VERIFY_ISSUER && SUPABASE_ISSUER ? { issuer: SUPABASE_ISSUER } : {}),
    });
    const id = payload.sub;
    if (!id || typeof id !== "string") return null;
    const meta = payload.user_metadata || {};
    const username =
      (typeof meta.username === "string" && meta.username.trim()) ||
      (typeof payload.email === "string"
        ? payload.email.split("@")[0]
        : "user");
    return {
      id,
      username,
      email: typeof payload.email === "string" ? payload.email : null,
    };
  } catch {
    return null;
  }
}
