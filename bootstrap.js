// Installs Coral's tenant, site and first admin on the loopback listener, then closes public registration.
// Idempotent: a second boot finds the tenant installed, signs in as the admin and re-applies the closed-registration setting.
// Requests carry Host: <public domain> because Coral names the tenant after the request's hostname.
const http = require("http");

const port = Number(process.argv[2]);
const domain = process.env.RAILWAY_PUBLIC_DOMAIN;
const email = process.env.ADMIN_EMAIL.trim().toLowerCase();
const password = process.env.ADMIN_PASSWORD;
const username = process.env.ADMIN_USERNAME || "admin";
const siteName = process.env.SITE_NAME || "Coral";
const origin = `https://${domain}`;

function call(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? null : JSON.stringify(body);
    const headers = { Host: domain };
    if (data) {
      headers["Content-Type"] = "application/json";
      headers["Content-Length"] = Buffer.byteLength(data);
    }
    if (token) headers.Authorization = `Bearer ${token}`;
    const req = http.request({ host: "127.0.0.1", port, method, path, headers }, (res) => {
      let text = "";
      res.on("data", (c) => (text += c));
      res.on("end", () => resolve({ status: res.statusCode, text }));
    });
    req.on("error", reject);
    if (data) req.write(data);
    req.end();
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitHealthy() {
  for (let i = 0; i < 120; i++) {
    try {
      const r = await call("GET", "/api/health");
      if (r.status === 200) return;
    } catch (e) {}
    await sleep(2000);
  }
  throw new Error("server did not become healthy on the loopback port within 240s");
}

async function install() {
  const r = await call("POST", "/api/install", {
    tenant: { organization: { name: siteName, url: origin, contactEmail: email } },
    site: { name: siteName, allowedOrigins: [origin] },
    user: { username, email, password },
  });
  if (r.status === 204) return "installed";
  if (r.status === 400 && /TENANT_INSTALLED_ALREADY/.test(r.text)) return "already installed";
  throw new Error(`install answered ${r.status}: ${r.text.slice(0, 300)}`);
}

async function login() {
  const r = await call("POST", "/api/auth/local", { email, password });
  if (r.status !== 200) return null;
  try {
    return JSON.parse(r.text).token || null;
  } catch (e) {
    return null;
  }
}

async function gql(query, token) {
  const r = await call("POST", "/api/graphql", { query }, token);
  if (r.status !== 200 || /"errors"/.test(r.text)) throw new Error(`graphql answered ${r.status}: ${r.text.slice(0, 300)}`);
  return JSON.parse(r.text).data;
}

(async () => {
  await waitHealthy();
  const state = await install();
  console.log(`[bootstrap] ${state}`);
  const token = await login();
  if (!token) {
    if (state === "installed") throw new Error("installed the admin but could not sign in with it");
    console.log("[bootstrap] the admin password no longer matches ADMIN_PASSWORD (changed in the app); leaving settings as they are");
    return;
  }
  const cur = await gql("query{settings{auth{sessionDuration}}}", token);
  const sessionDuration = cur.settings.auth.sessionDuration;
  await gql(
    `mutation{updateSettings(input:{clientMutationId:"railway",settings:{auth:{sessionDuration:${sessionDuration},integrations:{local:{allowRegistration:false}}}}}){settings{auth{integrations{local{allowRegistration}}}}}}`,
    token
  );
  const chk = await gql("query{settings{auth{integrations{local{allowRegistration}}}}}", token);
  if (chk.settings.auth.integrations.local.allowRegistration !== false) throw new Error("registration is still open after the update");
  console.log("[bootstrap] public registration closed");
})().catch((e) => {
  console.error(`[bootstrap] ${e.message}`);
  process.exit(1);
});
