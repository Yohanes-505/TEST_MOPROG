import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const enc = new TextEncoder();

function b64url(data: string | Uint8Array): string {
  const bytes = typeof data === "string" ? enc.encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// tuker service account firebase jadi access token google
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const pem = sa.private_key
    .replace(/-----[^-]+-----/g, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      enc.encode(`${header}.${claim}`),
    ),
  );
  const jwt = `${header}.${claim}.${b64url(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const json = await res.json();
  if (!json.access_token) {
    throw new Error("Gagal ambil access token: " + JSON.stringify(json));
  }
  return json.access_token;
}

// kirim notif ke semua HP milik 1 user
async function sendToUser(
  accessToken: string,
  userId: string,
  title: string,
  body: string,
  extra: { type: string; related_id: string },
) {
  const { data: tokens, error } = await supabase
    .from("device_tokens")
    .select("token, active_match_id")
    .eq("user_id", userId);

  if (error) {
    console.error("Gagal ambil device_tokens:", error);
    return;
  }
  if (!tokens || tokens.length === 0) {
    console.log(`User ${userId} belum punya device token`);
    return;
  }

  // skip HP yang lagi buka chat ini
  const targets = extra.type === "message"
    ? tokens.filter((t) => t.active_match_id !== String(extra.related_id))
    : tokens;

  if (targets.length === 0) {
    console.log("skip: chat lagi dibuka");
    return;
  }

  const collapseKey = `${extra.type}_${extra.related_id}`;

  for (const { token } of targets) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: { ...extra, title, body },
            android: {
              priority: "HIGH",
              // tag sama = notif baru nimpa notif lama (1 chat = 1 notif)
              notification: { tag: collapseKey },
            },
            apns: {
              headers: { "apns-collapse-id": collapseKey },
              payload: { aps: { "thread-id": String(extra.related_id) } },
            },
          },
        }),
      },
    );

    if (!res.ok) {
      const errText = await res.text();
      console.error(`FCM gagal (${res.status}):`, errText);
      // token udah gak valid
      if (res.status === 404 || errText.includes("UNREGISTERED")) {
        await supabase.from("device_tokens").delete().eq("token", token);
      }
    }
  }
}

async function getName(userId: string): Promise<string> {
  const { data } = await supabase
    .from("profiles")
    .select("name")
    .eq("id", userId)
    .maybeSingle();
  return data?.name ?? "Seseorang";
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    if (payload.type !== "INSERT") {
      return new Response("ignored", { status: 200 });
    }

    const record = payload.record;
    const accessToken = await getAccessToken();

    // chat baru
    if (payload.table === "messages") {
      const { data: match } = await supabase
        .from("matches")
        .select("user1_id, user2_id")
        .eq("id", record.match_id)
        .single();
      if (!match) return new Response("match not found", { status: 200 });

      const recipientId = match.user1_id === record.sender_id
        ? match.user2_id
        : match.user1_id;

      const senderName = await getName(record.sender_id);

      // hitung pesan belum dibaca dari pengirim ini di chat ini
      const { count } = await supabase
        .from("messages")
        .select("*", { count: "exact", head: true })
        .eq("match_id", record.match_id)
        .eq("sender_id", record.sender_id)
        .eq("is_read", false);

      const unread = count ?? 1;
      const body = unread > 1
        ? `${unread} pesan baru`
        : String(record.content ?? "").slice(0, 100);

      await sendToUser(accessToken, recipientId, senderName, body, {
        type: "message",
        related_id: String(record.match_id),
      });
    }

    // match baru
    if (payload.table === "matches") {
      const [name1, name2] = await Promise.all([
        getName(record.user1_id),
        getName(record.user2_id),
      ]);

      await Promise.all([
        sendToUser(
          accessToken,
          record.user1_id,
          "It's a Match!",
          `Kamu match sama ${name2}!`,
          { type: "match", related_id: String(record.id) },
        ),
        sendToUser(
          accessToken,
          record.user2_id,
          "It's a Match!",
          `Kamu match sama ${name1}!`,
          { type: "match", related_id: String(record.id) },
        ),
      ]);
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("send-notification error:", err);
    return new Response(String(err), { status: 500 });
  }
});