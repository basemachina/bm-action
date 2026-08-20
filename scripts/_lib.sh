#!/usr/bin/env bash
# 共通ユーティリティ。source 専用

bm::mask_secret() {
  local value="${1:-}"
  [ -z "${value}" ] && return 0
  printf '::add-mask::%s\n' "${value}"
}

# step output を書き込む。値に改行が含まれる場合は heredoc 形式で安全に出力
bm::set_output() {
  local name="${1:?output name required}"
  shift
  local value="${*:-}"
  if [[ "${value}" == *$'\n'* ]]; then
    local delim
    delim="BM_EOF_$(date +%s)_${RANDOM}"
    {
      printf '%s<<%s\n' "${name}" "${delim}"
      printf '%s\n' "${value}"
      printf '%s\n' "${delim}"
    } >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT not set}"
  else
    printf '%s=%s\n' "${name}" "${value}" >> "${GITHUB_OUTPUT:?GITHUB_OUTPUT not set}"
  fi
}

bm::log_group_start() { printf '::group::%s\n' "${1:-}"; }
bm::log_group_end()   { printf '::endgroup::\n'; }

# install 済み @basemachina/cli のバージョンを stdout に返す。判定できなければ空文字。
# node の module 解決は cwd 基準のため、呼び出し側 (working-directory 配下) の node_modules を見る。
# BM_CLI_VERSION はテストや特殊な install 構成向けのオーバーライドフック（BM_CLI_COMMAND と同様の位置づけ）。
bm::installed_cli_version() {
  if [ -n "${BM_CLI_VERSION:-}" ]; then
    printf '%s' "${BM_CLI_VERSION}"
    return 0
  fi
  if ! command -v node >/dev/null 2>&1; then
    return 0
  fi
  node -e "try { process.stdout.write(require('@basemachina/cli/package.json').version) } catch (e) { process.exit(0) }" 2>/dev/null
}

# major.minor.patch を数値として比較し、第 1 引数が第 2 引数より小さければ真を返す。
# prerelease サフィックスの除去は呼び出し側の責務
bm::version_lt() {
  local v1="${1:?version required}"
  local v2="${2:?version required}"
  local -a a b
  IFS='.' read -ra a <<< "${v1}"
  IFS='.' read -ra b <<< "${v2}"
  local i n1 n2
  for i in 0 1 2; do
    n1="${a[i]:-0}"
    n2="${b[i]:-0}"
    if (( 10#${n1} < 10#${n2} )); then
      return 0
    elif (( 10#${n1} > 10#${n2} )); then
      return 1
    fi
  done
  return 1
}

# dry-run / apply と、モノレポでの複数プロジェクトの sticky-comment を識別するため、
# 実行モード・environment・working-directory のハッシュからデフォルトタグを算出する
bm::default_comment_tag() {
  local mode="${1:-apply}"
  local env_label="${2:-dev}"
  local cwd="${3:-.}"
  local hash
  hash=$(printf '%s' "${cwd}" | shasum -a 256 | cut -c1-8)
  printf 'bm-sync:%s:%s:%s' "${mode}" "${env_label}" "${hash}"
}
