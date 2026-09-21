type WorkerEnv = Env & { SUPABASE_URL?: string; SUPABASE_PUBLISHABLE_KEY?: string }

const UPSTREAM_AUTH_TIMEOUT_MS = 7_000

function json(data: unknown, status = 200, headers?: HeadersInit): Response {
  return Response.json(data, { status, headers: { "Cache-Control": "no-store", ...headers } })
}

function getSupabaseConfig(env: WorkerEnv) {
  if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) return null
  return { url: env.SUPABASE_URL.replace(/\/$/, ""), key: env.SUPABASE_PUBLISHABLE_KEY }
}

function getBearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization")
  if (!authorization) return null
  const match = authorization.match(/^Bearer\s+(.+)$/i)
  return match?.[1] ?? null
}

async function forwardAuth(env: WorkerEnv, target: string, init: RequestInit): Promise<Response> {
  const config = getSupabaseConfig(env)
  if (!config) return json({ error: "server_not_configured" }, 503)

  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), UPSTREAM_AUTH_TIMEOUT_MS)
  try {
    const response = await fetch(`${config.url}${target}`, {
      ...init,
      signal: controller.signal,
      headers: { apikey: config.key, Accept: "application/json", ...(init.headers ?? {}) },
    })
    const body = await response.text()
    return new Response(body, {
      status: response.status,
      headers: { "Content-Type": response.headers.get("content-type") ?? "application/json", "Cache-Control": "no-store" },
    })
  } catch (error) {
    if (error instanceof Error && error.name === "AbortError") return json({ error: "upstream_request_timed_out" }, 504)
    return json({ error: "upstream_request_failed" }, 502)
  } finally {
    clearTimeout(timeout)
  }
}

async function handleAuth(request: Request, env: WorkerEnv, pathname: string): Promise<Response> {
  if (pathname === "/api/auth/token") {
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405)
    const grantType = new URL(request.url).searchParams.get("grant_type")
    if (grantType !== "password" && grantType !== "refresh_token") return json({ error: "invalid_grant_type" }, 400)
    let body: unknown
    try { body = await request.json() } catch { return json({ error: "invalid_json" }, 400) }
    if (!body || typeof body !== "object" || Array.isArray(body)) return json({ error: "request_body_must_be_object" }, 400)
    return forwardAuth(env, `/auth/v1/token?grant_type=${grantType}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })
  }
  if (pathname === "/api/auth/profile") {
    if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405)
    const accessToken = getBearerToken(request)
    if (!accessToken) return json({ error: "authentication_required" }, 401)
    const userId = new URL(request.url).searchParams.get("user_id")
    if (!userId || !/^[0-9a-fA-F-]{36}$/.test(userId)) return json({ error: "invalid_user_id" }, 400)
    const query = new URLSearchParams({ id: `eq.${userId}`, select: "id,name,email,role,active" })
    return forwardAuth(env, `/rest/v1/profiles?${query.toString()}`, { headers: { Authorization: `Bearer ${accessToken}` } })
  }
  if (pathname === "/api/auth/recover") {
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405)
    let body: unknown
    try { body = await request.json() } catch { return json({ error: "invalid_json" }, 400) }
    if (!body || typeof body !== "object" || Array.isArray(body)) return json({ error: "request_body_must_be_object" }, 400)
    const email = typeof (body as { email?: unknown }).email === "string" ? (body as { email: string }).email.trim() : ""
    if (!email) return json({ error: "email_required" }, 400)
    const redirectTo = `${new URL(request.url).origin}/login`
    return forwardAuth(env, "/auth/v1/recover", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, redirect_to: redirectTo }) })
  }
  if (pathname === "/api/auth/logout") {
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405)
    const accessToken = getBearerToken(request)
    if (!accessToken) return json({ error: "authentication_required" }, 401)
    return forwardAuth(env, "/auth/v1/logout", { method: "POST", headers: { Authorization: `Bearer ${accessToken}` } })
  }
  return json({ error: "not_found" }, 404)
}

import app from "./index.ts"

export default {
  async fetch(request: Request, env: WorkerEnv): Promise<Response> {
    const url = new URL(request.url)
    if (url.pathname.startsWith("/api/auth/")) return handleAuth(request, env, url.pathname)
    return app.fetch(request, env)
  },
}
