import net from "node:net";
import dns from "node:dns/promises";

export const LIMITS = Object.freeze({
  maxActions: 12,
  maxSnapshotBytes: 64 * 1024,
  maxDurationMs: 30_000,
  maxRedirects: 5,
});

export const ALLOWED_ACTIONS = Object.freeze([
  "navigate",
  "follow_link",
  "click",
  "back",
]);

const BLOCKED_HOSTS = new Set(["localhost", "metadata.google.internal"]);

function isBlockedIp(host) {
  const family = net.isIP(host);
  if (!family) return false;
  if (family === 4) {
    const [a,b] = host.split(".").map(Number);
    return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) ||
      (a === 100 && b >= 64 && b <= 127) || a >= 224;
  }
  const h = host.toLowerCase();
  return h === "::1" || h === "::" || h.startsWith("fe8") || h.startsWith("fe9") ||
    h.startsWith("fea") || h.startsWith("feb") || h.startsWith("fc") || h.startsWith("fd");
}

export function validatePublicUrl(value) {
  let url;
  try { url = new URL(value); } catch { return fail("invalid_url"); }
  if (!["http:", "https:"].includes(url.protocol)) return fail("unsupported_scheme");
  const host = url.hostname.toLowerCase().replace(/\.$/, "");
  if (!host || BLOCKED_HOSTS.has(host) || host.endsWith(".localhost") || isBlockedIp(host)) {
    return fail("blocked_destination");
  }
  if (url.username || url.password) return fail("credentials_in_url");
  return { status: "ok", url: url.toString(), hostname: host };
}

export async function validateResolvedPublicUrl(value, lookup = dns.lookup) {
  const checked = validatePublicUrl(value);
  if (checked.status !== "ok") return checked;
  if (net.isIP(checked.hostname)) return checked;
  let addresses;
  try { addresses = await lookup(checked.hostname, {all:true, verbatim:true}); }
  catch { return fail("dns_resolution_failed"); }
  if (!addresses.length || addresses.some(({address}) => isBlockedIp(address))) {
    return fail("blocked_resolved_destination");
  }
  return {...checked, resolved_addresses: addresses.map(x=>x.address)};
}

export function validateAction(action) {
  if (!action || typeof action !== "object") return fail("invalid_action");
  if (!ALLOWED_ACTIONS.includes(action.type)) return fail("action_not_allowed");
  if (action.type === "navigate") return validatePublicUrl(action.url);
  if (["follow_link","click"].includes(action.type) &&
      (typeof action.ref !== "string" || !/^[A-Za-z0-9_-]{1,80}$/.test(action.ref))) {
    return fail("invalid_ref");
  }
  return { status: "ok", action };
}

function fail(detail) { return { status: "failed", error: "policy_rejected", detail }; }
