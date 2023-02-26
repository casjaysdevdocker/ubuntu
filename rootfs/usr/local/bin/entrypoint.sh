#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202302261313-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.com
# @@License          :  WTFPL
# @@ReadME           :  entrypoint.sh --help
# @@Copyright        :  Copyright: (c) 2023 Jason Hempstead, Casjays Developments
# @@Created          :  Sunday, Feb 26, 2023 13:13 EST
# @@File             :  entrypoint.sh
# @@Description      :  entrypoint point for ubuntu
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :  
# @@Resource         :  
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  other/docker-entrypoint
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup trap
trap 'retVal=$?;kill -9 $$;exit $retVal' SIGINT
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
[ -n "$DEBUG" ] && set -x
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
__exec_command() {
  local exitCode=0
  local cmd="${*:-bash -l}"
  echo "${exec_message:-Executing command: $cmd}"
  $cmd || exitCode=1
  [ "$exitCode" = 0 ] || exitCode=10
  return ${exitCode:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__ps() { [ -f "$(type -P ps)" ] && ps "$@" || return 10; }
__curl() { curl -q -LSsf -o /dev/null "$@" &>/dev/null || return 10; }
__netstat() { [ -f "$(type -P netstat)" ] && netstat "$@" || return 10; }
__find() { find "$1" -mindepth 1 -type ${2:-f,d} 2>/dev/null | grep '^' || return 10; }
__pcheck() { [ -n "$(which pgrep 2>/dev/null)" ] && pgrep -x "$1" &>/dev/null || return 10; }
__pgrep() { __pcheck "${1:-$SERVICE_NAME}" || __ps aux 2>/dev/null | grep -Fw " ${1:-$SERVICE_NAME}" | grep -qv ' grep' || return 10; }
__get_ip6() { ip a 2>/dev/null | grep -w 'inet6' | awk '{print $2}' | grep -vE '^::1|^fe' | sed 's|/.*||g' | head -n1 | grep '^' || echo ''; }
__get_ip4() { ip a 2>/dev/null | grep -w 'inet' | awk '{print $2}' | grep -vE '^127.0.0' | sed 's|/.*||g' | head -n1 | grep '^' || echo '127.0.0.1'; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__show_procs() {
  local ps=""
  ps="$(__ps axco command | grep -vE 'COMMAND|grep|ps' | sort -u || grep '^' || echo '')"
  [ -n "$ps" ] && printf '%s\n%s\n' "Found the following proccesses" "$ps" || return 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__listening() {
  local ports=""
  ports="$(__netstat -taupln | awk -F ' ' '{print $4}' | awk -F ':' '{print $2}' | sort --unique --version-sort | grep -v '^$' | grep '^' || echo '')"
  [ -n "$ports" ] && printf '%s\n%s\n' "The followinf are servers:" "$ports" || return 1
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__certbot() {
  [ -n "$DOMAINNAME" ] && [ -n "$CERT_BOT_MAIL" ] || { echo "The variables DOMAINNAME and CERT_BOT_MAIL are set" && exit 1; }
  [ "$SSL_CERT_BOT" = "true" ] && type -P certbot &>/dev/null || { export SSL_CERT_BOT="" && return 10; }
  certbot $1 --agree-tos -m $CERT_BOT_MAIL certonly --webroot -w "${WWW_ROOT_DIR:-/data/htdocs/www}" -d $DOMAINNAME -d $DOMAINNAME \
    --put-all-related-files-into "$SSL_DIR" -key-path "$SSL_KEY" -fullchain-path "$SSL_CERT"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__heath_check() {
  local healthStatus=0 health="Good"
  for proc in $SERVICES_LIST; do
    if ! __pgrep "$proc"; then
      echo "$proc is not running" >&2
      status=$((status + 1))
    fi
  done
  #__curl "http://localhost:$SERVICE_PORT/server-health" || healthStatus=$((healthStatus + 1))
  [ "$healthStatus" -eq 0 ] || health="Errors reported see docker logs --follow $CONTAINER_NAME"
  return $healthStatus
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__start_all_services() {
  start-ubuntu.sh
  return $?
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional functions

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# export functions
export -f __exec_command __pcheck __pgrep __find __curl __heath_check __certbot
export -f __start_all_services __get_ip4 __get_ip6
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Define default variables - do not change these - redefine with -e or set under Additional
USER="${USER:-root}"
DISPLAY="${DISPLAY:-}"
LANG="${LANG:-C.UTF-8}"
DOMAINNAME="${DOMAINNAME:-}"
TZ="${TZ:-America/New_York}"
PHP_VERSION="${PHP_VERSION//php/}"
SERVICE_USER="${SERVICE_USER:-root}"
SERVICE_PORT="${SERVICE_PORT:-$PORT}"
HOSTNAME="${HOSTNAME:-casjaysdev-ubuntu}"
HOSTADMIN="${HOSTADMIN:-root@${DOMAINNAME:-$HOSTNAME}}"
CERT_BOT_MAIL="${CERT_BOT_MAIL:-certbot-mail@casjay.net}"
SSL_CERT_BOT="${SSL_CERT_BOT:-false}"
SSL_ENABLED="${SSL_ENABLED:-false}"
SSL_DIR="${SSL_DIR:-/config/ssl}"
SSL_CA="${SSL_CA:-$SSL_DIR/ca.crt}"
SSL_KEY="${SSL_KEY:-$SSL_DIR/server.key}"
SSL_CERT="${SSL_CERT:-$SSL_DIR/server.crt}"
SSL_CONTAINER_DIR="${SSL_CONTAINER_DIR:-/etc/ssl/CA}"
WWW_ROOT_DIR="${WWW_ROOT_DIR:-/data/htdocs}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-/usr/local/bin}"
DEFAULT_DATA_DIR="${DEFAULT_DATA_DIR:-/usr/local/share/template-files/data}"
DEFAULT_CONF_DIR="${DEFAULT_CONF_DIR:-/usr/local/share/template-files/config}"
DEFAULT_TEMPLATE_DIR="${DEFAULT_TEMPLATE_DIR:-/usr/local/share/template-files/defaults}"
CONTAINER_IP_ADDRESS="$(__get_ip4)"
CONTAINER_IP6_ADDRESS="$(__get_ip6)"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional variables and variable overrides
SERVICE_NAME="ubuntu"
SERVICES_LIST="ubuntu "
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Show start message
ENTRYPOINT_MESSAGE="false"
echo "Executing entrypoint script for $SERVICE_NAME"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ "$SERVICE_PORT" = "443" ] && SSL_ENABLED="true"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if this is a new container
[ -f "/data/.docker_has_run" ] && DATA_DIR_INITIALIZED="true" || DATA_DIR_INITIALIZED="false"
[ -f "/config/.docker_has_run" ] && CONFIG_DIR_INITIALIZED="true" || CONFIG_DIR_INITIALIZED="false"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# export variables
export USER LANG TZ DOMAINNAME HOSTNAME HOSTADMIN SSL_ENABLED SSL_DIR SSL_CA
export SSL_KEY SERVICE_NAME SSL_DIR LOCAL_BIN_DIR SSL_CONTAINER_DIR SSL_CERT_BOT
export DEFAULT_CONF_DIR CONTAINER_IP_ADDRESS DISPLAY CONFIG_DIR_INITIALIZED DATA_DIR_INITIALIZED
export SERVICE_USER ENTRYPOINT_MESSAGE PHP_VERSION SERVICES_LIST
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# import variables from file
[ -f "/root/env.sh" ] && . "/root/env.sh"
[ -f "/config/env.sh" ] && . "/config/env.sh"
[ -f "/config/.env.sh" ] && . "/config/.env.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set timezone
[ -n "$TZ" ] && [ -w "/etc/timezone" ] && echo "$TZ" >"/etc/timezone"
[ -f "/usr/share/zoneinfo/$TZ" ] && [ -w "/etc/localtime" ] && ln -sf "/usr/share/zoneinfo/$TZ" "/etc/localtime"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Make sure localhost exists
if [ -w "/etc/hosts" ] && ! grep -q '127.0.0.1' /etc/hosts; then
  echo "127.0.0.1       localhost" >"/etc/hosts"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set containers hostname
[ -n "$HOSTNAME" ] && echo "$HOSTNAME" >"/etc/hostname"
if [ -w "/etc/hosts" ] && [ -n "$HOSTNAME" ]; then
  echo "${CONTAINER_IP_ADDRESS:-127.0.0.1}    $HOSTNAME $HOSTNAME.local" >>"/etc/hosts"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Add domain to hosts file
[ -n "$DOMAINNAME" ] && echo "$HOSTNAME.${DOMAINNAME:-local}" >"/etc/hostname"
if [ -w "/etc/hosts" ] && [ -n "$DOMAINNAME" ]; then
  echo "${CONTAINER_IP_ADDRESS:-127.0.0.1}    $HOSTNAME.${DOMAINNAME:-local}" >"/etc/hosts"
  echo "${CONTAINER_IP_ADDRESS:-127.0.0.1}    $HOSTNAME.$DOMAINNAME" >>"/etc/hosts"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# import hosts file into container
[ -f "/usr/local/etc/hosts" ] && cat "/usr/local/etc/hosts" >>"/etc/hosts"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Delete any gitkeep files
[ -d "/data" ] && rm -Rf "/data/.gitkeep" "/data"/*/*.gitkeep
[ -d "/config" ] && rm -Rf "/config/.gitkeep" "/data"/*/*.gitkeep
[ -f "/usr/local/bin/.gitkeep" ] && rm -Rf "/usr/local/bin/.gitkeep"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create directories
[ -d "/etc/ssl" ] || mkdir -p "$SSL_CONTAINER_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create files

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create symlinks

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$SSL_ENABLED" = "true" ] || [ "$SSL_ENABLED" = "yes" ]; then
  if [ -f "/config/ssl/server.crt" ] && [ -f "/config/ssl/server.key" ]; then
    export SSL_ENABLED="true"
    if [ -n "$SSL_CA" ] && [ -f "$SSL_CA" ]; then
      mkdir -p "$SSL_CONTAINER_DIR/certs"
      cat "$SSL_CA" >>"/etc/ssl/certs/ca-certificates.crt"
      cp -Rf "/config/ssl/." "$SSL_CONTAINER_DIR/"
    fi
  else
    [ -d "$SSL_DIR" ] || mkdir -p "$SSL_DIR"
    create-ssl-cert
  fi
  type update-ca-certificates &>/dev/null && update-ca-certificates
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "$SSL_CA" ] && cp -Rfv "$SSL_CA" "$SSL_CONTAINER_DIR/ca.crt"
[ -f "$SSL_KEY" ] && cp -Rfv "$SSL_KEY" "$SSL_CONTAINER_DIR/server.key"
[ -f "$SSL_CERT" ] && cp -Rfv "$SSL_CERT" "$SSL_CONTAINER_DIR/server.crt"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup bin directory
SET_USR_BIN=""
[ -d "/data/bin" ] && SET_USR_BIN+="$(__find /data/bin f) "
[ -d "/config/bin" ] && SET_USR_BIN+="$(__find /config/bin f) "
if [ -n "$SET_USR_BIN" ]; then
  echo "Setting up bin"
  for create_bin in $SET_USR_BIN; do
    if [ -n "$create_bin" ]; then
      create_bin_name="$(basename "$create_bin")"
      ln -sf "$create_bin" "$LOCAL_BIN_DIR/$create_bin_name"
    fi
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create default config
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -d "/config" ]; then
  echo "Copying default config files"
  if [ -n "$DEFAULT_TEMPLATE_DIR" ] && [ -d "$DEFAULT_TEMPLATE_DIR" ]; then
    for create_template in "$DEFAULT_TEMPLATE_DIR"/*; do
      create_template_name="$(basename "$create_template")"
      if [ -n "$create_template" ]; then
        if [ -d "$create_template" ]; then
          mkdir -p "/config/$create_template_name/"
          cp -Rf "$create_template/." "/config/$create_template_name/" 2>/dev/null
        else
          cp -Rf "$create_template" "/config/$create_template_name" 2>/dev/null
        fi
      fi
    done
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom config files
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -d "/config" ]; then
  echo "Copying custom config files"
  for create_config in "$DEFAULT_CONF_DIR"/*; do
    create_config_name="$(basename "$create_config")"
    if [ -n "$create_config" ]; then
      if [ -d "$create_config" ]; then
        mkdir -p "/config/$create_config_name"
        cp -Rf "$create_config/." "/config/$create_config_name/" 2>/dev/null
      else
        cp -Rf "$create_config" "/config/$create_config_name" 2>/dev/null
      fi
    fi
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom data files
if [ "$DATA_DIR_INITIALIZED" = "false" ] && [ -d "/data" ]; then
  echo "Copying data files"
  for create_data in "$DEFAULT_DATA_DIR"/*; do
    create_data_name="$(basename "$create_data")"
    if [ -n "$create_data" ]; then
      if [ -d "$create_data" ]; then
        mkdir -p "/data/$create_data_name"
        cp -Rf "$create_data/." "/data/$create_data_name/" 2>/dev/null
      else
        cp -Rf "$create_data" "/data/$create_data_name" 2>/dev/null
      fi
    fi
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy /config to /etc
if [ -d "/config" ]; then
  [ "$CONFIG_DIR_INITIALIZED" = "false" ] && echo "Copying /config to /etc"
  for create_conf in /config/*; do
    if [ -n "$create_conf" ]; then
      create_conf_name="$(basename "$create_conf")"
      if [ -e "/etc/$create_conf_name" ]; then
        if [ -d "/etc/$create_conf_name" ]; then
          mkdir -p "/etc/$create_conf_name/"
          cp -Rf "$create_conf/." "/etc/$create_conf_name/" 2>/dev/null
        else
          cp -Rf "$create_conf" "/etc/$create_conf_name" 2>/dev/null
        fi
      fi
    fi
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ -d "$DEFAULT_DATA_DIR/htdocs/www" ] && [ ! -d "$WWW_ROOT_DIR" ]; then
  mkdir -p "$WWW_ROOT_DIR"
  cp -Rf "$DEFAULT_DATA_DIR/htdocs/www/" "$WWW_ROOT_DIR"
  [ -f "$WWW_ROOT_DIR/htdocs/www/server-health" ] || echo "OK" >"$WWW_ROOT_DIR/htdocs/www/server-health"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Unset unneeded variables
unset SET_USR_BIN create_bin create_bin_name create_template create_template_name
unset create_data create_data_name create_config create_config_name create_conf create_conf_name
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "/data/.docker_has_run" ] || { [ -d "/data" ] && echo "Initialized on: $(date)" >"/data/.docker_has_run"; }
[ -f "/config/.docker_has_run" ] || { [ -d "/config" ] && echo "Initialized on: $(date)" >"/config/.docker_has_run"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional commands

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Show message
echo "Container ip address is: $CONTAINER_IP_ADDRESS"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
case "$1" in
--help) # Help message
  echo 'Docker container for '$APPNAME''
  echo "Usage: $APPNAME [healthcheck, bash, command]"
  echo "Failed command will have exit code 10"
  echo ""
  exit 0
  ;;

healthcheck) # Docker healthcheck
  __heath_check || exitCode=10
  exit ${exitCode:-$?}
  ;;

ports)
  shift 1
  __listening
  exit $?
  ;;

procs)
  shift 1
  __show_procs
  exit $?
  ;;

*/bin/sh | */bin/bash | bash | shell | sh) # Launch shell
  shift 1
  __exec_command "${@:-/bin/bash}"
  exit ${exitCode:-$?}
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

*) # Execute primary command
  if [ $# -eq 0 ]; then
    __start_all_services
    exit ${exitCode:-$?}
  else
    __exec_command "$@"
    exitCode=$?
  fi
  ;;
esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end of entrypoint
exit ${exitCode:-$?}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# ex: ts=2 sw=2 et filetype=sh
