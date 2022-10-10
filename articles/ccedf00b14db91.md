---
title: "〇〇をソースコードからビルドしてインストールする"
emoji: "🐈"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["linux"]
published: true
---

## はじめに

ブックマークを整理していたところ、 git や PHP などをソースコードからビルドしてインストールする方法を説明しているサイトを多く見つけました。
今の自分には必要のない情報ですが、そのままブックマークを削除してしまうのももったいない気がしたので、今まで経験したことも含めてここにまとめます。

## 手順

1. 対象プログラムの削除(すでにインストールされている場合)
2. 利用するプログラムをインストール
3. ソースコードを取得
4. make でビルド
5. make install でインストール
6. コマンドを実行してインストールできているか確認

## やってみる

今回は Docker 上に Debian のコンテナを用意して、そこに git をインストールします。

```dockerfile:Dockerfile
FROM debian:bullseye-slim
```

### 1. 対象プログラムの削除(すでにインストールされている場合)

今回は不要ですが、すでにインストールしている場合は事前に削除しておきます。

```sh
# apt でインストールしている場合
$ apt remove git

# パッケージ管理システム以外の方法でインストールしている場合
# 必ずしも下記のコマンドで削除できるとは限らないので注意
$ make uninstall
$ rm /実行ファイルへのパス
```

### 2. 利用するプログラムをインストール

今回は `make` と `curl` を使います。
インストールされていない場合は事前にインストールしておきます。

```sh
$ apt install make curl
```

### 3. ソースコードを取得

ソースコードは[こちら](https://mirrors.edge.kernel.org/pub/software/scm/git/)のリポジトリから取得します。

```sh
$ cd /usr/local/src

$ curl -O https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.38.0.tar.gz

$ tar zxvf git-2.38.0.tar.gz

$ cd git-2.38.0
```

### 4. make でビルド

[INSTALL](https://github.com/git/git/blob/master/INSTALL) ファイルに従ってインストールします。

今回は `make` と `make install` のみ行います。

インストール先を `/usr/bin/` にしたいので、各コマンドに `prefix=/usr` をつけます。

`make` 実行時に起きたエラーと対応は折りたたみの中に記載しておきます。

```sh
# ビルド開始
$ make prefix=/usr
```

:::details エラーと対応

原因: gcc がない。
対応: gcc をインストールする。

```sh
make: curl-config: No such file or directory
    * new build flags
    GEN command-list.h
    GEN config-list.h
    GEN hook-list.h
    CC fuzz-commit-graph.o
/bin/sh: 1: cc: not found
make: *** [Makefile:2602: fuzz-commit-graph.o] Error 127

$ apt install -y gcc
```

原因: ssl.h がない。
対応: libssl-dev をインストールする。

```sh
make: curl-config: No such file or directory
    CC fuzz-commit-graph.o
In file included from commit-graph.h:4,
                 from fuzz-commit-graph.c:1:
git-compat-util.h:364:10: fatal error: openssl/ssl.h: No such file or directory
  364 | #include <openssl/ssl.h>
      |          ^~~~~~~~~~~~~~~
compilation terminated.
make: *** [Makefile:2602: fuzz-commit-graph.o] Error 1

$ apt install -y libssl-dev
```

原因: zlib.h がない。
対応: libzip-dev をインストールする。

```sh
make: curl-config: No such file or directory
    CC fuzz-commit-graph.o
In file included from commit-graph.h:4,
                 from fuzz-commit-graph.c:1:
git-compat-util.h:1540:10: fatal error: zlib.h: No such file or directory
 1540 | #include <zlib.h>
      |          ^~~~~~~~
compilation terminated.
make: *** [Makefile:2602: fuzz-commit-graph.o] Error 1

$ apt install -y libzip-dev
```

原因: curl.h がない。
対応: libcurl4-openssl-dev をインストールする。

```sh
make: curl-config: No such file or directory
    CC http.o
In file included from http.c:2:
git-curl-compat.h:3:10: fatal error: curl/curl.h: No such file or directory
    3 | #include <curl/curl.h>
      |          ^~~~~~~~~~~~~
compilation terminated.
make: *** [Makefile:2602: http.o] Error 1

$ apt install -y libcurl4-openssl-dev
```

原因: expat.h がない。
対応: libexpat1-dev をインストールする。

```sh
    CC http-push.o
http-push.c:22:10: fatal error: expat.h: No such file or directory
   22 | #include <expat.h>
      |          ^~~~~~~~~
compilation terminated.
make: *** [Makefile:2602: http-push.o] Error 1

$ apt install libexpat1-dev
```

原因: gettext がない。
対応: gettext をインストールする。

```sh
    * tclsh failed; using unoptimized loading
    MSGFMT    po/bg.msg make[1]: *** [Makefile:254: po/bg.msg] Error 127
make: *** [Makefile:2233: all] Error 2

$ apt install gettext
```

:::

### 5. make install でインストール

```sh
$ make prefix=/usr install
```

### 6. コマンドを実行してインストールできているか確認

エラーが起きなければインストール成功です。

```sh
$ git --version
git version 2.38.0
```

## さいごに

公式が出している手順通りにやれば難しいことはないです。
稀にパッケージ管理システムの標準リポジトリからはインストールできない依存プログラムがあるので、そのときは別のリポジトリやソースコードからインストールすることが必要になります。
