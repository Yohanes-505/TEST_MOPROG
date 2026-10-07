import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MIDTRANS_SERVER_KEY = Deno.env.get("MIDTRANS_SERVER_KEY")!;
const IS_PRODUCTION = Deno.env.get("MIDTRANS_IS_PRODUCTION") === "true";

const MIDTRANS_API_BASE = IS_PRODUCTION
  ? "https://api.midtrans.com"
  : "https://api.sandbox.midtrans.com";

type AppStatus = "pending" | "settlement" | "expire" | "cancel" | "deny" | "ignore";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const notification = await req.json();
    const { order_id, status_code, gross_amount, signature_key } = notification ?? {};

    if (!order_id || !status_code || !gross_amount || !signature_key) {
      return jsonResponse({ error: "Bad payload" }, 400);
    }

    // 1) Verifikasi signature notifikasi.
    const expected = await sha512Hex(
      `${order_id}${status_code}${gross_amount}${MIDTRANS_SERVER_KEY}`,
    );
    if (!timingSafeEqual(expected, String(signature_key))) {
      console.error("Invalid signature for order:", order_id);
      return jsonResponse({ error: "Invalid signature" }, 403);
    }

    // 2) Sumber kebenaran: tanya langsung ke Midtrans.
    const verified = await fetchMidtransStatus(String(order_id));
    if (String(verified.status_code) === "404") {
      return jsonResponse({ error: "Order not found at Midtrans" }, 404);
    }

    const appStatus = mapStatus(verified.transaction_status, verified.fraud_status);
    const verifiedAmount = Number.parseFloat(String(verified.gross_amount));
    if (!Number.isFinite(verifiedAmount)) {
      throw new Error("gross_amount dari Midtrans tidak valid");
    }

    // 3) Terapkan secara atomik di database.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data, error } = await supabase.rpc("apply_midtrans_notification", {
      p_order_id: order_id,
      p_new_status: appStatus,
      p_gross_amount: verifiedAmount,
      p_payload: verified,
    });

    if (error) {
      console.error("RPC apply_midtrans_notification error:", error);
      return jsonResponse({ error: "Gagal memproses notifikasi" }, 500);
    }

    if (data?.reason === "not_found") {
      console.error("Transaction not found:", order_id);
      return jsonResponse({ error: "Transaction not found" }, 404);
    }
    if (data?.reason === "amount_mismatch") {
      // Retry tidak akan memperbaiki ini -> balas 200 supaya tidak diulang,
      // tapi tinggalkan jejak di log untuk diperiksa manual.
      console.error("AMOUNT MISMATCH", order_id, data);
    }

    return jsonResponse({ received: true, result: data?.reason ?? null });
  } catch (err) {
    console.error("Webhook error:", err);
    return jsonResponse({ error: "Terjadi kesalahan tak terduga" }, 500);
  }
});

// ---------------------------------------------------------------------

async function fetchMidtransStatus(orderId: string) {
  const res = await fetch(
    `${MIDTRANS_API_BASE}/v2/${encodeURIComponent(orderId)}/status`,
    {
      headers: {
        Accept: "application/json",
        Authorization: `Basic ${btoa(`${MIDTRANS_SERVER_KEY}:`)}`,
      },
    },
  );
  if (!res.ok) {
    throw new Error(`Midtrans status API HTTP ${res.status}`);
  }
  return await res.json();
}

function mapStatus(transactionStatus: string, fraudStatus?: string): AppStatus {
  switch (transactionStatus) {
    case "capture":
      if (fraudStatus === "accept") return "settlement";
      if (fraudStatus === "challenge") return "pending"; // tunggu review manual
      return "deny";
    case "settlement":
      return "settlement";
    case "pending":
      return "pending";
    case "expire":
      return "expire";
    case "cancel":
      return "cancel";
    case "deny":
      return "deny";
    default:
      // refund, partial_refund, chargeback, dll: belum ditangani.
      return "ignore";
  }
}

async function sha512Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest("SHA-512", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}