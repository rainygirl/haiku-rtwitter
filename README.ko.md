# R Twitter

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md)

Haiku에서 X(x.com)를 전용 창으로 여는 앱이에요.
[R Chromium](https://github.com/rainygirl/haiku-rchromium-x86)을 브라우저 툴바 없이
띄우고, Qt는 필요 없어요.

![Haiku의 R Twitter](docs/screenshot.png)

## pkgman으로 설치

32비트 x86 Haiku(x86_gcc2)에서:

```sh
pkgman add-repo https://pkgman.rainygirl.com/x86_gcc2
pkgman install rtwitter        # rchromium_x86(약 200 MB)도 함께 설치돼요
```

설치 후 Deskbar -> Applications에서 **R Twitter**를 실행하세요.

`pkgman add-repo`가 `Operation not supported`로 실패하면 그 이미지의 네트워크 킷에
TLS가 없는 거예요. `http://pkgman.rainygirl.com/x86_gcc2`를 쓰세요.

## 소스에서 설치

R Chromium이 먼저 설치되어 있어야 해요. Haiku 기기에서:

```sh
make
make install        # 바탕화면과 Deskbar -> Applications에 R Twitter가 생겨요
```

참고: 창을 닫으면 x.com 로그인이 유지되지 않아요.

## AI 사용 고지

R Twitter의 일부는 AI 코딩 도구(Anthropic Claude)의 도움을 받아 개발했어요.
모든 코드는 작성자가 검토하고 테스트했어요.

## 라이선스

MIT. `assets/`의 Twitter 로고는 Apache 2.0이에요(`assets/NOTICE` 참고). Twitter와 새 로고는
해당 소유자의 상표예요. 개발 기록은 [AGENTS.md](AGENTS.md)에 있어요.
