#!/usr/bin/env bats

load 'helpers/common'

setup() {
  setup_common
  export INPUT_ENVIRONMENT_ID=""
  export INPUT_FROM=""
  export INPUT_DRY="auto"
  export INPUT_WITH_DISABLE="false"
  export GITHUB_EVENT_NAME="push"
  export BM_MOCK_CALL_LOG="${BATS_TEST_TMPDIR}/mock-call.log"
  cd "${BATS_TEST_TMPDIR}"
}

@test "dev sync (環境 ID 未指定) で bm sync が引数なしで呼ばれる" {
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" == *"args: sync"* ]]
}

@test "log group title は sync を二重表示しない" {
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::group::bm sync"* ]]
  [[ "$output" != *"::group::bm sync sync"* ]]
}

@test "environment 指定で positional 引数が付く" {
  export INPUT_ENVIRONMENT_ID="env-abc"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" == *"args: sync env-abc"* ]]
}

@test "pull_request event かつ dry=auto で --dry が付く" {
  export GITHUB_EVENT_NAME="pull_request"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" == *"--dry"* ]]
}

@test "environment dry-run の log group title は実行コマンド相当になる" {
  export INPUT_ENVIRONMENT_ID="env-abc"
  export INPUT_DRY="true"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::group::bm sync env-abc --dry"* ]]
  [[ "$output" != *"::group::bm sync sync env-abc --dry"* ]]
}

@test "push event かつ dry=auto で --dry が付かない" {
  export GITHUB_EVENT_NAME="push"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" != *"--dry"* ]]
}

@test "dry=false は pull_request でも --dry が付かない" {
  export GITHUB_EVENT_NAME="pull_request"
  export INPUT_DRY="false"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" != *"--dry"* ]]
}

@test "dry=true は push でも --dry が付く" {
  export GITHUB_EVENT_NAME="push"
  export INPUT_DRY="true"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" == *"--dry"* ]]
}

@test "dry に invalid 値を指定するとエラー" {
  export INPUT_DRY="invalid"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"dry input は 'auto' / 'true' / 'false'"* ]]
}

@test "with-disable に invalid 値を指定するとエラー" {
  export INPUT_WITH_DISABLE="invalid"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"with-disable input は 'true' / 'false'"* ]]
}

@test "with-disable=true + environment 指定でも --with-disable が付く (環境間で無効化状態を同期)" {
  export INPUT_ENVIRONMENT_ID="env-abc"
  export INPUT_WITH_DISABLE="true"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" == *"sync env-abc"* ]]
  [[ "$output" == *"--with-disable"* ]]
}

@test "with-disable=true + environment 空なら --with-disable が付く" {
  export INPUT_WITH_DISABLE="true"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" == *"--with-disable"* ]]
}

@test "from 指定で --from が付く" {
  export INPUT_ENVIRONMENT_ID="env-abc"
  export INPUT_FROM="env-from"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${BM_MOCK_CALL_LOG}"
  [[ "$output" == *"--from env-from"* ]]
}

@test "from 指定かつ environment ID 未指定ならエラー" {
  export INPUT_FROM="env-from"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"from input は environment-id 指定時のみ使用できます"* ]]
}

@test "from と environment ID が同一ならエラー" {
  export INPUT_ENVIRONMENT_ID="env-abc"
  export INPUT_FROM="env-abc"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"from input は environment-id と異なる環境 ID"* ]]
}

@test "bm sync 失敗時も run.sh 自体は 0 で返り exit_code output に値が入る" {
  export BM_MOCK_EXIT_CODE=1
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${GITHUB_OUTPUT}"
  [[ "$output" == *"exit_code=1"* ]]
}

@test "65535 超の出力は PR コメントで truncate される" {
  long=$(printf 'x%.0s' {1..70000})
  export BM_MOCK_OUTPUT="${long}"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  size=$(wc -c < bm-sync-output.md)
  [ "${size}" -lt 61000 ]
  run cat bm-sync-output.md
  [[ "$output" == *"truncated"* ]]
}

@test "PR コメントは CLI 出力をそのまま含み、Action 側の装飾を含まない" {
  export BM_MOCK_OUTPUT=$'bm sync 実行後、以下の変更が適用されます\n<details><summary>更新するアクション (1 件)</summary>\n\n\`\`\`\nfoo\n\`\`\`\n\n</details>'
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat bm-sync-output.md
  [[ "$output" == *"bm sync 実行後、以下の変更が適用されます"* ]]
  [[ "$output" == *"<details><summary>更新するアクション (1 件)</summary>"* ]]
  [[ "$output" != *"### BaseMachina Sync"* ]]
  [[ "$output" != *"**Status**"* ]]
}

@test "bm sync 失敗時も PR コメントに Action 側のステータス装飾は含まれない" {
  export BM_MOCK_EXIT_CODE=1
  export BM_MOCK_OUTPUT="sync failed: some error"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat bm-sync-output.md
  [[ "$output" == *"sync failed: some error"* ]]
  [[ "$output" != *"**Status**"* ]]
  [[ "$output" != *"failure (exit"* ]]
}

@test "Step Summary は CLI 出力をそのまま含み Action 側の装飾を含まない" {
  export BM_MOCK_OUTPUT=$'hello\n\`\`\`\nblock\n\`\`\`'
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${GITHUB_STEP_SUMMARY}"
  [[ "$output" == *"hello"* ]]
  [[ "$output" == *"block"* ]]
  [[ "$output" != *"## BaseMachina Sync"* ]]
}

@test "comment_tag は apply/dry-run と環境 ID とディレクトリハッシュから自動算出される" {
  export INPUT_ENVIRONMENT_ID="env-abc"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${GITHUB_OUTPUT}"
  [[ "$output" == *"comment_tag=bm-sync:apply:env-abc:"* ]]
}

@test "dry-run の comment_tag は apply と別 header になる" {
  export INPUT_ENVIRONMENT_ID="env-abc"
  export INPUT_DRY="true"
  run "${PROJECT_ROOT}/scripts/run.sh"
  [ "$status" -eq 0 ]
  run cat "${GITHUB_OUTPUT}"
  [[ "$output" == *"comment_tag=bm-sync:dry:env-abc:"* ]]
}
