#!/usr/bin/env bash
# 意図的に `-e` を外す: bm sync の exit code を変数に捕捉して step output に渡すため
set -uo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=./_lib.sh
source "$(dirname "$0")/_lib.sh"

case "${INPUT_DRY:-auto}" in
  auto|true|false) ;;
  *)
    echo "::error::dry input は 'auto' / 'true' / 'false' のいずれかを指定してください (指定値: ${INPUT_DRY})" >&2
    exit 1
    ;;
esac

# CLI の現仕様で environment ID は positional 引数
args=("sync")
sync_mode="apply"

if [ -n "${INPUT_ENVIRONMENT_ID:-}" ]; then
  args+=("${INPUT_ENVIRONMENT_ID}")
fi

if [ -n "${INPUT_FROM:-}" ]; then
  args+=(--from "${INPUT_FROM}")
fi

if [ "${INPUT_WITH_DISABLE:-false}" = "true" ]; then
  args+=(--with-disable)
fi

case "${INPUT_DRY:-auto}" in
  true)
    args+=(--dry)
    sync_mode="dry"
    ;;
  false)
    ;;
  auto)
    if [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ]; then
      args+=(--dry)
      sync_mode="dry"
    fi
    ;;
esac

# 呼び出し側が事前に install した node_modules 配下の CLI を実行する。
# `--no-install` で npm registry への暗黙 fallback を禁止し、
# 利用するバージョンを呼び出し側の package.json に固定させる。
# BM_CLI_COMMAND はテストで mock CLI を差し込むためのフック。
cli_cmd="${BM_CLI_COMMAND:-npx --no-install @basemachina/cli}"

output_file="bm-sync-output.txt"
bm::log_group_start "bm ${args[*]}"
set +e
# cli_cmd は "npx --yes @basemachina/cli@latest" のように複数トークンを含む文字列として
# 保持するため、意図的に word-split させる
# shellcheck disable=SC2086
${cli_cmd} "${args[@]}" 2>&1 | tee "${output_file}"
exit_code=${PIPESTATUS[0]}
set -e
bm::log_group_end

# PR コメント body を生成。bm sync CLI は既に <details> やコードフェンスを含む形で出力を整形しているため、
# Action 側で外側にヘッダー・ステータス行・コードフェンスを被せるとネストが壊れて描画が崩れる。
# そのまま貼り付ける。65535 文字制限を避けるため 60000 バイトで truncate する。
comment_file="bm-sync-output.md"
{
  head -c 60000 "${output_file}"
  if [ "$(wc -c < "${output_file}")" -gt 60000 ]; then
    printf '\n\n... (truncated, see Step Summary for full output)\n'
  fi
} > "${comment_file}"

# Step Summary には全文を出力。AI エージェントによる調査を容易にする
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "${output_file}" >> "${GITHUB_STEP_SUMMARY}"
fi

# dry-run と apply、および同一 PR 内で複数 job が本 Action を呼ぶケースで
# sticky-comment が混線しないよう、実行モード + environment + working-directory から識別 tag を算出する
env_label="${INPUT_ENVIRONMENT_ID:-dev}"
tag=$(bm::default_comment_tag "${sync_mode}" "${env_label}" "${PWD}")

bm::set_output "exit_code" "${exit_code}"
bm::set_output "comment_tag" "${tag}"

# run.sh 自体は常に 0 で終了。失敗伝播は action.yml の最終 step が担当する
exit 0
