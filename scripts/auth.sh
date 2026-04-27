#!/usr/bin/env bash
set -euo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=./_lib.sh
source "$(dirname "$0")/_lib.sh"

if [ -z "${INPUT_AUDIENCE:-}" ]; then
  echo "::error::input 'audience' が未指定です。BaseMachina の trust policy に登録した audience を渡してください" >&2
  exit 1
fi
readonly AUDIENCE="${INPUT_AUDIENCE}"

if [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] || [ -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]; then
  echo "::error::OIDC トークン取得に必要な環境変数が未設定です。呼び出し側 workflow に 'permissions: id-token: write' を追加してください" >&2
  exit 1
fi

response=$(curl -sSL --fail-with-body \
  -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=${AUDIENCE}") || {
  echo "::error::OIDC トークン取得リクエストに失敗しました" >&2
  exit 1
}

token=$(printf '%s' "${response}" | jq -r '.value // empty')
if [ -z "${token}" ]; then
  echo "::error::OIDC トークンのレスポンスに value フィールドがありません" >&2
  exit 1
fi

bm::mask_secret "${token}"
bm::set_output "oidc_token" "${token}"
echo "OIDC 認証トークンを取得しました (audience: ${AUDIENCE})"
