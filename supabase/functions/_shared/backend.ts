// Shared Supabase/service helpers for the Dayframe Edge Functions.
import { providerConfig, type Platform } from "./providers.ts";

export const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
export const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
export const SERVICE_HEADERS = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  "Content-Type": "application/json",
};

export function requireServiceRole(req: Request): boolean {
  return (req.headers.get("Authorization") ?? "") === `Bearer ${SERVICE_KEY}`;
}

export async function rpc<T>(name: string, args: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: SERVICE_HEADERS,
    body: JSON.stringify(args),
  });
  if (!response.ok) throw new Error(`rpc ${name} failed: ${response.status}`);
  return response.json() as Promise<T>;
}

export interface StoredToken {
  access_token: string;
  refresh_token: string | null;
  expires_at: string;
}

export interface TokenBundle {
  accessToken: string;
  refreshToken: string | null;
  expiresAt: number;
  secretId: string;
}

export async function channelRow(channelId: string): Promise<Record<string, unknown> | null> {
  const rows = await fetch(
    `${SUPABASE_URL}/rest/v1/channels?id=eq.${channelId}&select=*`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  ).then((r) => r.json());
  return rows[0] ?? null;
}

export async function loadToken(channelId: string): Promise<TokenBundle | null> {
  const channel = await channelRow(channelId);
  if (!channel?.token_secret_id) return null;
  const secret = await rpc<string>("read_token_secret", { p_secret_id: channel.token_secret_id });
  const parsed = JSON.parse(secret) as StoredToken;
  return {
    accessToken: parsed.access_token,
    refreshToken: parsed.refresh_token,
    expiresAt: Date.parse(parsed.expires_at),
    secretId: channel.token_secret_id,
  };
}

async function tokenEndpoint(platform: Platform): Promise<string> {
  const base = providerConfig(platform).apiBase;
  return platform === "x"
    ? `${base}/2/oauth2/token`
    : platform === "linkedin"
    ? `${base}/oauth/v2/accessToken`
    : `${base}/access_token`;
}

export async function refreshToken(
  platform: Platform,
  refresh: string,
): Promise<{ accessToken: string; refreshToken: string | null; expiresIn: number }> {
  const config = providerConfig(platform);
  const body = new URLSearchParams({ grant_type: "refresh_token", refresh_token: refresh });
  const headers: Record<string, string> = { "Content-Type": "application/x-www-form-urlencoded" };
  if (platform === "x") {
    headers["Authorization"] = "Basic " + btoa(`${config.clientId}:${config.clientSecret}`);
    body.set("client_id", config.clientId!);
  } else {
    body.set("client_id", config.clientId!);
    body.set("client_secret", config.clientSecret!);
  }
  const response = await fetch(tokenEndpoint(platform), { method: "POST", headers, body });
  const data = await response.json();
  if (!response.ok) throw new Error(`Token refresh failed: ${data.error ?? response.status}`);
  return { accessToken: data.access_token, refreshToken: data.refresh_token ?? refresh, expiresIn: data.expires_in ?? 3600 };
}

async function saveRefreshedToken(
  channelId: string,
  refreshed: { accessToken: string; refreshToken: string | null; expiresIn: number },
): Promise<string> {
  const expiresAt = new Date(Date.now() + refreshed.expiresIn * 1000).toISOString();
  const newSecretId = await rpc<string>("store_token_secret", {
    p_secret: JSON.stringify({
      access_token: refreshed.accessToken,
      refresh_token: refreshed.refreshToken,
      expires_at: expiresAt,
    }),
  });
  await fetch(`${SUPABASE_URL}/rest/v1/channels?id=eq.${channelId}`, {
    method: "PATCH",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ token_secret_id: newSecretId, token_expires_at: expiresAt, status: "connected" }),
  });
  return newSecretId;
}

/// X tokens live 2 h, Instagram/LinkedIn 60 days: refresh when inside the
/// window. Returns the (possibly refreshed) bundle or null when absent.
export async function ensureFreshToken(
  platform: Platform,
  channelId: string,
): Promise<TokenBundle | null> {
  const bundle = await loadToken(channelId);
  if (!bundle) return null;
  const refreshWindowMs = platform === "x" ? 30 * 60 * 1000 : 7 * 86_400 * 1000;
  if (bundle.expiresAt - Date.now() > refreshWindowMs) return bundle;
  if (!bundle.refreshToken) return bundle;
  try {
    const refreshed = await refreshToken(platform, bundle.refreshToken);
    bundle.accessToken = refreshed.accessToken;
    bundle.refreshToken = refreshed.refreshToken;
    bundle.expiresAt = Date.now() + refreshed.expiresIn * 1000;
    bundle.secretId = await saveRefreshedToken(channelId, refreshed);
  } catch {
    // The caller surfaces the auth error from the actual API call.
  }
  return bundle;
}

export async function expireChannel(channelId: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/rest/v1/channels?id=eq.${channelId}`, {
    method: "PATCH",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ status: "expired" }),
  });
}

/// Signed URLs for private storage media (Instagram requires a public URL).
export async function signedMediaUrls(paths: string[]): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  if (paths.length === 0) return result;
  const response = await fetch(`${SUPABASE_URL}/storage/v1/object/sign/media`, {
    method: "POST",
    headers: SERVICE_HEADERS,
    body: JSON.stringify({ expiresIn: 7 * 86_400, paths }),
  });
  if (!response.ok) throw new Error(`Could not sign media URLs: ${response.status}`);
  const data = await response.json() as { signedURLs?: string[]; signedUrls?: string[] };
  const urls = data.signedURLs ?? data.signedUrls ?? [];
  paths.forEach((path, index) => {
    if (urls[index]) result.set(path, `${SUPABASE_URL}/storage/v1${urls[index]}`);
  });
  return result;
}
