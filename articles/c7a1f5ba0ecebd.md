---
title: "[php-src を読む] DateTimeInterface オブジェクト比較編"
emoji: "⌛"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["php"]
published: true
published_at: 2023-12-14 00:00
---

この記事は [PHP Advent Calendar 2023](https://qiita.com/advent-calendar/2023/php) 14 日目の記事です。

## 初めに結論

DatetimeInterface オブジェクトの演算子はオーバーライドされていて、オブジェクトが持つ日付と時間を用いて比較をします。

## 環境とスクリプト

[こちら](https://zenn.dev/sayu/articles/6fd3a39f6e5d96)の記事で作成した環境を利用します。  
実行する PHP スクリプトは以下です。

```php
<?php

new DateTime() <= new DateTime(); // true になる
```

## ソースコードを読んでいく

### あたりをつける

GDB を利用して処理を追っていくのですが、いちから処理を追っていくといくら時間があっても足りないので、あたりを付けます。  
今回、 `<=` を利用しているので、`<=` の挙動を定義しているところを見つけます。  
ソースコード上を検索して探すことも可能ではあるのですが、検索に引っかかる数が多すぎるので、PHP マニュアルの[パーサトークンの一覧](https://www.php.net/manual/ja/tokens.php)[^1]から探します。  
[^1]: 一部の記号は一覧にはない場合があります。

`<=` は `T_IS_SMALLER_OR_EQUAL` という名前で定義されています。  
これをソースコードから探します。

`T_IS_SMALLER_OR_EQUAL` は Zend/zend_language_parser.y に定義されているのが確認できます。

```:Zend/zend_language_parser.y
%token T_IS_SMALLER_OR_EQUAL "'<='"
```

また、規則部には `<=` が使われたときのアクションも記載されています。  
ここで出てきた `ZEND_IS_SMALLER_OR_EQUAL` を検索してみます。

```:Zend/zend_language_parser.y
    | expr T_IS_SMALLER_OR_EQUAL expr
        { $$ = zend_ast_create_binary_op(ZEND_IS_SMALLER_OR_EQUAL, $1, $3); }
```

Zend/zend_opcode.c に定義してある get_binary_op 関数で `ZEND_IS_SMALLER_OR_EQUAL` が使われています。  
次はこの関数で返却している `is_smaller_or_equal_function` を検索します。

```c:Zend/zend_opcode.c
ZEND_API binary_op_type get_binary_op(int opcode)
{
    switch (opcode) {
        // 省略
        case ZEND_IS_SMALLER_OR_EQUAL:
          return (binary_op_type) is_smaller_or_equal_function;
        // 省略
    }
}
```

Zend/zend_operators.c に `is_smaller_or_equal_function` 関数を見つけました。  

```c:Zend/zend_operators.c
ZEND_API zend_result ZEND_FASTCALL is_smaller_or_equal_function(zval *result, zval *op1, zval *op2) /* {{{ */
{
    ZVAL_BOOL(result, (zend_compare(op1, op2) <= 0));
    return SUCCESS;
}
/* }}} */
```

ここで呼ばれている `zend_compare` 関数を見てみます。  
この関数に渡された 2 つの引数の型に応じて比較をしているようです。    
今回はどちらもオブジェクトなので、 `Z_TYPE_P()` の結果が `IS_OBJECT` になると予想されます。

ここまできたら、GDB でデバッグするためにブレークポイントを設定し、実際にデバッグをします。

```c:Zend/zend_operators.c
ZEND_API int ZEND_FASTCALL zend_compare(zval *op1, zval *op2) /* {{{ */
{
    int converted = 0;
    zval op1_copy, op2_copy;

    while (1) {
        switch (TYPE_PAIR(Z_TYPE_P(op1), Z_TYPE_P(op2))) {
            // 省略
            default:
                if (Z_ISREF_P(op1)) {
                    op1 = Z_REFVAL_P(op1);
                    continue;
                } else if (Z_ISREF_P(op2)) {
                    op2 = Z_REFVAL_P(op2);
                    continue;
                }

                if (Z_TYPE_P(op1) == IS_OBJECT
                && Z_TYPE_P(op2) == IS_OBJECT
                && Z_OBJ_P(op1) == Z_OBJ_P(op2)) {
                    return 0;
                } else if (Z_TYPE_P(op1) == IS_OBJECT) {
                    return Z_OBJ_HANDLER_P(op1, compare)(op1, op2); // 今回はここにブレークポイントを設定する
                } else if (Z_TYPE_P(op2) == IS_OBJECT) {
                    return Z_OBJ_HANDLER_P(op2, compare)(op1, op2);
                }
            // 省略
        }
    }
}
/* }}} */
```

### GDB でデバッグ

`return Z_OBJ_HANDLER_P(op1, compare)(op1, op2);` にブレークポイントを設定し、スクリプトを実行します。

![](/images/reading-php-src-datetimeinterface/break.png)

![](/images/reading-php-src-datetimeinterface/debug.png)

ブレークポイントを設定したところで処理が止まったので、ステップイン実行で、比較処理の中身を見ていきます。

ステップイン実行すると、`date_object_compare_date` 関数に飛びます。  
ここで引数を php_date_obj に変換し、`timelib_time_compare` 関数で比較しています。

```c:ext/date/php_date.c
static int date_object_compare_date(zval *d1, zval *d2) /* {{{ */
{
    php_date_obj *o1;
    php_date_obj *o2;

    ZEND_COMPARE_OBJECTS_FALLBACK(d1, d2);

    o1 = Z_PHPDATE_P(d1);
    o2 = Z_PHPDATE_P(d2);

    if (!o1->time || !o2->time) {
        zend_throw_error(date_ce_date_object_error, "Trying to compare an incomplete DateTime or DateTimeImmutable object");
        return ZEND_UNCOMPARABLE;
    }
    if (!o1->time->sse_uptodate) {
        timelib_update_ts(o1->time, o1->time->tz_info);
    }
    if (!o2->time->sse_uptodate) {
        timelib_update_ts(o2->time, o2->time->tz_info);
    }

    return timelib_time_compare(o1->time, o2->time);
} /* }}} */
```

`timelib_time_compare` 関数は ext/date/lib/timelib.c に定義してあります。  
ここでオブジェクトの持つ UNIX タイムスタンプとマイクロ秒を使い比較をしています。

```c:ext/date/lib/timelib.c
int timelib_time_compare(timelib_time *t1, timelib_time *t2)
{
    if (t1->sse == t2->sse) {     // UNIX タイムスタンプの比較
        if (t1->us == t2->us) {   // マイクロ秒の比較
            return 0;
        }

        return (t1->us < t2->us) ? -1 : 1;
    }

    return (t1->sse < t2->sse) ? -1 : 1;
}
```
