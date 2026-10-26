var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// workers/web/index.mjs
var DEFAULT_APPLE_TEAM_ID = "2V25DVST23";
var DEFAULT_IOS_BUNDLE_ID = "tw.avianjay.taiwanbus.flutter";
var DEFAULT_APP_CLIP_BUNDLE_ID = `${DEFAULT_IOS_BUNDLE_ID}.Clip`;
function trimTrailingSlash(value, fallback) {
  const normalized = `${value ?? ""}`.trim();
  const base = normalized || fallback;
  return base.replace(/\/+$/, "");
}
__name(trimTrailingSlash, "trimTrailingSlash");
function jsonResponse(payload, init = {}) {
  const headers = new Headers(init.headers);
  if (!headers.has("content-type")) {
    headers.set("content-type", "application/json; charset=utf-8");
  }
  if (!headers.has("cache-control")) {
    headers.set("cache-control", "no-store");
  }
  return new Response(JSON.stringify(payload, null, 2), {
    ...init,
    headers
  });
}
__name(jsonResponse, "jsonResponse");
function buildPublicBaseUrl(request, env) {
  return trimTrailingSlash(env.PUBLIC_BASE_URL, new URL(request.url).origin);
}
__name(buildPublicBaseUrl, "buildPublicBaseUrl");
function buildAppleAssociation(env) {
  const appleTeamId = `${env.APPLE_TEAM_ID ?? DEFAULT_APPLE_TEAM_ID}`.trim() || DEFAULT_APPLE_TEAM_ID;
  const iosBundleId = `${env.IOS_APP_BUNDLE_ID ?? DEFAULT_IOS_BUNDLE_ID}`.trim() || DEFAULT_IOS_BUNDLE_ID;
  const appClipBundleId = `${env.APP_CLIP_BUNDLE_ID ?? `${iosBundleId}.Clip`}`.trim() || DEFAULT_APP_CLIP_BUNDLE_ID;
  const appId = `${appleTeamId}.${iosBundleId}`;
  const clipId = `${appleTeamId}.${appClipBundleId}`;
  return {
    appId,
    clipId,
    appClipBundleId,
    payload: {
      applinks: {
        details: [
          {
            appIDs: [appId],
            components: [
              { "/": "/route/*", comment: "YABus route detail links" },
              { "/": "/search", comment: "YABus search" },
              { "/": "/nearby", comment: "YABus nearby" },
              { "/": "/favorites", comment: "YABus favorites" },
              { "/": "/announcement/*", comment: "YABus announcements" }
            ]
          }
        ]
      },
      appclips: {
        apps: [clipId]
      },
      webcredentials: {
        apps: [appId]
      }
    }
  };
}
__name(buildAppleAssociation, "buildAppleAssociation");
async function serveStatic(request, env, assetPath) {
  const assetRequest = assetPath ? new Request(new URL(assetPath, request.url), request) : request;
  const response = await env.ASSETS.fetch(assetRequest);
  const headers = new Headers(response.headers);
  const path = new URL(request.url).pathname;
  const isFont = /\.(?:otf|ttf|woff2?)$/i.test(path);
  const noStorePaths = /* @__PURE__ */ new Set([
    "/sw.js",
    "/firebase-messaging-sw.js",
    "/flutter_service_worker.js"
  ]);
  const cacheControl = noStorePaths.has(path) ? "no-store" : isFont ? "public, max-age=604800, stale-while-revalidate=2592000" : "public, max-age=0, must-revalidate";
  headers.set("cache-control", cacheControl);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}
__name(serveStatic, "serveStatic");
var web_default = {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS",
          "access-control-allow-headers": request.headers.get("access-control-request-headers") ?? "*"
        }
      });
    }
    const url = new URL(request.url);
    const appleAssociation = buildAppleAssociation(env);
    const publicBaseUrl = buildPublicBaseUrl(request, env);
    if (url.pathname === "/apple-app-site-association" || url.pathname === "/.well-known/apple-app-site-association") {
      return jsonResponse(appleAssociation.payload);
    }
    if (url.pathname === "/.well-known/appclip") {
      return jsonResponse({
        invocationURL: `${publicBaseUrl}/route/`,
        appClipBundleId: appleAssociation.appClipBundleId,
        appID: appleAssociation.clipId
      });
    }
    if (url.pathname === "/" && (request.method === "GET" || request.method === "HEAD")) {
      return serveStatic(request, env, "/landing");
    }
    return serveStatic(request, env);
  }
};

// node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-Pr5TRO/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = web_default;

// node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-Pr5TRO/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class ___Facade_ScheduledController__ {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  static {
    __name(this, "__Facade_ScheduledController__");
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof ___Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = /* @__PURE__ */ __name((request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    }, "#fetchDispatcher");
    #dispatcher = /* @__PURE__ */ __name((type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    }, "#dispatcher");
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
