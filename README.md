https://keioroboticsassociation.github.io/rogi_nav_documentation/

## ローカルで確認

`uv` と `make` が使える環境で、`rogi_nav_documentation` ディレクトリで実行します。rogi_nav のルートからなら `cd rogi_nav_documentation` で移動してください。

```bash
make test
```

依存関係の同期と HTML のビルド後、ローカルサーバーを起動します。
[http://localhost:8000](http://localhost:8000) をブラウザで開いてください。
停止するには `Ctrl+C` を押します。ビルドに失敗した場合はサーバーを起動しません。

ポートを変更する場合は `make test PORT=8001` を実行します。
編集後は別ターミナルで `make build` を実行し、ブラウザを更新してください。

警告と内部参照も検査する場合は次を実行します。

```bash
uv run --frozen --group dev sphinx-build -n -W --keep-going -b html docs docs/_build/html
```
