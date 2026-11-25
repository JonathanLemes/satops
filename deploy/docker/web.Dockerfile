FROM node:24-bookworm-slim AS build
RUN corepack enable
WORKDIR /repo
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY apps/web/package.json apps/web/package.json
COPY packages/config-schemas/package.json packages/config-schemas/package.json
COPY packages/graphql-types/package.json packages/graphql-types/package.json
COPY examples/demo-fintech/package.json examples/demo-fintech/package.json
RUN pnpm install --frozen-lockfile --filter @satops/web...
COPY packages packages
COPY apps/web apps/web
RUN pnpm --filter @satops/web exec vite build

FROM nginx:1.29-alpine AS runtime
COPY deploy/docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/apps/web/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
