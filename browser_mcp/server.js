import { prepareAction, prepareGoal, createSession } from "./contracts.js";
import { LIMITS } from "./policy.js";

function unavailable(detail) {
  return { status: "failed", error: "runtime_unavailable", detail };
}

function browserFailure(phase, error) {
  return {
    status: "failed",
    error: "browser_error",
    phase,
    detail: error instanceof Error ? error.message : String(error),
  };
}

async function callRuntime(phase, operation) {
  try {
    return await operation();
  } catch (error) {
    return browserFailure(phase, error);
  }
}

function validateSnapshotResult(result) {
  if (typeof result?.snapshot === "string" &&
      Buffer.byteLength(result.snapshot, "utf8") > LIMITS.maxSnapshotBytes) {
    return { status:"failed", error:"budget_exceeded", detail:"snapshot exceeds policy" };
  }
  return result;
}

function boundedCandidates(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 100).flatMap((candidate) => {
    if (!candidate || typeof candidate !== "object" || typeof candidate.ref !== "string") return [];
    return [{
      ref: candidate.ref,
      name: typeof candidate.name === "string" ? candidate.name.slice(0, 200) : "",
      href: typeof candidate.href === "string" ? candidate.href : "",
    }];
  });
}

function runtimeMetrics(runtime) {
  try {
    return typeof runtime?.metrics === "function" ? runtime.metrics() : null;
  } catch {
    return null;
  }
}

async function askJudge(judge, input, deadline) {
  const remaining = deadline - Date.now();
  if (remaining <= 0) {
    return { status:"failed", error:"budget_exceeded", detail:"goal duration budget exceeded" };
  }

  let timer;
  try {
    const decision = await Promise.race([
      Promise.resolve().then(() => judge(input)),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          const error = new Error("judge exceeded goal duration budget");
          error.code = "JUDGE_TIMEOUT";
          reject(error);
        }, remaining);
      }),
    ]);
    if (!decision || typeof decision !== "object") {
      return { status:"failed", error:"judge_invalid", detail:"judge must return a decision object" };
    }
    return { status:"ok", decision };
  } catch (error) {
    return {
      status:"failed",
      error: error?.code === "JUDGE_TIMEOUT" ? "judge_timeout" : "judge_failed",
      detail: error instanceof Error ? error.message : String(error),
    };
  } finally {
    if (timer) clearTimeout(timer);
  }
}

export async function navigate(args, runtime) {
  const session = createSession({ start_url: args?.url });
  if (session.status !== "ok") return session;
  if (!runtime?.navigate) return unavailable("Playwright runtime adapter is not configured");
  return callRuntime("navigate", () => runtime.navigate(session.start_url, session.limits));
}

export async function observe(_args, runtime) {
  if (!runtime?.snapshot) return unavailable("Playwright runtime adapter is not configured");
  const result = await callRuntime("observe", () => runtime.snapshot());
  return validateSnapshotResult(result);
}

export async function act({ action } = {}, runtime) {
  const checked = prepareAction(action);
  if (checked.status !== "ok") return checked;
  if (!runtime?.act) return unavailable("Playwright runtime adapter is not configured");
  return callRuntime("act", () => runtime.act(action));
}

export async function verify(_args, runtime) {
  if (!runtime?.verify) return unavailable("Playwright verification adapter is not configured");
  const result = await callRuntime("verify", () => runtime.verify());
  return validateSnapshotResult(result);
}

export async function executeGoal(args, runtime, judge = null) {
  const plan = prepareGoal(args);
  if (plan.status !== "ok") return plan;
  if (typeof judge !== "function") {
    return { status:"failed", error:"judge_unavailable", detail:"bounded goal execution requires an advisory judge" };
  }
  if (!runtime?.navigate || !runtime?.snapshot || !runtime?.act || !runtime?.verify) {
    return unavailable("bounded Playwright runtime is not fully configured");
  }

  const deadline = Date.now() + LIMITS.maxDurationMs;
  let actions = 0;

  const navigated = await navigate({url:plan.start_url}, runtime);
  if (navigated.status !== "ok") return navigated;
  actions += 1;

  let observed = await observe({}, runtime);
  if (observed.status !== "ok") return observed;

  while (true) {
    const candidates = boundedCandidates(observed.candidates);
    const judged = await askJudge(judge, {
      goal: plan.goal,
      url: observed.url ?? navigated.url ?? null,
      snapshot: observed.snapshot,
      candidates,
      actions_used: actions,
      actions_remaining: Math.max(0, plan.max_actions - actions),
    }, deadline);

    if (judged.status !== "ok") {
      return {...judged, actions, metrics:runtimeMetrics(runtime)};
    }

    const decision = judged.decision;
    if (decision.decision === "complete") {
      return {
        status:"ok",
        goal:plan.goal,
        url:observed.url ?? navigated.url ?? null,
        actions,
        verification:{deterministic:"ok", semantic:"complete"},
        metrics:runtimeMetrics(runtime),
      };
    }

    if (decision.decision !== "act" || typeof decision.candidate_ref !== "string") {
      return {
        status:"failed",
        error:"judge_invalid",
        detail:"judge must return complete or choose a supplied candidate_ref",
        actions,
        metrics:runtimeMetrics(runtime),
      };
    }

    if (actions >= plan.max_actions) {
      return {
        status:"failed",
        error:"budget_exceeded",
        detail:"goal action budget exhausted",
        actions,
        metrics:runtimeMetrics(runtime),
      };
    }

    const candidate = candidates.find((item) => item.ref === decision.candidate_ref);
    if (!candidate) {
      return {
        status:"failed",
        error:"judge_invalid",
        detail:"judge selected a candidate that was not supplied",
        actions,
        metrics:runtimeMetrics(runtime),
      };
    }

    const action = {type:"follow_link", ref:candidate.ref};
    const checked = prepareAction(action);
    if (checked.status !== "ok") return checked;

    const acted = await act({action}, runtime);
    if (acted.status !== "ok") return {...acted, actions, metrics:runtimeMetrics(runtime)};
    actions += 1;

    const verified = await verify({}, runtime);
    if (verified.status !== "ok") return {...verified, actions, metrics:runtimeMetrics(runtime)};
    observed = verified;
  }
}

export const tools = Object.freeze([
  { name:"browser_navigate", readOnlyHint:true, openWorldHint:true },
  { name:"browser_observe", readOnlyHint:true, openWorldHint:true },
  { name:"browser_act", readOnlyHint:false, openWorldHint:true },
  { name:"browser_verify", readOnlyHint:true, openWorldHint:true },
  { name:"browser_execute_goal", readOnlyHint:false, openWorldHint:true },
]);
