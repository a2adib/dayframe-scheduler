// oauth-start: the app calls this with its JWT and a platform; it returns the
// provider authorize URL carrying a signed, short-lived state (and PKCE where
// the provider supports it).
import { callbackUrl, codeChallenge, codeVerifier, providerConfig, signState } from "../_shared/providers.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return Response.json({ code: "unauthorized", message: "Missing Authorization header." }, { status: 401, headers: CORS });
  }

  const { platform } = await req.json().catch(() => ({ platform: null }));
  if (platform !== "instagram" && platform !== "x" && platform !== "linkedin" && platform !== "facebook") {
    return Response.json({ code: "bad_request", message: "Unsupported platform." }, { status: 400, headers: CORS });
  }

  // Validate the caller's JWT through the auth server.
  const authResponse = await fetch(
    `${Deno.env.get("SUPABASE_URL")}/auth/v1/user`,
    { headers: { Authorization: authHeader, apikey: Deno.env.get("SUPABASE_ANON_KEY")! } },
  );
  if (!authResponse.ok) {
    return Response.json({ code: "unauthorized", message: "Invalid session." }, { status: 401, headers: CORS });
  }
  const { id: userId } = await authResponse.json();

  const config = providerConfig(platform);
  if (!config.clientId || !config.clientSecret) {
    return Response.json(
      { code: "not_configured", message: `${platform} OAuth credentials are not configured.` },
      { status: 501, headers: CORS },
    );
  }

  const verifier = config.usesPkce ? codeVerifier() : undefined;
  const state = await signState({
    userId,
    platform,
    codeVerifier: verifier,
    exp: Date.now() + 10 * 60 * 1000,
  });

  const params = new URLSearchParams({
    response_type: "code",
    client_id: config.clientId,
    redirect_uri: callbackUrl(req, platform),
    scope: config.scopes,
    state,
  });
  if (verifier) {
    params.set("code_challenge", await codeChallenge(verifier));
    params.set("code_challenge_method", "S256");
  }

  return Response.json({ url: `${config.authorizeUrl}?${params}` }, { headers: CORS });
});
