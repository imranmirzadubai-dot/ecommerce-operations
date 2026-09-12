const ALLOWED_COMMANDS = new Set([
  "resolve_customer_by_phone",
  "create_order",
  "update_order",
  "update_order_items",
  "confirm_order",
  "cancel_order",
  "create_parcel",
  "allocate_parcel_items",
  "correct_parcel_allocation",
  "cancel_parcel",
  "dispatch_parcel",
  "bulk_dispatch",
  "record_delivery_outcome",
  "process_rto",
  "bulk_rto",
  "record_cod_receipt",
  "resolve_cod_exception",
  "record_financial_adjustment",
  "generate_invoice",
  "print_invoice",
  "import_preview",
  "import_commit",
]);

type WorkerEnv = Env & {
  SUPABASE_URL?: string;
  SUPABASE_PUBLISHABLE_KEY?: string;
};

function json(data: unknown, status = 200, headers?: HeadersInit): Response {
  return Response.json(data, {
    status,
    headers: {
      "Cache-Control": "no-store",
      ...headers,
    },
  });
}

function getBearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization");
  if (!authorization) return null;
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

function getRequestId(request: Request): string {
  const supplied = request.headers.get("X-Request-ID")?.trim();
  if (supplied && /^[A-Za-z0-9._:-]{1,128}$/.test(supplied)) return supplied;
  return crypto.randomUUID();
}

function getSupabaseConfig(env: WorkerEnv) {
  if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) return null;
  return {
    url: env.SUPABASE_URL.replace(/\/$/, ""),
    key: env.SUPABASE_PUBLISHABLE_KEY,
  };
}

function logEvent(event: string, fields: Record<string, unknown>) {
  console.log(JSON.stringify({ event, ...fields }));
}

async function handleRpc(
  request: Request,
  env: WorkerEnv,
  commandName: string,
  requestId: string,
): Promise<Response> {
  const startedAt = performance.now();
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405, { "X-Request-ID": requestId });
  if (!ALLOWED_COMMANDS.has(commandName)) return json({ error: "command_not_allowed" }, 404, { "X-Request-ID": requestId });

  const accessToken = getBearerToken(request);
  if (!accessToken) return json({ error: "authentication_required" }, 401, { "X-Request-ID": requestId });

  const config = getSupabaseConfig(env);
  if (!config) {
    logEvent("command_request", { request_id: requestId, command: commandName, result: "server_error", status: 503 });
    return json({ error: "server_not_configured" }, 503, { "X-Request-ID": requestId });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400, { "X-Request-ID": requestId });
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "request_body_must_be_object" }, 400, { "X-Request-ID": requestId });
  }

  let rpcResponse: Response;
  try {
    rpcResponse = await fetch(
      `${config.url}/rest/v1/rpc/${encodeURIComponent(commandName)}`,
      {
        method: "POST",
        headers: {
          apikey: config.key,
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(body),
      },
    );
  } catch {
    logEvent("command_request", {
      request_id: requestId,
      command: commandName,
      result: "server_error",
      status: 502,
      duration_ms: Math.round(performance.now() - startedAt),
      dependency: "supabase_rest",
      error: "upstream_request_failed",
    });
    return json({ error: "upstream_request_failed" }, 502, { "X-Request-ID": requestId });
  }

  const responseBody = await rpcResponse.text();
  const result = rpcResponse.status >= 500 ? "server_error" : rpcResponse.status >= 400 ? "client_error" : "success";
  logEvent("command_request", {
    request_id: requestId,
    command: commandName,
    result,
    status: rpcResponse.status,
    duration_ms: Math.round(performance.now() - startedAt),
    dependency: "supabase_rest",
  });

  return new Response(responseBody, {
    status: rpcResponse.status,
    headers: {
      "Content-Type": rpcResponse.headers.get("content-type") ?? "application/json",
      "Cache-Control": "no-store",
      "X-Request-ID": requestId,
    },
  });
}

async function handleOrders(request: Request, env: WorkerEnv, requestId: string): Promise<Response> {
  const startedAt = performance.now();
  if (request.method !== "GET") return json({ error: "method_not_allowed" }, 405, { "X-Request-ID": requestId });
  const accessToken = getBearerToken(request);
  if (!accessToken) return json({ error: "authentication_required" }, 401, { "X-Request-ID": requestId });
  const config = getSupabaseConfig(env);
  if (!config) return json({ error: "server_not_configured" }, 503, { "X-Request-ID": requestId });

  let response: Response;
  try {
    response = await fetch(
      `${config.url}/rest/v1/orders?select=id,order_number,lifecycle_state,original_amount,created_at,updated_at,customers(name,phone)&order=created_at.desc&limit=50`,
      {
        headers: {
          apikey: config.key,
          Authorization: `Bearer ${accessToken}`,
          Accept: "application/json",
        },
      },
    );
  } catch {
    logEvent("orders_request", {
      request_id: requestId,
      result: "server_error",
      status: 502,
      duration_ms: Math.round(performance.now() - startedAt),
      dependency: "supabase_rest",
      error: "upstream_request_failed",
    });
    return json({ error: "upstream_request_failed" }, 502, { "X-Request-ID": requestId });
  }

  const body = await response.text();
  logEvent("orders_request", {
    request_id: requestId,
    result: response.status >= 500 ? "server_error" : response.status >= 400 ? "client_error" : "success",
    status: response.status,
    duration_ms: Math.round(performance.now() - startedAt),
    dependency: "supabase_rest",
  });

  return new Response(body, {
    status: response.status,
    headers: {
      "Content-Type": response.headers.get("content-type") ?? "application/json",
      "Cache-Control": "no-store",
      "X-Request-ID": requestId,
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const requestId = getRequestId(request);

    if (url.pathname === "/api/health") {
      logEvent("health_request", { request_id: requestId, result: "success", status: 200 });
      return json({ status: "ok", service: "ecommerce-operations" }, 200, { "X-Request-ID": requestId });
    }

    if (url.pathname === "/api/orders") {
      return handleOrders(request, env as WorkerEnv, requestId);
    }

    if (url.pathname.startsWith("/api/commands/")) {
      const commandName = decodeURIComponent(url.pathname.slice("/api/commands/".length));
      return handleRpc(request, env as WorkerEnv, commandName, requestId);
    }

    logEvent("http_request", { request_id: requestId, result: "client_error", status: 404 });
    return new Response(null, { status: 404, headers: { "X-Request-ID": requestId } });
  },
} satisfies ExportedHandler<Env>;
