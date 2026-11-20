# Coral Talk wrapper for Railway. Upstream is a Node server that needs a MongoDB URI, a Redis URI and a signing secret, listens
# on its own PORT, and has no first account until someone opens /install in a browser (a race the first visitor wins). The
# wrapper builds both URIs from Railway's service variables, runs the server on a private loopback port first, installs the
# tenant with the public domain and creates the admin account from ADMIN_EMAIL and ADMIN_PASSWORD there, closes public
# registration, and only then starts the server on Railway's injected PORT, so the install page is never reachable from outside.
# upstream: coralproject/talk
FROM coralproject/talk:9.11.9@sha256:04bece445db596e7bccd7b5da3aac0b97e5efc854b049413a9c2f124c50da547

COPY --chmod=0755 boot.sh /railway-boot.sh
COPY bootstrap.js /railway-bootstrap.js

# Upstream answers a sign-up on a closed tenant with HTTP 500 and "Internal Error"; a 403 lets a client tell "refused" from "broken".
# The build fails if upstream renames the line.
RUN f=dist/core/server/app/handlers/api/auth/local/signup.js \
 && grep -q "return next(new Error(\"registration is disabled\"));" "$f" \
 && sed -i 's|return next(new Error("registration is disabled"));|return res.status(403).json({ error: { code: "REGISTRATION_DISABLED", message: "Registration is disabled." } });|' "$f" \
 && grep -q REGISTRATION_DISABLED "$f"

ENV PORT=8080 \
    ADMIN_USERNAME=admin \
    SITE_NAME=Coral \
    TRUST_PROXY=2 \
    LOGGING_LEVEL=info
EXPOSE 8080
ENTRYPOINT ["/railway-boot.sh"]
CMD ["node", "dist/index.js"]
