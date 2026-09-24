const ALLOWED_COMMANDS = new Set([
  "resolve_customer_by_phone", "create_order", "update_order", "update_order_items", "confirm_order", "cancel_order",
  "create_parcel", "allocate_parcel_items", "correct_parcel_allocation", "cancel_parcel", "dispatch_parcel", "bulk_dispatch",
  "record_delivery_outcome", "process_rto", "bulk_rto", "create_cod_obligation", "allocate_cod_obligation_to_parcel", "record_cod_receipt", "resolve_cod_exception", "record_financial_adjustment",
  "generate_invoice", "print_invoice", "import_preview", "import_commit",
]);

type WorkerEnv = Env & { SUPABASE_URL?: string; SUPABASE_PUBLISHABLE_KEY?: string };

function json(data: unknown, status = 200, headers?: HeadersInit): Response { return Response.json(data, { status, headers: { "Cache-Control": "no-store", ...headers } }); }
function getBearerToken(request: Request): string | null { const authorization = request.headers.get("Authorization"); if (!authorization) return null; const match = authorization.match(/^Bearer\s+(.+)$/i); return match?.[1] ?? null; }
function getRequestId(request: Request): string { const supplied = request.headers.get("X-Request-ID")?.trim(); if (supplied && /^[A-Za-z0-9._:-]{1,128}$/.test(supplied)) return supplied; return crypto.randomUUID(); }
function getSupabaseConfig(env: WorkerEnv) { if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) return null; return { url: env.SUPABASE_URL.replace(/\/$/, ""), key: env.SUPABASE_PUBLISHABLE_KEY }; }
function logEvent(event: string, fields: Record<string, unknown>) { console.log(JSON.stringify({ event, ...fields })); }
function escapeSearchTerm(value: string) { return value.replace(/[(),.*]/g, " ").replace(/%/g, " ").replace(/\s+/g, " ").trim().slice(0, 100); }
function validFilter(value: string | null, allowed: readonly string[]) { return value === null || allowed.includes(value); }
function validDate(value: string | null) { return value === null || /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(`${value}T00:00:00Z`)); }

const AUTH_COOKIE = "ecommerce_operations_refresh";
const AUTH_COOKIE_MAX_AGE = 60 * 60 * 24 * 30;

function cookieValue(request: Request, name: string): string | null {
  const header = request.headers.get("Cookie") ?? "";
  const match = header.split(";").map((part) => part.trim()).find((part) => part.startsWith(name + "="));
  return match ? decodeURIComponent(match.slice(name.length + 1)) : null;
}

function authCookie(refreshToken: string): string {
  return `${AUTH_COOKIE}=${encodeURIComponent(refreshToken)}; Max-Age=${AUTH_COOKIE_MAX_AGE}; Path=/; HttpOnly; Secure; SameSite=Lax`;
}

function clearAuthCookie(): string {
  return `${AUTH_COOKIE}=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Lax`;
}

