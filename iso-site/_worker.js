// KaadzOS ISO mirror.
//
// This Worker is deployed only as the `iso` preview branch of the `kaadzos`
// Pages project, so https://iso.kaadzos.pages.dev is a branch alias, not a
// custom domain. It streams objects from the private `kaadzos` R2 bucket
// through the R2_BUCKET binding; the bucket does not need public access.
//
// The production site (site/) is plain static assets and has no Worker, so
// this file does not affect https://kaadzos.pages.dev.

const TEXTUAL = new Set([
  "inrelease",
  "release",
  "packages",
  "sources",
]);

function contentTypeFor(key) {
  const name = key.split("/").pop().toLowerCase();

  if (TEXTUAL.has(name)) return "text/plain; charset=utf-8";
  if (name.endsWith(".iso")) return "application/x-iso9660-image";
  if (name.endsWith(".sha256") || name.endsWith(".asc") || name.endsWith(".sources") || name.endsWith(".txt")) {
    return "text/plain; charset=utf-8";
  }
  if (name.endsWith(".gz")) return "application/gzip";
  if (name.endsWith(".xz")) return "application/x-xz";
  if (name.endsWith(".deb")) return "application/vnd.debian.binary-package";
  if (name.endsWith(".gpg")) return "application/pgp-signature";
  if (name.endsWith(".json")) return "application/json";
  return "application/octet-stream";
}

function cacheControlFor(key) {
  if (key.startsWith("releases/")) return "public, max-age=3600";
  if (key.startsWith("apt/dists/")) return "public, max-age=60, must-revalidate";
  if (key.startsWith("apt/")) return "public, max-age=300";
  return "public, max-age=300";
}

function plain(status, body, extraHeaders = {}) {
  return new Response(body, {
    status,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "x-frame-options": "DENY",
      "referrer-policy": "no-referrer",
      ...extraHeaders,
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // The landing page is a normal static asset. Everything else on this
    // hostname is an object download.
    if (pathname === "/" || pathname === "/index.html") {
      return env.ASSETS.fetch(request);
    }

    if (pathname === "/health") {
      const ok = Boolean(env.R2_BUCKET);
      return new Response(JSON.stringify({ ok, service: "kaadzos-iso" }), {
        status: ok ? 200 : 503,
        headers: {
          "content-type": "application/json; charset=utf-8",
          "cache-control": "no-store",
          "x-content-type-options": "nosniff",
        },
      });
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return plain(405, "Method not allowed\n", { allow: "GET, HEAD" });
    }

    if (!env.R2_BUCKET) {
      return plain(503, "R2 binding is not configured\n", { "retry-after": "60" });
    }

    let decoded;
    try {
      decoded = decodeURIComponent(pathname);
    } catch {
      return plain(400, "Bad request\n");
    }

    const segments = decoded.split("/").filter((part) => part.length > 0);
    if (segments.some((part) => part === "." || part === ".." || part.includes("\0"))) {
      return plain(404, "Not found\n");
    }

    const key = segments.join("/");
    if (!key) return plain(404, "Not found\n");

    const range = request.headers.get("range");
    let object;
    try {
      object = await env.R2_BUCKET.get(key, range ? { range: request.headers } : undefined);
    } catch {
      if (range) {
        return plain(416, "Range not satisfiable\n", { "accept-ranges": "bytes" });
      }
      return plain(502, "Storage error\n", { "retry-after": "30" });
    }

    if (object === null) return plain(404, "Not found\n");

    const headers = new Headers();
    object.writeHttpMetadata(headers);
    headers.set("etag", object.httpEtag);
    headers.set("accept-ranges", "bytes");
    headers.set("x-content-type-options", "nosniff");
    headers.set("cache-control", cacheControlFor(key));

    const name = key.split("/").pop().toLowerCase();
    const storedType = (headers.get("content-type") || "").toLowerCase();
    if (!storedType || storedType === "application/octet-stream" || storedType === "binary/octet-stream") {
      headers.set("content-type", contentTypeFor(key));
    }

    // APT expects the compressed bytes themselves, not a transparently
    // decompressed response. Do not advertise Content-Encoding for .gz/.xz.
    if (name.endsWith(".gz") || name.endsWith(".xz")) {
      headers.delete("content-encoding");
    }

    if (!headers.has("content-disposition") && (name.endsWith(".iso") || name.endsWith(".deb"))) {
      const filename = key.split("/").pop().replace(/["\\]/g, "");
      headers.set("content-disposition", `attachment; filename="${filename}"`);
    }

    const ifNoneMatch = request.headers.get("if-none-match");
    if (ifNoneMatch) {
      const tags = ifNoneMatch
        .split(",")
        .map((tag) => tag.trim().replace(/^W\//, ""));
      if (tags.includes("*") || tags.includes(object.httpEtag.replace(/^W\//, ""))) {
        return new Response(null, { status: 304, headers });
      }
    }

    let status = 200;
    if (object.range) {
      const offset = object.range.offset ?? 0;
      const length = object.range.length ?? Math.max(0, object.size - offset);
      if (length > 0) {
        headers.set("content-range", `bytes ${offset}-${offset + length - 1}/${object.size}`);
      } else {
        headers.set("content-range", `bytes */${object.size}`);
      }
      headers.set("content-length", String(length));
      status = 206;
    } else {
      headers.set("content-length", String(object.size));
    }

    if (request.method === "HEAD") {
      if (object.body) {
        try {
          await object.body.cancel();
        } catch {
          // The body may already be closed; nothing else to do.
        }
      }
      return new Response(null, { status, headers });
    }

    return new Response(object.body, { status, headers });
  },
};
