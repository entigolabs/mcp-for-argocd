# Build stages run on the NATIVE builder platform (--platform=$BUILDPLATFORM), not
# the target platform. tsup/esbuild ship a Go binary that crashes under QEMU
# emulation (fatal error: lfstack.push) when cross-building. Both outputs are
# plain, architecture-independent JavaScript (no dependency has a native addon),
# so they are safe to copy into a target-arch final image below.
FROM --platform=$BUILDPLATFORM node:24.22.3-alpine3.24 AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
# Run pnpm non-interactively: without a TTY, pnpm 10 otherwise aborts when it
# needs to purge node_modules (ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY).
ENV CI=true
RUN corepack enable
COPY . /app
WORKDIR /app

FROM base AS prod-deps
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --prod --frozen-lockfile

FROM base AS build
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile
RUN pnpm run build

# The runtime image carries only the Node.js binary, the production dependencies
# and the built output. npm, yarn and corepack are removed: nothing uses them at
# runtime and their bundled dependencies are a steady source of CVE findings.
FROM node:24.22.3-alpine3.24
RUN apk upgrade --no-cache \
    && rm -rf /usr/local/lib/node_modules /usr/local/bin/npm /usr/local/bin/npx \
       /usr/local/bin/corepack /usr/local/bin/yarn /usr/local/bin/yarnpkg /opt/yarn-*
WORKDIR /app
# package.json is needed at runtime for "type": "module".
COPY package.json /app/package.json
COPY --from=prod-deps /app/node_modules /app/node_modules
COPY --from=build /app/dist /app/dist
EXPOSE 3000
# No MCP_BIND_ADDRESS here on purpose. The image keeps the loopback default, which
# a sidecar or any other container sharing this network namespace can reach.
# Publishing a port is the case that needs a wider bind, and that stays an explicit
# `-e MCP_BIND_ADDRESS=0.0.0.0` alongside an inbound credential. See "Network
# Exposure" in the README.
#
# Split so that overriding the command only replaces the arguments, not the
# interpreter: `docker run <image> http --stateless` works as written.
ENTRYPOINT [ "node", "dist/index.js" ]
CMD [ "http" ]
USER 1000
