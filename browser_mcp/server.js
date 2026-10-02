import { prepareAction, prepareGoal, createSession } from "./contracts.js";

function unavailable(detail) {
  return { status: "failed", error: "runtime_unavailable", detail };
}

export async function navigate(args, runtime) {
  const session = createSession({ start_url: args?.url });
  if (session.status !== "ok") return session;
  if (!runtime?.navigate) return unavailable("Playwright runtime adapter is not configured");
  return runtime.navigate(session.start_url, session.limits);
}

export async function observe(_args, runtime) {
  if (!runtime?.snapshot) return unavailable("Playwright runtime adapter is not configured");
  const result = await runtime.snapshot();
  if (typeof result?.snapshot === "string" &&
      Buffer.byteLength(result.snapshot, "utf8") > createSession({start_url:"https://example.com"}).limits.maxSnapshotBytes) {
    return { status:"failed", error:"budget_exceeded", detail:"snapshot exceeds policy" };
  }
  return result;
}

export async function act({ action } = {}, runtime) {
  const checked = prepareAction(action);
  if (checked.status !== "ok") return checked;
  if (!runtime?.act) return unavailable("Playwright runtime adapter is not configured");
  return runtime.act(action);
}

export async function executeGoal(args, runtime, judge = null) {
  const plan = prepareGoal(args);
  if (plan.status !== "ok") return plan;
  if (!runtime?.runBoundedGoal) return unavailable("bounded Playwright loop is not configured");
  return runtime.runBoundedGoal(plan, {
    judge,
    deterministicPolicy: "browser_mcp/policy.js",
  });
}

export const tools = Object.freeze([
  { name:"browser_navigate", readOnlyHint:true, openWorldHint:true },
  { name:"browser_observe", readOnlyHint:true, openWorldHint:true },
  { name:"browser_act", readOnlyHint:false, openWorldHint:true },
  { name:"browser_execute_goal", readOnlyHint:false, openWorldHint:true },
]);
