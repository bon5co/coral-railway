# coral-railway

Railway wrapper image for [Coral Talk](https://github.com/coralproject/talk) (`coralproject/talk` 9.11.9, Apache-2.0), used by the Coral Talk template on the Railway marketplace.

Upstream needs a MongoDB URI, a Redis URI and a signing secret, and has no first account until someone opens `/install` in a browser. The wrapper:

- builds `MONGODB_URI` and `REDIS_URI` from `MONGO_HOST`, `MONGO_PASSWORD`, `REDIS_HOST` and `REDIS_PASSWORD`;
- starts the server on a loopback port, installs the tenant (named after `RAILWAY_PUBLIC_DOMAIN`), a site and the admin account from `ADMIN_EMAIL` and `ADMIN_PASSWORD`, then closes public registration through the settings API (`bootstrap.js`, idempotent on every boot);
- starts the real server on Railway's injected `PORT`, so the install page is never reachable from outside;
- patches the sign-up handler to answer 403 instead of HTTP 500 when registration is closed (the build fails if upstream renames that line).

Build: GitHub Actions `publish` pushes `ghcr.io/bon5co/coral-railway:9.11.9`.
