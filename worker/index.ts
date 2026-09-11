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

function json(data: unknown, status = 200): Response {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

function getBearerToken(request: Request): string | null {
  const authorization = request.headers.get("Authorization");
  if (!authorization) return null;
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

async function handleRpc(
  request: Request,
  env: WorkerEnv,
  commandName: string,
): Promise<Response> {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!ALLOWED_COMMANDS.has(commandName)) return json({ error: "command_not_allowed" }, 404);

  const accessToken = getBearerToken(request);
  if (!accessToken) return json({ error: "authentication_required" }, 401);

  if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
    console.error("Supabase Worker configuration is missing");
    return json({ error: "server_not_configured" }, 503);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json({ error: "request_body_must_be_object" }, 400);
  }

  const rpcResponse = await fetch(
    `${env.SUPABASE_URL.replace(/\/$/, "")}/rest/v1/rpc/${encodeURIComponent(commandName)}`,
    {
      method: "POST",
      headers: {
        apikey: env.SUPABASE_PUBLISHABLE_KEY,
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    },
  );

  return new Response(await rpcResponse.text(), {
    status: rpcResponse.status,
    headers: {
      "Content-Type": rpcResponse.headers.get("content-type") ?? "application/json",
      "Cache-Control": "no-store",
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/api/health") {
      return json({ status: "ok", service: "ecommerce-operations" });
    }

    if (url.pathname.startsWith("/api/commands/")) {
      const commandName = decodeURIComponent(url.pathname.slice("/api/commands/".length));
      return handleRpc(request, env as WorkerEnv, commandName);
    }

    return new Response(null, { status: 404 });
  },
} satisfies ExportedHandler<Env>;
