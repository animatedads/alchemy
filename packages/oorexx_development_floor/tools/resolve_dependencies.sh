#!/usr/bin/env bash
# Sourced helper.  Verifies and resolves Development Floor's pinned local package closure.
set -euo pipefail

df_resolve_dependencies() {
  local package_root=$1
  local cache=${DF_DEPS_CACHE:-$package_root/state/deps-cache}
  mkdir -p "$cache"

  df_one_dep "$package_root" "$cache" DF_WLU_ROOT oorexx_work_load_units_v0.12.zip oorexx_work_load_units_v0.12 b5f6cd8230daa26c227b93032d42b4263c5fcb3b40838359aeab3421cf0ab75a
  df_one_dep "$package_root" "$cache" DF_CRYPTO_ROOT oorexx_crypto_v0.8.3.zip oorexx_crypto_v0.8.3 5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49
  df_one_dep "$package_root" "$cache" DF_ALCHEMY_OBJECTS_ROOT alchemy_objects_v0.8.zip alchemy_objects_v0.8 7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073
  df_one_dep "$package_root" "$cache" DF_AI_ACCESS_ROOT oorexx_ai_access_v0.6.1.zip oorexx_ai_access_v0.6.1 4cf0dc41330b5e42fa0d533c3601d441ba1f813cb2fbeb582629cad0937ed1f8
  df_one_dep "$package_root" "$cache" DF_SECRET_BROKER_ROOT oorexx_secret_broker_v0.2.zip oorexx_secret_broker_v0.2 19e80d381af659b6d9b0c838cf768a0160d0059cac08edbd17978658f77a86b5
  df_one_dep "$package_root" "$cache" DF_LOGGING_ROOT oorexx_logging_v0.7.zip oorexx_logging_v0.7 df271691ec0bb497367feadacf9ee36cb7d2e70d7f2266599360cc89d36ab7cc
  df_one_dep "$package_root" "$cache" DF_OPENAI_COMPAT_ROOT oorexx_ai_provider_openai_compat_v0.6.2.zip oorexx_ai_provider_openai_compat_v0.6.2 bca67fb506cf2a4c6379605b76d12068a966ab304a0163ab1b8606c604a99211
}

df_one_dep() {
  local package_root=$1 cache=$2 var=$3 archive_name=$4 root_name=$5 expected=$6
  local existing=${!var:-}
  if [[ -n "$existing" ]]; then
    [[ -d "$existing/src" ]] || { printf 'FAIL %s override has no src/: %s\n' "$var" "$existing" >&2; return 2; }
    export "$var=$existing"
    return 0
  fi
  local archive="$package_root/deps/$archive_name"
  [[ -f "$archive" ]] || { printf 'FAIL packaged dependency archive missing: %s\n' "$archive" >&2; return 2; }
  local actual
  actual=$(sha256sum "$archive" | awk '{print $1}')
  [[ "$actual" == "$expected" ]] || { printf 'FAIL dependency hash mismatch: %s expected=%s actual=%s\n' "$archive_name" "$expected" "$actual" >&2; return 2; }
  local target="$cache/$root_name"
  if [[ ! -d "$target/src" ]]; then
    local tmp="$cache/.${root_name}.tmp.$$"
    rm -rf "$tmp"; mkdir -p "$tmp"
    unzip -q "$archive" -d "$tmp"
    [[ -d "$tmp/$root_name/src" ]] || { printf 'FAIL dependency archive layout invalid: %s\n' "$archive_name" >&2; rm -rf "$tmp"; return 2; }
    rm -rf "$target"
    mv "$tmp/$root_name" "$target"
    rm -rf "$tmp"
  fi
  export "$var=$target"
}
