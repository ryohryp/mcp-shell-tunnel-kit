import { chromium } from "playwright-core";
import { validateResolvedPublicUrl, validateAction, LIMITS } from "./policy.js";

export async function createPlaywrightRuntime({ executablePath } = {}) {
  const browser = await chromium.launch({
    headless: true,
    executablePath,
    args: ["--disable-dev-shm-usage"],
  });
  const context = await browser.newContext({
    acceptDownloads: false,
    serviceWorkers: "block",
  });
  const page = await context.newPage();
  let actions = 0;
  const startedAt = Date.now();

  function budget() {
    if (actions >= LIMITS.maxActions) throw new Error("action budget exceeded");
    if (Date.now() - startedAt > LIMITS.maxDurationMs) throw new Error("duration budget exceeded");
  }

  async function guardRequest(route) {
    const checked = await validateResolvedPublicUrl(route.request().url());
    if (checked.status !== "ok") return route.abort("blockedbyclient");
    return route.continue();
  }
  await context.route("**/*", guardRequest);

  async function navigate(url) {
    budget();
    const checked = await validateResolvedPublicUrl(url);
    if (checked.status !== "ok") return checked;
    actions++;
    const response = await page.goto(checked.url, {waitUntil:"domcontentloaded", timeout:10_000});
    return {status:"ok", url:page.url(), http_status:response?.status() ?? null};
  }

  async function snapshot() {
    budget();
    const text = await page.locator("body").innerText({timeout:5_000});
    const links = await page.getByRole("link").evaluateAll((els) =>
      els.slice(0,100).map((el,i)=>({ref:`link_${i}`,name:(el.textContent||"").trim().slice(0,200),href:el.href}))
    );
    const snapshot = JSON.stringify({url:page.url(),text:text.slice(0,32000),links});
    return {status:"ok", snapshot, candidates:links};
  }

  async function act(action) {
    budget();
    const checked=validateAction(action);
    if (checked.status !== "ok") return checked;
    if (action.type === "back") { actions++; await page.goBack({waitUntil:"domcontentloaded"}); return {status:"ok",url:page.url()}; }
    if (action.type === "navigate") return navigate(action.url);
    const match=/^link_(\d+)$/.exec(action.ref ?? "");
    if (!match) return {status:"failed",error:"unsupported_ref",detail:"MVP runtime currently acts on link refs only"};
    const link=page.getByRole("link").nth(Number(match[1]));
    if (action.type === "follow_link" || action.type === "click") {
      actions++;
      await link.click({timeout:5_000});
      await page.waitForLoadState("domcontentloaded").catch(()=>{});
      return {status:"ok",url:page.url()};
    }
    return {status:"failed",error:"unsupported_action",detail:"action is not implemented by the MVP runtime"};
  }

  return {
    navigate,
    snapshot,
    act,
    async close(){ await context.close(); await browser.close(); },
    metrics(){ return {actions,elapsed_ms:Date.now()-startedAt}; },
  };
}
