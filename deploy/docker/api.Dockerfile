ARG ELIXIR_IMAGE=hexpm/elixir:1.18.4-erlang-27.3.4-debian-bookworm-20250520-slim
ARG RUNTIME_IMAGE=debian:bookworm-20250520-slim

FROM ${ELIXIR_IMAGE} AS base
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
ENV MIX_HOME=/opt/mix HEX_HOME=/opt/hex
RUN mix local.hex --force && mix local.rebar --force && mkdir -p /opt/hex && chmod -R a+rwX /opt/mix /opt/hex
WORKDIR /app

FROM base AS dev
ENV MIX_ENV=dev
CMD ["mix", "phx.server"]

FROM base AS build
ENV MIX_ENV=prod
COPY apps/api/mix.exs apps/api/mix.lock ./
RUN mix deps.get --only prod && mix deps.compile
COPY apps/api/config config
COPY apps/api/lib lib
COPY apps/api/priv priv
COPY packages/config-schemas/schemas priv/config_schemas
RUN mix compile && mix release

FROM ${RUNTIME_IMAGE} AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && useradd --system --uid 10001 --home /app satops
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 MIX_ENV=prod PHX_SERVER=true
WORKDIR /app
COPY --from=build --chown=satops:satops /app/_build/prod/rel/sat_ops ./
USER satops
EXPOSE 4000
HEALTHCHECK --interval=15s --timeout=3s --start-period=30s CMD curl -fsS http://127.0.0.1:4000/api/health || exit 1
CMD ["/app/bin/sat_ops", "start"]
