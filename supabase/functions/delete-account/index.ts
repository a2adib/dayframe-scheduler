// delete-account: permanently deletes the calling user. Removing the auth user
// cascades to profiles and every user-owned table (all reference profiles(id)
// with on delete cascade). Platform tokens stored in Vault are deleted first
// so no orphaned secrets remain.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SERVICE_HEADERS = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") {
    return Response.json({ code: "method_not_allowed" }, { status: 405, headers: CORS });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return Response.json({ code: "unauthorized", message: "Missing Authorization header." }, { status: 401, headers: CORS });
  }

  // Resolve the caller from their own JWT; never trust a user id in the body.
  const userResponse = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { Authorization: authHeader, apikey: Deno.env.get("SUPABASE_ANON_KEY")! },
  });
  if (!userResponse.ok) {
    return Response.json({ code: "unauthorized", message: "Invalid session." }, { status: 401, headers: CORS });
  }
  const { id: userId } = await userResponse.json();

  // Delete Vault secrets referenced by the user's channels.
  const channelsResponse = await fetch(
    `${SUPABASE_URL}/rest/v1/channels?user_id=eq.${userId}&select=token_secret_id`,
    { headers: SERVICE_HEADERS },
  );
  if (channelsResponse.ok) {
    const channels = await channelsResponse.json() as Array<{ token_secret_id: string | null }>;
    for (const { token_secret_id } of channels) {
      if (!token_secret_id) continue;
      await fetch(`${SUPABASE_URL}/rest/v1/rpc/delete_token_secret`, {
        method: "POST",
        headers: SERVICE_HEADERS,
        body: JSON.stringify({ p_secret_id: token_secret_id }),
      }).catch(() => undefined);
    }
  }

  // Delete the user's uploaded media files.
  const listResponse = await fetch(`${SUPABASE_URL}/storage/v1/object/list/media`, {
    method: "POST",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ prefix: `${userId}/`, limit: 1000 }),
  });
  if (listResponse.ok) {
    // Objects live under <user>/<post>/<file>; list returns the post folders.
    const folders = await listResponse.json() as Array<{ name: string }>;
    for (const folder of folders) {
      const filesResponse = await fetch(`${SUPABASE_URL}/storage/v1/object/list/media`, {
        method: "POST",
        headers: SERVICE_HEADERS,
        body: JSON.stringify({ prefix: `${userId}/${folder.name}/`, limit: 1000 }),
      });
      if (!filesResponse.ok) continue;
      const files = await filesResponse.json() as Array<{ name: string }>;
      const prefixes = files.map((file) => `${userId}/${folder.name}/${file.name}`);
      if (prefixes.length === 0) continue;
      await fetch(`${SUPABASE_URL}/storage/v1/object/media`, {
        method: "DELETE",
        headers: SERVICE_HEADERS,
        body: JSON.stringify({ prefixes }),
      });
    }
  }

  // Delete the auth user; database rows cascade from profiles.
  const deleteResponse = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`, {
    method: "DELETE",
    headers: SERVICE_HEADERS,
  });
  if (!deleteResponse.ok) {
    return Response.json(
      { code: "delete_failed", message: `Could not delete the account (${deleteResponse.status}).` },
      { status: 500, headers: CORS },
    );
  }

  return Response.json({ deleted: true }, { headers: CORS });
});
