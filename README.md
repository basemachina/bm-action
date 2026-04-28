# basemachina/bm-action

[BaseMachina](https://basemachina.com) の `bm sync` CLI を GitHub Actions から実行する公式 Composite Action。Linux / macOS で動作します（Windows 非対応）。

主な機能:

- **OIDC 認証**: GitHub Actions の OIDC ID token を BaseMachina に提示します。secret に token を保存する必要はなく、workflow に `permissions: id-token: write` と `audience` を書くだけで認証が通ります
- **PR sticky-comment**: `bm sync` の差分出力を PR コメントとして自動投稿します。dry-run / apply ごとに別コメントとして追跡し、再実行ごとに同じ種別のコメントだけを上書き更新します
- **dry-run 自動判定**: `pull_request` event では差分プレビュー (`--dry`) を実行し、`push` event では実 apply に自動で切り替わります。event ごとに workflow を分けたり `if:` を書く必要はありません

詳細仕様は[公式ドキュメント (CI/CD の設定)](https://docs.basemachina.com/preview/code_management/ci_cd/)を参照してください。

## Prerequisites

プロジェクトに `@basemachina/cli` が install されている必要があります。

- `actions/setup-node@v6` などで Node.js をセットアップ
- `npm ci` / `pnpm install` / `yarn install` で `@basemachina/cli` を install
- self-hosted runner で使う場合は `bash`, `curl`, `jq`, `shasum`, `npx` が利用できる必要があります

## Quick Start

```yaml
name: BaseMachina Sync
on:
  pull_request: { branches: [main] }
  push:         { branches: [main] }

permissions:
  contents: read
  id-token: write
  pull-requests: write
  packages: read

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: '24'
      - run: npm ci
      - uses: basemachina/bm-action@v1
        with:
          audience: "https://basemachina.com"
```

[2 ブランチ運用](https://docs.basemachina.com/preview/code_management/examples/two_branch/) / [3 ブランチ運用](https://docs.basemachina.com/preview/code_management/examples/three_branch/) の workflow 例は公式ドキュメントを参照してください。

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `audience` | **Yes** | — | OIDC token の audience。BaseMachina trust policy に登録した値と同じものを指定 |
| `environment-id` | No | `""` | 同期先の環境 ID。未指定なら開発環境へ sync |
| `from` | No | `""` | 同期元の環境 ID (`--from`)。`environment-id` 指定時のみ指定可能で、同期先とは異なる ID が必要 |
| `working-directory` | No | `"."` | `basemachina.config.ts` が存在するディレクトリ |
| `dry` | No | `"auto"` | `auto` は `pull_request` で dry-run / `true` 常時 dry / `false` 常時 apply |
| `with-disable` | No | `"false"` | `true` / `false` を指定。`true` の場合は `--with-disable` を付与。`environment-id` 未指定時は設定ファイルにないアクションを開発環境で無効化、指定時は同期元で無効化されたアクションを同期先にも反映 |

## License

MIT
