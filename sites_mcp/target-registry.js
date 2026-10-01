import { KNOWN_CAPABILITIES } from "./policy.js";

const ALLOWED_FIELDS = new Set([
  "id",
  "label",
  "platform",
  "executor",
  "capabilities",
  "tags",
]);

const HOST_CAPABILITIES = new Set(
  KNOWN_CAPABILITIES.filter((capability) =>
    !["policy_info", "target_discovery"].includes(capability)
  )
);

const ID_RE = /^[a-z0-9][a-z0-9._-]{0,63}$/;
const PLATFORM_RE = /^[a-z0-9][a-z0-9._-]{0,31}$/;

function fail(detail) {
  throw new Error(detail);
}

function validateString(value, name, maxLength) {
  if (typeof value !== "string" || !value.trim() || value.length > maxLength) {
    fail(`${name} must be a non-empty string up to ${maxLength} characters`);
  }
  return value.trim();
}

export function validateTarget(target) {
  if (!target || typeof target !== "object" || Array.isArray(target)) {
    fail("target must be an object");
  }

  const unknownFields = Object.keys(target).filter(
    (field) => !ALLOWED_FIELDS.has(field)
  );
  if (unknownFields.length > 0) {
    fail(`target contains unsupported fields: ${unknownFields.sort().join(", ")}`);
  }

  const id = validateString(target.id, "target.id", 64);
  if (!ID_RE.test(id)) {
    fail("target.id must use lowercase letters, digits, dot, underscore, or hyphen");
  }

  const label = validateString(target.label, "target.label", 80);
  const platform = validateString(target.platform, "target.platform", 32);
  if (!PLATFORM_RE.test(platform)) {
    fail("target.platform must use lowercase letters, digits, dot, underscore, or hyphen");
  }

  if (target.executor !== "host_local_executor") {
    fail('target.executor must be "host_local_executor"');
  }

  if (!Array.isArray(target.capabilities) || target.capabilities.length === 0) {
    fail("target.capabilities must be a non-empty array");
  }
  if (target.capabilities.length > HOST_CAPABILITIES.size) {
    fail("target.capabilities contains too many entries");
  }

  const capabilities = [...new Set(target.capabilities)];
  if (
    capabilities.length !== target.capabilities.length ||
    capabilities.some(
      (capability) =>
        typeof capability !== "string" || !HOST_CAPABILITIES.has(capability)
    )
  ) {
    fail("target.capabilities must contain unique documented host-local capability IDs");
  }

  const tags = target.tags ?? [];
  if (!Array.isArray(tags) || tags.length > 8) {
    fail("target.tags must be an array with at most 8 entries");
  }
  const normalizedTags = tags.map((tag) => validateString(tag, "target.tags[]", 32));

  return Object.freeze({
    id,
    label,
    platform,
    executor: "host_local_executor",
    capabilities: Object.freeze(capabilities),
    tags: Object.freeze(normalizedTags),
  });
}

export function loadTargets(env = {}) {
  const raw = env.MCP_SHELL_TARGETS_JSON;
  if (raw === undefined || raw === null || String(raw).trim() === "") {
    return Object.freeze([]);
  }

  let parsed;
  try {
    parsed = JSON.parse(String(raw));
  } catch {
    fail("MCP_SHELL_TARGETS_JSON must be valid JSON");
  }

  if (!Array.isArray(parsed)) {
    fail("MCP_SHELL_TARGETS_JSON must be a JSON array");
  }
  if (parsed.length > 32) {
    fail("MCP_SHELL_TARGETS_JSON must contain at most 32 targets");
  }

  const targets = parsed.map(validateTarget);
  const ids = targets.map((target) => target.id);
  if (new Set(ids).size !== ids.length) {
    fail("target ids must be unique");
  }

  return Object.freeze(targets);
}
