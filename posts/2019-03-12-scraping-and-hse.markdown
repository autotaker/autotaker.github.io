---
title: Haskellでスクレイピング、haskell-src-extsのバグ
tags: 日記
description: Haskellでスクレイピングしようとして見たら苦戦した。
---

AtCoderの自動化プラグインを作りたくてスクレイピングを始めた。
Haskellでスクレイピングでググると
[Haskell で楽しい Web スクレイピング](https://qiita.com/na-o-ys/items/30a4950d5391911493c2)
という記事がヒットした。
`scalpel`というライブラリを使えばいいらしい。

試しにAtcoderのページにログインして見ることにした。
が、意外と手こずった。まず、`scalpel`単体ではセッションの管理ができない。
仕方ないので、Cookieを操作するミドルウェアを書いていたのだが途中で車輪の再生産は良くないと思い
ライブラリを探した。
次に見つけたのは`http-conduit-browser`というライブラリ。
使って見てビルドしようとしたらパッケージが壊れていた。よくよくpackage descriptionを読むと

> This package creates a monad representing things that browsers do, letting you elegantly describe a browsing session. This package wraps the http-conduit package by Michael Snoyman. This package is deprecated, use http://hackage.haskell.org/package/wreq instead

**This package is deprecated, use http://hackage.haskell.org/package/wreq instead**

はい。
全く英語が読めていない。

ここで紹介されている`wreq`というライブラリを使って見る。
すごく直感的だ。GETでアクセスするには`get :: String -> IO (Response ByteString)`を呼べばよく、
POSTでアクセスするには`post :: Postable a => String -> a -> IO (Response ByteString)`を叩けば良い。
そうそう、こういうのでいいんだよ。

セッションを管理したくなったら`Network.Wreq.Session`の関数を使えば良い。使い方も簡単だ。
これで楽勝かと思ったが、AtCoderにログインしようとしたら`csrf tokens mismatch`と言われてしまう。
しばらく悩んだ結果、`application/json`でフォームを送信していたのを`application/x-www-form-urlencoded`に直したらログインできた。

これを開発している途中に`hlint`のバグを見つけた。（実際はhaskell-src-extsのバグだが）
HIE上でHaskellのコードを編集すると、勝手にhlintをかけてhintを表示してくれるのだが、なぜか
`hlint`がパーズエラーを投げていた。しかし手元のターミナルで直接`hlint Program.hs`を叩いても全然再現しない。
バグを特定したところ、HIEがhlintをかけるとき勝手に`TypeApplications`の拡張を有効にすることがわかった。

```haskell
runLintCmd :: FilePath -> [String] -> ExceptT [Diagnostic] IO [Idea]
runLintCmd fp args = do
  (flags,classify,hint) <- liftIO $ argsSettings args
  let myflags = flags { hseFlags = (hseFlags flags) { extensions = EnableExtension TypeApplications:extensions (hseFlags flags)}}
  res <- bimapExceptT parseErrorToDiagnostic id $ ExceptT $ parseModuleEx myflags fp Nothing
  pure $ applyHints classify hint [res]
```
[ソース](https://github.com/haskell/haskell-ide-engine/blob/65225fe9c4314b44fd2f9f3c0a4067961ee872cc/src/Haskell/Ide/Engine/Plugin/ApplyRefact.hs#L117)

謎の仕様ではあるが、まあなんらかの理由があってこういうことをしているのだろう。
とりあえず回避策としては`NoTypeApplications`プラグマを書いておけば良い。
真の問題は`TypeApplications`を有効にすると`hlint`が正しくパーズしてくれないということだ。
バグを調べたところ`haskell-src-exts`の[issue](https://github.com/haskell-suite/haskell-src-exts/issues/326)
が見つかった。`TypeApplications`が有効になっていると`@:`という演算子がパーズできなくなるというバグだ。
面白いのは`@=`とか`@@`などの演算子は正しくパーズできるというところだ。`@:`で始まる演算子のみがパーズできない。

1行修正すれば治るバグのようだったので修正してプルリクを投げた。マージされると嬉しいな。

話は変わるが`neovim` + `vim-lsp`経由でHIEを動かしているのだが、重すぎて正直使い物にならない。
カーソルを１つ動かすたびに数百ms待たされる。どれを使えば良いのやら。
