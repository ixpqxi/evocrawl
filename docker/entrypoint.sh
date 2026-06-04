#!/usr/bin/env bash
set -euo pipefail

cd /opt/evocrawl
export PATH="/opt/evocrawl/node_modules/.bin:$PATH"

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

APPNAME="${APPNAME:-kanboard}"
MODE="${MODE:-Crawler}"
INPUT="${INPUT:-1}"
RESTART_KAFKA="${RESTART_KAFKA:-1}"
START_CRAWLER="${START_CRAWLER:-1}"

mkdir -p data inputs_detection/data

render_login_config() {
  local source_config="${EVOCRAWL_LOGIN_CONFIG_SOURCE:-/opt/evocrawl/utils-evo/login_information.defaults.json}"
  local target_config="${EVOCRAWL_LOGIN_CONFIG_TARGET:-/opt/evocrawl/utils-evo/login_information.json}"

  if [ ! -f "$source_config" ]; then
    cp "$target_config" "$source_config"
  fi

  node docker/render-login-config.js
}

cleanup() {
  pm2 stop all >/dev/null 2>&1 || true
  while read -r session; do
    [ -n "$session" ] && screen -S "$session" -X quit >/dev/null 2>&1 || true
  done < <(screen -ls 2>/dev/null | awk '/pts/ {print $1}')
}

trap 'cleanup; exit 0' INT TERM

render_login_config

prepare_mysql_binlog_helper() {
  if [ "$INPUT" != "1" ]; then
    return 0
  fi

  if [ ! -S /var/run/docker.sock ] || ! command -v docker >/dev/null 2>&1; then
    echo "Input insertion detection requested, but Docker socket/CLI is unavailable."
    echo "Set INPUT=0 or mount /var/run/docker.sock into the evocrawl service."
    return 0
  fi

  for _ in $(seq 1 60); do
    if docker inspect mysql-test >/dev/null 2>&1; then
      docker exec mysql-test bash -lc "mkdir -p /home/data" >/dev/null 2>&1 || true
      docker cp inputs_detection/docker_log_convert.sh mysql-test:/home/docker_log_convert.sh >/dev/null
      docker exec mysql-test chmod +x /home/docker_log_convert.sh >/dev/null 2>&1 || true
      return 0
    fi
    sleep 2
  done

  echo "mysql-test container was not visible through Docker CLI; input insertion detection may fail."
}

prepare_mysql_binlog_helper

if [ "$START_CRAWLER" = "1" ]; then
  bash ./start_process.sh -i "$INPUT" -a "$APPNAME" -m "$MODE" -s "$RESTART_KAFKA"
else
  echo "START_CRAWLER=0; container is ready for manual commands."
fi

while true; do
  sleep 3600 &
  wait $!
done