async function handleAuth(request: Request, env: WorkerEnv, action: "sign-in" | "session" | "sign-out"): Promise<Response> {
  const config = getSupabaseConfig(env);
  if (!config) return json({ error: "server_not_configured" }, 503);
  if (action === "sign-out") {
    const refreshToken = cookieValue(request, AUTH_COOKIE);
    if (refreshToken) {
      try {
        const tokenResponse = await fetch(`${config.url}/auth/v1/token?grant_type=refresh_token`, {
          method: "POST",
          headers: { apikey: config.key, "Content-Type": "application/json" },
          body: JSON.stringify({ refresh_token: refreshToken }),
        });
        if (tokenResponse.ok) {
          const token = await tokenResponse.json() as TokenResponse;
          await fetch(`${config.url}/auth/v1/logout`, {
            method: "POST",
            headers: { apikey: config.key, Authorization: `Bearer ${token.access_token}` },
          }).catch(() => undefined);
        }
      } catch {
        // Cookie is cleared even when upstream logout cannot be completed.
      }
    }
    return json({ ok: true }, 200, { "Set-Cookie": clearAuthCookie() });
  }

  let tokenResponse: Response;
  if (action === "sign-in") {
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    const body = await request.json().catch(() => null) as { email?: string; password?: string } | null;
    if (!body?.email || !body.password) return json({ error: "credentials_required" }, 400);
    tokenResponse = await fetch(`${config.url}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: config.key, "Content-Type": "application/json" },
      body: JSON.stringify({ email: body.email, password: body.password }),
    });
  } else {
    const refreshToken = cookieValue(request, AUTH_COOKIE);
    if (!refreshToken) return json({ error: "authentication_required" }, 401);
    tokenResponse = await fetch(`${config.url}/auth/v1/token?grant_type=refresh_token`, {
      method: "POST",
      headers: { apikey: config.key, "Content-Type": "application/json" },
      body: JSON.stringify({ refresh_token: refreshToken }),
    });
  }

  if (!tokenResponse.ok) return json({ error: "authentication_failed" }, tokenResponse.status, { "Set-Cookie": clearAuthCookie() });
  const token = await tokenResponse.json() as TokenResponse;
  return json({ accessToken: token.access_token, userId: token.user.id }, 200, { "Set-Cookie": authCookie(token.refresh_token) });
}

async function handleRpc(request: Request, env: WorkerEnv, commandName: string, requestId: string): Promise<Response> { const startedAt = performance.now(); if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405, { "X-Request-ID": requestId }); if (!ALLOWED_COMMANDS.has(commandName)) return json({ error: "command_not_allowed" }, 404, { "X-Request-ID": requestId }); const accessToken = getBearerToken(request); if (!accessToken) return json({ error: "authentication_required" }, 401, { "X-Request-ID": requestId }); const config = getSupabaseConfig(env); if (!config) { logEvent("command_request", { request_id: requestId, command: commandName, result: "server_error", status: 503 }); return json({ error: "server_not_configured" }, 503, { "X-Request-ID": requestId }); } let body: unknown; try { body = await request.json(); } catch { return json({ error: "invalid_json" }, 400, { "X-Request-ID": requestId }); } if (!body || typeof body !== "object" || Array.isArray(body)) return json({ error: "request_body_must_be_object" }, 400, { "X-Request-ID": requestId }); let rpcResponse: Response; try { rpcResponse = await fetch(`${config.url}/rest/v1/rpc/${encodeURIComponent(commandName)}`, { method: "POST", headers: { apikey: config.key, Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json", Accept: "application/json" }, body: JSON.stringify(body) }); } catch { logEvent("command_request", { request_id: requestId, command: commandName, result: "server_error", status: 502, duration_ms: Math.round(performance.now() - startedAt), dependency: "supabase_rest", error: "upstream_request_failed" }); return json({ error: "upstream_request_failed" }, 502, { "X-Request-ID": requestId }); } const responseBody = await rpcResponse.text(); const result = rpcResponse.status >= 500 ? "server_error" : rpcResponse.status >= 400 ? "client_error" : "success"; logEvent("command_request", { request_id: requestId, command: commandName, result, status: rpcResponse.status, duration_ms: Math.round(performance.now() - startedAt), dependency: "supabase_rest" }); return new Response(responseBody, { status: rpcResponse.status, headers: { "Content-Type": rpcResponse.headers.get("content-type") ?? "application/json", "Cache-Control": "no-store", "X-Request-ID": requestId } }); }

async function handleOrders(request: Request, env: WorkerEnv, requestId: string): Promise<Response> { const startedAt = performance.now(); if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405, { "X-Request-ID": requestId }); const accessToken = getBearerToken(request); if (!accessToken) return json({ error: "authentication_required" }, 401, { "X-Request-ID": requestId }); const config = getSupabaseConfig(env); if (!config) return json({ error: "server_not_configured" }, 503, { "X-Request-ID": requestId }); const url = new URL(request.url); const rawPage = Number.parseInt(url.searchParams.get("page") ?? "1", 10); const rawPageSize = Number.parseInt(url.searchParams.get("page_size") ?? "25", 10); const rawSearch = url.searchParams.get("search") ?? ""; const search = escapeSearchTerm(rawSearch); const lifecycleState = url.searchParams.get("lifecycle_state"); const parcelState = url.searchParams.get("parcel_state"); const codState = url.searchParams.get("cod_state"); const dateFrom = url.searchParams.get("date_from"); const dateTo = url.searchParams.get("date_to"); const lifecycleStates = ["Draft", "Confirmed", "Active", "Completed", "Cancelled"] as const; const parcelStates = ["Prepared", "Dispatched", "In Transit", "NDR", "Delivered", "RTO", "Lost", "Damaged", "Cancelled"] as const; const codStates = ["Outstanding", "Partially Received", "Received", "Exception", "Voided", "Closed"] as const; if (!Number.isInteger(rawPage) || rawPage < 1 || !Number.isInteger(rawPageSize) || rawPageSize < 1 || rawPageSize > 100) return json({ error: "invalid_pagination", message: "page must be >= 1 and page_size must be between 1 and 100" }, 400, { "X-Request-ID": requestId }); if (rawSearch.trim() && !search) return json({ error: "invalid_search", message: "search must contain at least one searchable character" }, 400, { "X-Request-ID": requestId }); if (!validFilter(lifecycleState, lifecycleStates) || !validFilter(parcelState, parcelStates) || !validFilter(codState, codStates)) return json({ error: "invalid_filter" }, 400, { "X-Request-ID": requestId }); if (!validDate(dateFrom) || !validDate(dateTo) || dateFrom && dateTo && dateFrom > dateTo) return json({ error: "invalid_date_range", message: "date_from and date_to must be valid dates with date_from <= date_to" }, 400, { "X-Request-ID": requestId }); const offset = (rawPage - 1) * rawPageSize; const limit = rawPageSize + 1; let response: Response; try { const customerEmbed = "customers(id,name,phone,address,city)"; const itemEmbed = "order_items(id,line_no,description,quantity)"; const parcelEmbed = parcelState ? "parcels!inner(id,state,shipper_id,tracking_id)" : "parcels(id,state,shipper_id,tracking_id)"; const codEmbed = codState ? "cod_obligations!inner(state)" : "cod_obligations(state)"; const select = `id,order_number,lifecycle_state,original_amount,notes,order_date,created_at,updated_at,${customerEmbed},${itemEmbed},${parcelEmbed},${codEmbed}`; const query = new URLSearchParams({ select, order: "order_date.desc,created_at.desc,id.desc", limit: String(limit), offset: String(offset) }); if (search) { const pattern = `*${search}*`; query.set("or", `(order_number.ilike.${pattern},customers.name.ilike.${pattern},customers.phone.ilike.${pattern},customers.address.ilike.${pattern},order_items.description.ilike.${pattern})`); } if (lifecycleState) query.set("lifecycle_state", `eq.${lifecycleState}`); if (parcelState) query.set("parcels.state", `eq.${parcelState}`); if (codState) query.set("cod_obligations.state", `eq.${codState}`); if (dateFrom) query.set("order_date", `gte.${dateFrom}`); if (dateTo) query.set("order_date", `lte.${dateTo}`); response = await fetch(`${config.url}/rest/v1/orders?${query.toString()}`, { headers: { apikey: config.key, Authorization: `Bearer ${accessToken}`, Accept: "application/json" } }); } catch { logEvent("orders_request", { request_id: requestId, result: "server_error", status: 502, duration_ms: Math.round(performance.now() - startedAt), dependency: "supabase_rest", error: "upstream_request_failed" }); return json({ error: "upstream_request_failed" }, 502, { "X-Request-ID": requestId }); } const body = await response.text(); if (!response.ok) { logEvent("orders_request", { request_id: requestId, page: rawPage, page_size: rawPageSize, search: Boolean(search), lifecycle_state: lifecycleState, parcel_state: parcelState, cod_state: codState, date_from: dateFrom, date_to: dateTo, result: response.status >= 500 ? "server_error" : "client_error", status: response.status, duration_ms: Math.round(performance.now() - startedAt), dependency: "supabase_rest" }); return new Response(body, { status: response.status, headers: { "Content-Type": response.headers.get("content-type") ?? "application/json", "Cache-Control": "no-store", "X-Request-ID": requestId } }); } const parsed: unknown = (() => { try { return JSON.parse(body); } catch { return null; } })(); if (!Array.isArray(parsed)) return json({ error: "invalid_upstream_response" }, 502, { "X-Request-ID": requestId }); const hasMore = parsed.length > rawPageSize; const pageRows = hasMore ? parsed.slice(0, rawPageSize) : parsed; logEvent("orders_request", { request_id: requestId, page: rawPage, page_size: rawPageSize, search: Boolean(search), lifecycle_state: lifecycleState, parcel_state: parcelState, cod_state: codState, date_from: dateFrom, date_to: dateTo, result: "success", status: 200, returned: pageRows.length, has_more: hasMore, duration_ms: Math.round(performance.now() - startedAt), dependency: "supabase_rest" }); return new Response(JSON.stringify(pageRows), { status: 200, headers: { "Content-Type": "application/json", "Cache-Control": "no-store", "X-Request-ID": requestId, "X-Page": String(rawPage), "X-Page-Size": String(rawPageSize), "X-Has-More": String(hasMore) } }); }

async function handleOrderTimeline(request: Request, env: WorkerEnv, requestId: string, orderId: string): Promise<Response> { const startedAt = performance.now(); if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405, { "X-Request-ID": requestId }); const accessToken = getBearerToken(request); if (!accessToken) return json({ error: "authentication_required" }, 401, { "X-Request-ID": requestId }); if (!/^[0-9a-fA-F-]{36}$/.test(orderId)) return json({ error: "invalid_order_id" }, 400, { "X-Request-ID": requestId }); const config = getSupabaseConfig(env); if (!config) return json({ error: "server_not_configured" }, 503, { "X-Request-ID": requestId }); let response: Response; try { const query = new URLSearchParams({ select: "id,event_type,event_time,performed_by,notes,metadata,parcel_id", order_id: `eq.${orderId}`, order: "event_time.desc", limit: "100" }); response = await fetch(`${config.url}/rest/v1/order_events?${query.toString()}`, { headers: { apikey: config.key, Authorization: `Bearer ${accessToken}`, Accept: "application/json" } }); } catch { return json({ error: "upstream_request_failed" }, 502, { "X-Request-ID": requestId }); } const body = await response.text(); logEvent("order_timeline_request", { request_id: requestId, order_id: orderId, result: response.status >= 500 ? "server_error" : response.status >= 400 ? "client_error" : "success", status: response.status, duration_ms: Math.round(performance.now() - startedAt), dependency: "supabase_rest" }); return new Response(body, { status: response.status, headers: { "Content-Type": response.headers.get("content-type") ?? "application/json", "Cache-Control": "no-store", "X-Request-ID": requestId } }); }

async function handleCustomerHistory(request: Request, env: WorkerEnv, requestId: string, customerId: string): Promise<Response> { const startedAt = performance.now(); if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405, { "X-Request-ID": requestId }); const accessToken = getBearerToken(request); if (!accessToken) return json({ error: "authentication_required" }, 401, { "X-Request-ID": requestId }); if (!/^[0-9a-fA-F-]{36}$/.test(customerId)) return json({ error: "invalid_customer_id" }, 400, { "X-Request-ID": requestId }); const config = getSupabaseConfig(env); if (!config) return json({ error: "server_not_configured" }, 503, { "X-Request-ID": requestId }); let response: Response; try { const query = new URLSearchParams({ select: "id,order_number,order_date,lifecycle_state,original_amount", customer_id: `eq.${customerId}`, order: "order_date.desc,created_at.desc", limit: "100" }); response = await fetch(`${config.url}/rest/v1/orders?${query.toString()}`, { headers: { apikey: config.key, Authorization: `Bearer ${accessToken}`, Accept: "application/json" } }); } catch { return json({ error: "upstream_request_failed" }, 502, { "X-Request-ID": requestId }); } const body = await response.text(); logEvent("customer_history_request", { request_id: requestId, customer_id: customerId, result: response.status >= 500 ? "server_error" : response.status >= 400 ? "client_error" : "success", status: response.status, duration_ms: Math.round(performance.now() - startedAt), dependency: "supabase_rest" }); return new Response(body, { status: response.status, headers: { "Content-Type": response.headers.get("content-type") ?? "application/json", "Cache-Control": "no-store", "X-Request-ID": requestId } }); }

export default {
  async fetch(request: Request, env: WorkerEnv): Promise<Response> {
    const url = new URL(request.url);
    const requestId = getRequestId(request);
    if (url.pathname === "/api/auth/sign-in") return handleAuth(request, env, "sign-in");
    if (url.pathname === "/api/auth/session") return handleAuth(request, env, "session");
    if (url.pathname === "/api/auth/sign-out") return handleAuth(request, env, "sign-out");
    if (url.pathname === "/api/health") { logEvent("health_request", { request_id: requestId, result: "success", status: 200 }); return json({ status: "ok", service: "ecommerce-operations" }, 200, { "X-Request-ID": requestId }); }
    if (url.pathname === "/api/orders") return handleOrders(request, env, requestId);
    const timelineMatch = url.pathname.match(/^\/api\/orders\/([^/]+)\/timeline$/);
    if (timelineMatch) return handleOrderTimeline(request, env, requestId, decodeURIComponent(timelineMatch[1]));
    const historyMatch = url.pathname.match(/^\/api\/customers\/([^/]+)\/history$/);
    if (historyMatch) return handleCustomerHistory(request, env, requestId, decodeURIComponent(historyMatch[1]));
    const commandMatch = url.pathname.match(/^\/api\/commands\/([^/]+)$/);
    if (commandMatch) return handleRpc(request, env, decodeURIComponent(commandMatch[1]), requestId);
    return json({ error: "not_found" }, 404, { "X-Request-ID": requestId });
  },
};