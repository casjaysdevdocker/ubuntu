#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202302261313-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.com
# @@License          :  WTFPL
# @@ReadME           :  start-ubuntu.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, Feb 26, 2023 13:13 EST
# @@File             :  start-ubuntu.sh
# @@Description      :  script to start ubuntu
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :  
# @@Resource         :  
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  other/start-service
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set trap
trap -- 'retVal=$?;kill -9 $$;exit $retVal' SIGINT SIGTERM ERR EXIT
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
__cd() { [ -d "$1" ] && builtin cd "$1" || return 1; }
__curl() { curl -q -LSsf -o /dev/null "$@" &>/dev/null || return 10; }
__find() { find "$1" -mindepth 1 -type ${2:-f,d} 2>/dev/null | grep '^' || return 10; }
__pcheck() { [ -n "$(which pgrep 2>/dev/null)" ] && pgrep -x "$1" &>/dev/null || return 10; }
__pgrep() { __pcheck "$1" || ps aux 2>/dev/null | grep -Fw " $1" | grep -qv ' grep' || return 10; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__certbot() {
  [ -n "$DOMAINNAME" ] && [ -n "$CERT_BOT_MAIL" ] || { echo "The variables DOMAINNAME and CERT_BOT_MAIL are set" && exit 1; }
  [ "$SSL_CERT_BOT" = "true" ] && type -P certbot &>/dev/null || { export SSL_CERT_BOT="" && return 10; }
  certbot $1 --agree-tos -m $CERT_BOT_MAIL certonly --webroot \
    -w "${WWW_ROOT_DIR:-/data/htdocs/www}" -d $DOMAINNAME -d $DOMAINNAME \
    --put-all-related-files-into "$SSL_DIR" -key-path "$SSL_KEY" -fullchain-path "$SSL_CERT"
  return $?
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__exec_command() {
  local exitCode=0
  local cmd="${*:-bash -l}"
  echo "Executing: $cmd"
  eval $cmd || exitCode=1
  [ "$exitCode" = 0 ] || exitCode=10
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__exec_service_start() {
  [ -n "$DEBUG" ] && set -x
  local exitCode=0 cmd="${SERVICE_COMMAND:-false}"
  sleep 30
  echo "Setting up service to run as $SERVICE_USER"
  echo "Executing: $cmd "
  if [ "$SERVICE_USER" = "root" ]; then
    su_cmd() { eval "$@" || return 1; }
  elif [ "$(builtin type -P su)" ]; then
    su_cmd() { su -s /bin/sh - $SERVICE_USER -c "$@" || return 1; }
  elif [ "$(builtin type -P runuser)" ]; then
    su_cmd() { runuser -u $SERVICE_USER "$@" || return 1; }
  elif [ "$(builtin type -P sudo)" ]; then
    su_cmd() { sudo -u $SERVICE_USER "$@" || return 1; }
  else
    echo "Can not switch to $SERVICE_USER"
    exit 10
  fi
  su_cmd "$cmd" && su_cmd "touch /tmp/$SERVICE_NAME.pid" || exitCode=1
  [ "$exitCode" -ne 0 ] && exitCode=10 && rm -Rf "/tmp/$SERVICE_NAME.pid"
  return $exitCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__start_message() {
  __pgrep "$SERVICE_NAME" && [ -f "/tmp/$SERVICE_NAME.pid" ] && echo "$SERVICE_NAME is running" && exit 0
  if [ "$ENTRYPOINT_MESSAGE" = "false" ]; then
    echo "Starting services: $SERVICES_LIST"
  else
    echo "Starting services: $SERVICES_LIST on: $CONTAINER_IP_ADDRESS"
  fi
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__exec_pre_start() {
  local statusCode=0
  __start_message
  __exec_command php -S 0.0.0.0:80 -t "/data/htdocs/www" &
  statusCode+=$(($? + $statusCode))
  return $statusCode
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_backup() {
  local save="" date=""
  save="${1:-$BACKUP_DIR}"
  date="$(date '+%Y%m%d-%H%M')"
  tar cfvz "$save/$date.tar.gz" --exclude="$save" "/data" "/config"
  return $?
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set variables
DISPLAY="${DISPLAY:-}"
LANG="${LANG:-C.UTF-8}"
DOMAINNAME="${DOMAINNAME:-}"
TZ="${TZ:-America/New_York}"
PORT="${SERVICE_PORT:-$PORT}"
PHP_VERSION="${PHP_VERSION//php/}"
HOSTNAME="${HOSTNAME:-casjaysdev-ubuntu}"
HOSTADMIN="${HOSTADMIN:-root@${DOMAINNAME:-$HOSTNAME}}"
SSL_CERT_BOT="${SSL_CERT_BOT:-false}"
SSL_ENABLED="${SSL_ENABLED:-false}"
SSL_DIR="${SSL_DIR:-/config/ssl}"
SSL_CA="${SSL_CA:-$SSL_DIR/ca.crt}"
SSL_KEY="${SSL_KEY:-$SSL_DIR/server.key}"
SSL_CERT="${SSL_CERT:-$SSL_DIR/server.crt}"
SSL_CONTAINER_DIR="${SSL_CONTAINER_DIR:-/etc/ssl/CA}"
BACKUP_DIR="${BACKUP_DIR:-/config/backup}"
WWW_ROOT_DIR="${WWW_ROOT_DIR:-/data/htdocs}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-/usr/local/bin}"
DATA_DIR_INITIALIZED="${DATA_DIR_INITIALIZED:-}"
CONFIG_DIR_INITIALIZED="${CONFIG_DIR_INITIALIZED:-}"
DEFAULT_DATA_DIR="${DEFAULT_DATA_DIR:-/usr/local/share/template-files/data}"
DEFAULT_CONF_DIR="${DEFAULT_CONF_DIR:-/usr/local/share/template-files/config}"
DEFAULT_TEMPLATE_DIR="${DEFAULT_TEMPLATE_DIR:-/usr/local/share/template-files/defaults}"
CONTAINER_IP_ADDRESS="$(ip a 2>/dev/null | grep 'inet' | grep -v '127.0.0.1' | awk '{print $2}' | sed 's|/.*||g')"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Custom variables

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Overwrite variables
WORKDIR=""
SERVICE_PORT="$PORT"
SERVICE_NAME="ubuntu"
SERVICE_USER="${SERVICE_USER:-root}"
SERVICE_COMMAND="$SERVICE_NAME"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ "$SERVICE_PORT" = "443" ] && SSL_ENABLED="true"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Pre copy commands

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if this is a new container
[ -z "$DATA_DIR_INITIALIZED" ] && [ -f "/data/.docker_has_run" ] && DATA_DIR_INITIALIZED="true"
[ -z "$CONFIG_DIR_INITIALIZED" ] && [ -f "/config/.docker_has_run" ] && CONFIG_DIR_INITIALIZED="true"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create default config
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -n "$DEFAULT_TEMPLATE_DIR" ]; then
  [ -d "/config" ] && cp -Rf "$DEFAULT_TEMPLATE_DIR/." "/config/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom config files
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -n "$DEFAULT_CONF_DIR" ]; then
  [ -d "/config" ] && cp -Rf "$DEFAULT_CONF_DIR/." "/config/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom data files
if [ "$DATA_DIR_INITIALIZED" = "false" ] && [ -n "$DEFAULT_DATA_DIR" ]; then
  [ -d "/data" ] && cp -Rf "$DEFAULT_DATA_DIR/." "/data/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy html files
if [ "$DATA_DIR_INITIALIZED" = "false" ] && [ -d "$DEFAULT_DATA_DIR/data/htdocs" ]; then
  [ -d "/data" ] && cp -Rf "$DEFAULT_DATA_DIR/data/htdocs/." "$WWW_ROOT_DIR/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create the backup dir
[ -d "$BACKUP_DIR" ] || mkdir -p "$BACKUP_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Post copy commands

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initialized
[ -d "/data" ] && touch "/data/.docker_has_run"
[ -d "/config" ] && touch "/config/.docker_has_run"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# APP Variables overrides
[ -f "/root/env.sh" ] && . "/root/env.sh"
[ -f "/config/env.sh" ] && . "/config/env.sh"
[ -f "/config/.env.sh" ] && . "/config/.env.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Actions based on env

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Change to working dir
[ -n "$WORKDIR" ] && __cd "$WORKDIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# begin main app
case "$1" in
backup)
  shift 1
  __run_backup "${1:-$BACKUP_DIR}"
  ;;

certbot)
  shift 1
  SSL_CERT_BOT="true"
  if [ "$1" = "create" ]; then
    shift 1
    __certbot
  elif [ "$1" = "renew" ]; then
    shift 1
    __certbot "renew certonly --force-renew"
  else
    __exec_command "certbot" "$@"
  fi
  ;;

*)
  __exec_pre_start && __exec_service_start
  ;;
esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set exit code
exitCode="${exitCode:-$?}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# lets exit with code
exit ${exitCode:-$?}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
# ex: ts=2 sw=2 et filetype=sh
