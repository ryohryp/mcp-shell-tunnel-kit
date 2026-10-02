import { LIMITS, validateAction, validatePublicUrl } from "./policy.js";

export function createSession({ start_url } = {}) {
  const checked = validatePublicUrl(start_url);
  if (checked.status !== "ok") return checked;
  return {
    status: "ok",
    mode: "isolated_public_read",
    start_url: checked.url,
    limits: LIMITS,
    authenticated_profile: false,
  };
}

export function prepareAction(action) {
  return validateAction(action);
}

export function prepareGoal({ goal, start_url, max_actions = LIMITS.maxActions } = {}) {
  if (typeof goal !== "string" || !goal.trim() || goal.length > 1000) {
    return { status: "failed", error: "invalid_input", detail: "goal must be 1..1000 characters" };
  }
  const checked = validatePublicUrl(start_url);
  if (checked.status !== "ok") return checked;
  if (!Number.isInteger(max_actions) || max_actions < 1 || max_actions > LIMITS.maxActions) {
    return { status: "failed", error: "invalid_input", detail: "max_actions exceeds policy" };
  }
  return {
    status: "ok",
    goal: goal.trim(),
    start_url: checked.url,
    max_actions,
    execution: "gce_local_loop",
    jev_role: "bounded_candidate_choice_and_semantic_verification_only",
  };
}
