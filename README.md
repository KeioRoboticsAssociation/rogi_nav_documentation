https://keioroboticsassociation.github.io/rogi_nav_documentation/

## ローカルで確認

`uv` と `make` が使える環境で、このリポジトリのルートから実行します。

```bash
make test
```

依存関係の同期と HTML のビルド後、ローカルサーバーを起動します。
[http://localhost:8000](http://localhost:8000) をブラウザで開いてください。
停止するには `Ctrl+C` を押します。ビルドに失敗した場合はサーバーを起動しません。

ポートを変更する場合は `make test PORT=8001` を実行します。
編集後は別ターミナルで `make build` を実行し、ブラウザを更新してください。
