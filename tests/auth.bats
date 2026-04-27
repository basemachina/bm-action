#!/usr/bin/env bats

load 'helpers/common'

setup() {
  setup_common
  # OIDC 関連環境変数はデフォルトで unset
  unset ACTIONS_ID_TOKEN_REQUEST_URL || true
  unset ACTIONS_ID_TOKEN_REQUEST_TOKEN || true
  # audience は呼び出し側 workflow の input で必須。各テストの前提として設定
  export INPUT_AUDIENCE="https://example.test"
}

@test "audience input 未設定ならエラー" {
  unset INPUT_AUDIENCE
  run "${PROJECT_ROOT}/scripts/auth.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"input 'audience' が未指定"* ]]
}

@test "OIDC 環境変数が未設定ならエラーで id-token:write の案内を出す" {
  run "${PROJECT_ROOT}/scripts/auth.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"id-token: write"* ]]
}

@test "OIDC REQUEST_URL だけ設定されていてもエラー" {
  export ACTIONS_ID_TOKEN_REQUEST_URL="https://example.com/token"
  run "${PROJECT_ROOT}/scripts/auth.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"id-token: write"* ]]
}
