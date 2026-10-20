FROM rust:1.82-bookworm AS build
WORKDIR /src
RUN apt-get update && apt-get install -y --no-install-recommends cmake protobuf-compiler && rm -rf /var/lib/apt/lists/*
COPY . .
RUN cargo build --release --locked

FROM debian:bookworm-slim
COPY --from=build /src/target/release/meter-ingest /usr/local/bin/meter-ingest
USER 65532
ENTRYPOINT ["/usr/local/bin/meter-ingest"]
