# Headless co-op server for Linux and macOS hosts.
# Build from the HORROR-GAME folder:  docker build -f server/Dockerfile -t empty-school-server .
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2-stable

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates curl unzip \
	&& curl -fsSL -o /tmp/godot.zip \
		"https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
	&& unzip -q /tmp/godot.zip -d /tmp \
	&& mv "/tmp/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot \
	&& rm -rf /tmp/godot.zip /var/lib/apt/lists/*

WORKDIR /game
COPY . /game
RUN godot --headless --path /game --import

ENV NEUMANN_PORT=7777 \
	NEUMANN_MAX_PLAYERS=4 \
	NEUMANN_PUBLIC_HOST= \
	NEUMANN_CODE=

EXPOSE 7777/udp
ENTRYPOINT ["godot", "--headless", "--path", "/game", "res://scenes/dedicated_server.tscn", "--"]
