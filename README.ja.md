# R Twitter

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

Haiku で X(x.com)を専用ウィンドウで開くアプリです。
[R Chromium](https://github.com/rainygirl/haiku-rchromium-x86) をブラウザのツールバーなしで
起動します。Qt は不要です。

## pkgman でインストール

32 ビット x86 の Haiku(x86_gcc2)で:

```sh
pkgman add-repo https://pkgman.rainygirl.com/x86_gcc2
pkgman install rtwitter        # rchromium_x86(約 200 MB)も一緒に入ります
```

インストール後、Deskbar -> Applications から **R Twitter** を起動します。

`pkgman add-repo` が `Operation not supported` で失敗する場合、そのイメージの
ネットワークキットに TLS がありません。`http://pkgman.rainygirl.com/x86_gcc2` を使ってください。

## ソースからインストール

R Chromium が先にインストールされている必要があります。Haiku のマシンで:

```sh
make
make install        # デスクトップと Deskbar -> Applications に R Twitter ができます
```

注意: ウィンドウを閉じると x.com のログインは保持されません。

## AI 利用の告知

R Twitter の一部は AI コーディングツール(Anthropic の Claude)の支援を受けて開発しました。
すべてのコードは作者がレビューし、テストしています。

## ライセンス

MIT。`assets/` の Twitter ロゴは Apache 2.0 です(`assets/NOTICE` を参照)。Twitter と鳥のロゴは
その所有者の商標です。開発メモは [AGENTS.md](AGENTS.md) にあります。
