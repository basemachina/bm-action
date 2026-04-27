#!/usr/bin/env bash
# bats 共通セットアップ。各 bats ファイルから `load 'helpers/common'` で読む

setup_common() {
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

  # テスト汚染を避けるため step output / step summary を tmpdir に向ける
  export GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/github_output"
  export GITHUB_STEP_SUMMARY="${BATS_TEST_TMPDIR}/github_step_summary"
  : > "${GITHUB_OUTPUT}"
  : > "${GITHUB_STEP_SUMMARY}"

  # mock CLI を PATH に置かず BM_CLI_COMMAND で直接指定する
  export BM_CLI_COMMAND="${PROJECT_ROOT}/tests/fixtures/bm-mock"
}
