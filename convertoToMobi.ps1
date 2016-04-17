﻿clear

Remove-Item .\x010.html
Remove-Item .\x020.html
#Remove-Item .\test.html


#xcont.htmlには全行適用
#その他はナビゲータのみに適用
function Rewrite-PageLink ($line) {
    ###リンク関係
    $line = $line  -replace "xcont.html", "#ccont" #●目次
    $line = $line  -replace "xfore.html", "#sfore" #●序文
    $line = $line  -replace "xpre2.html", "#spre2" #●第二版への前文
    $line = $line  -replace "xpre1.html", "#spre1" #●第一版への前文
    $line = $line  -replace "xackn.html", "#sackn" #●謝辞
    $line = $line  -replace "xrefr.html", "#srefr" #●参考文献
    $line = $line  -replace "xexls.html", "#sexls" #●問題リスト
    $line = $line  -replace "xindx.html", "#iindx" #●索引
    $line = $line  -replace "xcont_001.html#", "#" #●目次へのリンクを修正
    #●各章へのリンク

    while (($line -match ".*href=`"x(?<number>\d+).html`".*") -eq $true) {
        $number = $Matches."number"
        $line = $line -replace "href=`"x$number.html`"", "href=`"#ss$number`""
    }

    $line
}

#xexlsに全行適用
function Rewrite-ExLink ($line) {
    #練習問題へのリンク修正
    #なお練習問題のネームタグはユニークなので変更の必要はないもよう
    $line -replace ”href=`"x\d+.html#ex", ”href=`"#ex"
}

#索引リンクのリスト
$Script:index_list = @()

#索引リンクの張り替え
#xindx.html内でしか使われていない。全行適用。
function Rename-Index ($line) {
    if ($line -match "href=`"x(?<pagenum>\d+).html#index(?<indxnum>\d+)`"") {
        $pagenum = $Matches."pagenum"
        $indxnum = $Matches."indxnum"

        if (("x" + $pagenum + "index" + $indxnum) -in $Script:index_list) {
            #"x" + $pagenum + "index" + $indxnum | Out-Default
            $line = $line -replace ("href=`"x" + $pagenum + ".html#index"), ("href=`"#x" + $pagenum + "index")
        } else {
            $line = Rewrite-PageLink ($line -replace ("#index" + $indxnum), "")
        }
    }

    $line
}


function Rewrite-HTML ($file) {
    $x = Get-Content $file -Encoding UTF8
    $file_name = $file.BaseName

    "<hr />"

    #各章リンク場所の移動
    if ((Rewrite-PageLink $x[13]) -match ".*name=`"(?<name>[^`"]+)`".*href=`"(?<href>[^`"]+)`"") {
        $link_name = $Matches."name"
        $cont_ref = $Matches."href"
    }
    "<a name=`"" + $link_name + "`"></a>"
    (Rewrite-PageLink ($x[10] + " " + $x[11])) -replace "<br>", "" -replace "indepth=`"true`" ", ""

    if ($x[14] -match ".*<h2>.*") {
        "<h2><a href=`"" + $cont_ref + "`">"
        $x[14] -replace "<h2>", "" -replace "</h2> *</a>", "</a></h2>" -replace "<br>", ""
    } elseif ($x[14] -match ".*<h4>.*") {
        "<h4><a href=`"" + $cont_ref + "`">"
        $x[14] -replace "<h4>", "" -replace "</h4> *</a>", "</a></h4>" -replace "<br>", ""
    }

    $blockquote_flag　= $false #引用文判定用フラグ

    #先頭の<body>タグまで削除
    for ($i = 15; $i -lt $x.Length; $i++) {
        $line = $x[$i]

        $line = $line -replace " indepth=`"true`"", "" #変な属性。要らない。
        $line = $line -replace "&nbsp;", "" #行頭字下げはスタイルでやってくれるので要らない

        #章頭の引用文を<blockquote>タグで囲む
        if ($line -match "<p style=`"padding-left: 100mm;`">") {
            $line = $line -replace "<p style=`"padding-left: 100mm;`">", "<p><blockquote>"
            $blockquote_flag = $true
        }
        if (($blockquote_flag -eq $true) -and ($line -match "</p>") ) {
            $line = $line -replace "</p>", "</blockquote></p>"
            $blockquote_flag = $false
        }

        #スペーサ除去
        $line = $line -replace "<[^>]*spacer[^>]*>", ""

        #htmlタグと誤認されてしまうシンボルを変換
        $line = $line -replace "'<procedure-env>", "&lt;procedure-env&gt;"
        $line = $line -replace "</procedure-env>", ""
        $line = $line -replace "'<compiled-procedure>", "&lt;compiled-procedure&gt;"
        $line = $line -replace "'</compiled-procedure>", ""

        $line = $line -replace "<i><i>f</i></i>", "<i>f</i>"

        #特殊文字対策
        $line = $line -replace "⟨", "&lt;"
        $line = $line -replace "⟩", "&gt;"


        #章タイトルのタグづけ入れ子ミス
        if (($line -match ".*<a href=.*") -and ($x[$i + 1] -match ".*<h2>.*")) {
            $line = "<h2>" + $line
        }
        $line = $line -replace "<h2>", ""
        $line = $line -replace "</h2> *</a>", "</a></h2>"

        if (($line -match ".*<a href=.*") -and ($x[$i + 1] -match ".*<h4>.*")) {
            $line = "<h4>" + $line
        }
        $line = $line -replace "<h4>", ""
        $line = $line -replace "</h4> *</a>", "</a></h4>"

        #索引リンク
        if ($line -match "name=`"index(?<indxnum>\d+)`"") {
            $line = $line -replace "name=`"index", ("name=`"" + $file_name + "index")
            $Script:index_list += $file_name + "index" + $Matches."indxnum"
        }

        #脚注リンク
        $line = $line -replace "name=`"ft", ("name=`"" + $file_name + "ft")
        $line = $line -replace "href=`"#ft", ("href=`"#" + $file_name + "ft")
        $line = $line -replace "name=`"ftnt", ("name=`"" + $file_name + "ftnt")
        $line = $line -replace "href=`"#ftnt", ("href=`"#" + $file_name + "ftnt")

        #脚注問題対応
        #$line = $line -replace "<tt>", "<pre>"
        #$line = $line -replace "</tt><br>", "</pre>"
        #$line = $line -replace "</tt>", "</pre>"
        $line = $line -replace "<tt>", "<span style=`"font-family: monospace`">"
        #$line = $line -replace "</tt><br>", "</span>"
        $line = $line -replace "</tt>", "</span>"
    
        #脚注欄区切り線
        if ($line -match "<p></p><div class=`"smallprint`"><hr></div>") {
            if ($x[$i + 1] -match ".*目次.*前節.*") {
                #脚注が無くてすぐナビゲータなら区切り線は要らない
                $line = "" #"</p>"
            } else {
                $line = $line -replace "<p></p><div class=`"smallprint`"><hr></div>" , "<hr />"
            }
        }

        #改行タグ
        $line = $line -replace "<br>", "<br />"

        #末尾のナビゲータは削除
        if ($line -match "<p.*目次.*前節.*") {
            $line = ""
        } elseif ($line -match "^</p>.*目次.*前節.*") {
            $line = "</p>"
        }

        #末尾の閉じタグ削除
        $line = $line -replace "</body></html>", ""

        $line
    } 
}


@"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html lang="ja">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<meta http-equiv="content-language" content="ja">
<meta name="description" content="計算機プログラムの構造と解釈 第二版 著：Gerald Jay Sussman, Harold Abelson, Julie Sussman 監訳：和田英一">
<meta name="keywords" content="SICP,Gerald Jay Sussman,Harold Abelson,Julie Sussman,和田英一,魔術師本,Scheme,Lisp">
<title>計算機プログラムの構造と解釈 第二版</title>
</head>

<body>
<div align=`"center`"><img src=`"indexfig2.png`"></div>
<p>2014-03-06 更新</p>
"@ | Out-File -Encoding utf8 sicp_jp.html


Rewrite-HTML ".\xcont.html" | foreach {
    Rewrite-PageLink $_
} | Out-File -Encoding utf8 sicp_jp.html -Append

Rewrite-HTML .\xfore.html | Out-File -Encoding utf8 sicp_jp.html -Append
Rewrite-HTML .\xpre2.html | Out-File -Encoding utf8 sicp_jp.html -Append
Rewrite-HTML .\xpre1.html | Out-File -Encoding utf8 sicp_jp.html -Append
Rewrite-HTML .\xackn.html | Out-File -Encoding utf8 sicp_jp.html -Append

ls -Filter "*.html" | foreach {
    if ($_.BaseName -match "x\d\d\d") {
        Rewrite-HTML $_    
    }
} | Out-File -Encoding utf8 sicp_jp.html -Append


Rewrite-HTML .\xrefr.html | Out-File -Encoding utf8 sicp_jp.html -Append

Rewrite-HTML .\xexls.html | foreach {
    Rewrite-ExLink $_
} | Out-File -Encoding utf8 sicp_jp.html -Append

Rewrite-HTML .\xindx.html | foreach {
    Rename-Index $_
} | Out-File -Encoding utf8 sicp_jp.html -Append

"</body></html>" | Out-File -Encoding utf8 sicp_jp.html -Append


iex "D:\bin\kindlegen_win32_v2_9\kindlegen.exe sicp_jp.html -c2 -verbose -locale en -o test.mobi"