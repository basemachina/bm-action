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
