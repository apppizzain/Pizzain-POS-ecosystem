import { timingSafeEqual } from "node:crypto";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const encoder = new TextEncoder();
const uuid = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;

Deno.serve(async (request) => {
  if (request.method !== "POST") return Response.json({}, { status: 405 });
  const secret = Deno.env.get("ANTERIN_PILOT_BRIDGE_SECRET") || "";
  if (secret.length < 32) return Response.json({}, { status: 503 });
  const expected = encoder.encode(`Bearer ${secret}`);
  const supplied = encoder.encode(request.headers.get("authorization") || "");
  if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) {
    return Response.json({}, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const driverId = typeof body?.driverId === "string" ? body.driverId.trim() : "";
  if (!driverId || driverId.length > 128) return Response.json({}, { status: 400 });

  const client = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  if (body.action === "feed") {
    // Fresin's authenticated transport forwards an optional order ID with a feed request.
    if (body.orderId !== undefined) {
      if (typeof body.orderId !== "string" || !uuid.test(body.orderId)) {
        return Response.json({}, { status: 400 });
      }
      const { data, error } = await client.rpc("pizzain_anterin_order_detail", {
        p_driver_id: driverId,
        p_order_id: body.orderId,
      });
      if (error) return Response.json({}, { status: 502 });
      return data
        ? Response.json({ order: data }, { headers: { "Cache-Control": "no-store" } })
        : Response.json({}, { status: 404 });
    }
    const revision = typeof body.revision === "string" && /^[a-f0-9]{64}$/.test(body.revision) ? body.revision : null;
    const { data, error } = await client.rpc("sync_pizzain_anterin_feed", {
      p_driver_id: driverId,
      p_revision: revision,
    });
    return error ? Response.json({}, { status: 502 }) : Response.json(data);
  }
  if (!["take", "process", "delivering", "complete"].includes(body.action) ||
      typeof body.orderId !== "string" || !uuid.test(body.orderId)) {
    return Response.json({}, { status: 400 });
  }
  const args = { p_order_id: body.orderId, p_driver_id: driverId };
  const driverName = typeof body.driverName === "string" ? body.driverName.trim() : "";
  const driverPhone = typeof body.driverPhone === "string" ? body.driverPhone.trim() : "";
  if (body.action === "take" && (!driverName || driverName.length > 128 || driverPhone.length > 64)) {
    return Response.json({}, { status: 400 });
  }
  const { data, error } = body.action === "take" ? await client.rpc("accept_pizzain_anterin_order", {
    ...args,
    p_driver_name: driverName,
    p_driver_phone: driverPhone,
  }) : await client.rpc("advance_pizzain_anterin_order", { ...args, p_action: body.action });
  if (error) return Response.json({}, { status: 502 });
  return Response.json({ accepted: data === true }, { status: data === true ? 200 : 409 });
});
