// 統合テスト用の OIDC エンドポイント stub。
// 127.0.0.1 の MOCK_OIDC_PORT で待ち受け、auth.sh が要求する {"value": "..."} を返す。
const http = require('http');

const port = Number(process.env.MOCK_OIDC_PORT);
if (!Number.isInteger(port)) {
  console.error(
    `MOCK_OIDC_PORT が未設定または不正です: ${JSON.stringify(process.env.MOCK_OIDC_PORT)}`,
  );
  process.exit(1);
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ value: 'mock-oidc-token' }));
});

server.listen(port, '127.0.0.1', () => {
  console.log(`mock OIDC endpoint listening on 127.0.0.1:${port}`);
});
