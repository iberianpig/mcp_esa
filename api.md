---
title: v1
category: dev/esa/api
tags: noexpand
created_at: '2015-05-08T12:59:00+09:00'
updated_at: '2025-08-07T16:57:19+09:00'
published: true
number: 102
---

# はじめに

この記事では esa API v1について説明します。

# 概要

## リクエスト

APIとの通信には `HTTPS` プロトコルを使用します。アクセス先のホストは `api.esa.io` です。

## パラメータ

API v1へのリクエストには、 `GET` / `POST` / `PUT` / `PATCH` / `DELETE` の HTTPメソッドを利用します。
多くのAPIはリクエスト時にパラメータを含められますが、GETリクエストにはURIクエリ文字列を利用し、それ以外の場合にはリクエストボディを利用します。パラメータにはページネーション等の任意で渡すものと、記事名等の必須のものが存在します。

## 利用制限

現時点では、ユーザ毎に15分間に300リクエストまで受け付けます。
データのインポート等で短期間に大量のAPIリクエストを予定している場合は、チームのフィードバックフォームから「対象のチーム名」と「ご希望期間」を明記の上、一時的な制限の緩和についてご相談下さい。

制限状況はAPIのレスポンスヘッダに含まれる `x-ratelimit-*` の値をご確認下さい。

```
x-ratelimit-limit: 300
x-ratelimit-remaining: 299
x-ratelimit-reset: 1728609300
```

なお、決められた制限を超える場合は、`429 Too Many Requests` が返却されます。

## ステータスコード

`200` / `201` / `204` / `400` / `401` / `402` / `403` / `404` / `405` / `406` / `409` / `429` / `500` のステータスコードを利用します。

## データ形式

APIとのデータの送受信にはJSONを利用します。JSONをリクエストボディに含める場合は`Content-Type: application/json`をリクエストヘッダに追加して下さい。文字コードはUTF-8を使用して下さい。

## エラーレスポンス

エラーが発生した場合は、エラーを表現するオブジェクトを含んだエラーレスポンスが返却されます。

```json
{
  "error": "not_found",
  "message": "Not found"
}
```

## エラーステータスごとの対策例

ステータスごとのよくある対策例を示します。

### 400

- パラメータの名称などの指定が違う場合
- Owner権限が必要なパラメーターを上書きしようとした場合

#### 対策

- ドキュメント内のパラメーターをご確認ください
- ご利用のアクセストークンを発行したユーザーのチーム内での権限をご確認ください

### 401

- 対象のリソースを操作する権限がない
- アクセストークンのScopeが __Read__ 権限で、リソースの作成・更新・削除など、参照以外の操作をした場合

#### 対策

- チームに所属していることをご確認ください
- チーム内の権限をご確認ください
- アクセストークンのScopeをご確認ください

### 404

- 対象のリソースが見つからない

#### 対策

- 存在しない記事などにAPIでリクエストしていないかご確認ください

### 409

- 現在の記事の状態と競合した

#### 対策

- 同時編集中の記事を __Save as WIP__ や __Ship It!__ で保存してしてから再度リクエストをお試し下さい

### 429

- 決められたリクエスト数の制限を超えた

#### 対策

- メッセージに含まれる `Retry after N seconds.`を参考に、指定された時間後に再度リクエストをお試しください
- [利用制限](#利用制限)の項を参考にしてください

## ページネーション

リストを返すAPIでは、すべての要素を一度に返すことは現実的ではないため、ページを指定することができるようになっています。これらのAPIには、1から始まるページ番号を表す `page` パラメータと、1ページあたりに含まれる要素数を表す `per_page` パラメータを指定することができます。`page` の初期値は `1` に設定されています。また、 `per_page` の初期値は `20`、最大値は `100` に設定されています。

ページを指定できるAPIでは、ページネーションの情報を含んだレスポンスを返します。

```
# GET /v1/teams HTTP/1.1

{
    "teams": [
        ...
    ],
    "prev_page": null,
    "next_page": 2,
    "total_count": 30,
    "page": 1,
    "per_page": 20,
    "max_per_page": 100
}
```

- prev_page
    - 1つ前のpage番号。存在しない場合はnull
- next_page
    - 1つ先のpage番号。存在しない場合はnull
- total_count
    - リソースの総数
- page
    - 現在のページ番号
- per_page
    - 1ページあたりに含まれる要素数
- max_per_page
    - per_pageに指定可能な数の最大値

## クライアントライブラリ

現時点で以下のライブラリが利用可能です。

- Ruby
    - [esaio/esa-ruby](https://github.com/esaio/esa-ruby)

# 認証と認可

esa APIを利用するには、アクセストークンをリクエストに含める必要があります。アクセストークンは、ユーザの管理画面

```
https://[team].esa.io/user/applications
```

もしくはOAuthを利用した認可フローにより発行できます。


## アクセストークン

アクセストークンは、以下のようにリクエストヘッダに含められます。

```
Authorization: Bearer 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

また、URIクエリ文字列として指定することも可能です。

```
api.esa.io/v1/teams?access_token=1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

## スコープ

個々のアクセストークンには、複数のスコープを紐付けることができます。アクセストークンが適切なスコープを持っている時のみAPIを利用することができます。esa APIでは以下のスコープを利用することができます。

| スコープ | 説明 |
| --- | --- |
| read | データの読み出し |
| write | データの書き込み |

## OAuthを利用した認可フロー

### アプリケーションの登録

`https://[team].esa.io/user/applications` から アプリケーションを登録できます。

※ RailsやSinatraでは、以下の手順は [omniauth-esa](https://github.com/esaio/omniauth-esa) を使うことで実装の手間を省くことが出来ます。

### GET /oauth/authorize

アプリケーションのユーザーに認可画面を表示します。

- client_id
    - 登録されたアプリケーションのclient_idです
- redirect_uri
    - 認可が行われた後のリダイレクト先を指定します。アプリケーション登録時に設定したredirect_uriのうちいずれかに一致する必要があります。
    - `urn:ietf:wg:oauth:2.0:oob`を指定した場合、認可後にリダイレクトせず画面に認証コードを表示します
- scope
    - アプリケーションが利用するスコープをスペース区切りで指定します
- response_type
    - `code` を指定します
- state
    - CSRF対策のため、認可後にリダイレクトするURLのクエリに含まれる値を指定できます

```
GET /oauth/authorize?client_id=0a9bff757caf1eeb344421211637bb6cf724da767062069cafe16a43283a6e04&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&response_type=code&scope=read+write&state=a7e567e2fb858f0e12838798016ee9cf8ccc778 HTTP/1.1
```

<img width="578" alt="ss 2016-04-21 14.49.33.png (138.0 kB)" src="https://img.esa.io/uploads/production/attachments/105/2016/04/21/1/781dc446-c038-49aa-81f0-7486d9a4e265.png">

### POST /oauth/token

新規にアクセストークンを発行します。

- client_id
    - 登録されたアプリケーションのClient IDです
- client_secret
    - 登録されたアプリケーションのClient Secretです
- grant_type
    - `authorization_code ` を指定します
- redirect_uri
    - 認可を行った際のredirect_uriを指定します
- code
    - 認可後のリダイレクト先のURLに含まれた認可コードです

```
POST /oauth/token HTTP/1.1

{"client_id":"0a9bff757caf1eeb344421211637bb6cf724da767062069cafe16a43283a6e04","client_secret":"ca6eb9452f2fdaaa68a8d870bc654db8e6f466f6d42685b914e04c442b2065a2","code":"c486e26492dfdc42bcf4e07bfbd84a97f98548c1cf89178a512e76b79b099313","grant_type":"authorization_code","redirect_uri":"urn:ietf:wg:oauth:2.0:oob"}
```

```
HTTP/1.1 200 OK

{
  "access_token": "5d49aab1f0796bbbd78100f06c6cd4d667851644012d37421073bb61126cdafc",
  "token_type": "Bearer",
  "scope": "read write",
  "created_at": 1461218696
}
```

### GET /oauth/token/info

アクセストークンの情報を取得します

```
GET /oauth/token/info HTTP/1.1
Authorization: Bearer 5d49aab1f0796bbbd78100f06c6cd4d667851644012d37421073bb61126cdafc
```

```
HTTP/1.1 200 OK

{"resource_owner_id":1,"scope":["read","write"],"expires_in":null,"application":{"uid":"0a9bff757caf1eeb344421211637bb6cf724da767062069cafe16a43283a6e04"},"created_at":1461218696,"user":{"id":1}}
```

### POST /oauth/revoke

アクセストークンを失効させます

- client_id
    - 登録されたアプリケーションのClient IDです
- client_secret
    - 登録されたアプリケーションのClient Secretです
- token
    - アクセストークンを指定します

```
POST /oauth/revoke HTTP/1.1

{"client_id":"0a9bff757caf1eeb344421211637bb6cf724da767062069cafe16a43283a6e04","client_secret":"ca6eb9452f2fdaaa68a8d870bc654db8e6f466f6d42685b914e04c442b2065a2","token":"5d49aab1f0796bbbd78100f06c6cd4d667851644012d37421073bb61126cdafc"}
```

```
HTTP/1.1 200 OK

{}
```

# チーム

esa上で所属しているチームを表します。

- name (String)
    - チームを特定するための一意なIDです。サブドメインになります。
    - Example: "docs"
- privacy (String)
    - チームの公開範囲です。
        - closed: "チームメンバーだけが情報にアクセスできます。"
        - open: "ShipItされた記事はインターネット上に公開されます。"
- description (String)
    - チームの説明です
    - Example: "esa.io official documents"
    - 登録がない場合には空文字列(`""`)になります
- icon (String)
    - チームのアイコンです
    - Example: "https://img.esa.io/uploads/production/teams/105/icon/thumb_m_0537ab827c4b0c18b60af6cdd94f239c.png"

MEMO: member_count等の情報を追加予定

## GET /v1/teams

### URIクエリ文字列

- role (String)
    - 設定可能な値
        - `member`
            - メンバー権限を持つチームのみ取得
        - `owner`
            - オーナー権限を持つチームのみ取得

```
GET /v1/teams HTTP/1.1
```

```
{
  "teams": [
    {
      "name": "docs",
      "privacy": "open",
      "description": "esa.io official documents",
      "icon": "https://img.esa.io/uploads/production/teams/105/icon/thumb_m_0537ab827c4b0c18b60af6cdd94f239c.png",
      "url": "https://docs.esa.io/"
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 1,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```

## GET /v1/teams/:team_name

```
GET /v1/teams/docs HTTP/1.1
```

```
{
  "name": "docs",
  "privacy": "open",
  "description": "esa.io official documents",
  "icon": "https://img.esa.io/uploads/production/teams/105/icon/thumb_m_0537ab827c4b0c18b60af6cdd94f239c.png",
  "url": "https://docs.esa.io/"
}
```

# 統計情報

チームの統計情報を表します。

- members(Integer)
    - チーム内のメンバーの総数です
- posts(Integer)
    - チーム内の記事の総数です
- posts_wip(Integer)
    - チーム内の記事(wip)の総数です
- posts_shipped(Integer)
    - チーム内の記事(shipped)の総数です
- comments(Integer)
    - チーム内の記事につけられたコメントの総数です
- stars(Integer)
    - チーム内の記事につけられたスターの総数です
- daily_active_users(Integer)
    - 過去24時間以内に記事の新規投稿/更新・コメント・Star等の活動を行ったメンバー数です。
- weekly_active_users(Integer)
    - 過去7日間以内にに記事の新規投稿/更新・コメント・Star等の活動を行ったメンバー数です。
- monthly_active_users(Integer)
    - 過去30日間以内にに記事の新規投稿/更新・コメント・Star等の活動を行ったメンバー数です。

## GET /v1/teams/:team_name/stats

```
GET /v1/teams/docs/stats HTTP/1.1
```

```
{
  "members": 20,
  "posts": 1959,
  "posts_wip": 59,
  "posts_shipped": 1900,
  "comments": 2695,
  "stars": 3115,
  "daily_active_users": 8,
  "weekly_active_users": 14,
  "monthly_active_users": 15
}
```

#  メンバー

チームのメンバーを表します。
- myself(Boolean)
    - 自分自身であるかどうかのフラグです。
- name (String)
    - メンバーの名前です
- screen_name (String)
    - メンバーのスクリーンネームです
- icon (String)
    - メンバーのアイコンのURLです
- email (String)
    - メンバーのemailです
- role (String)
    - メンバーのロール(owner, member)です。
- posts_count (Integer)
    - チーム内でメンバーが作成した記事数です
- joined_at (DateTime String)
    - チームにメンバーが参加した日時です
- last_accessed_at (DateTime String)
    - チームにメンバーがアクセスした最後の日時です
    - 参考: [help/details/メンバーの最終アクセス日時について](https://docs.esa.io/posts/364)

## GET /v1/teams/:team_name/members

### URIクエリ文字列

- sort (String)
    - 設定可能な値
        - `posts_count` (default)
            - チーム内での記事の作成数
        - `joined`
            - チームへ参加日時
        - `last_accessed`
            - 最終アクセス日時
- order (String)
    - 設定可能な値
        - `desc` (default)
            - 降順
        - `asc`
            - 昇順

```
GET /v1/teams/docs/members HTTP/1.1
```

```
{
  "members": [
    {
      "myself": true,
      "name": "Atsuo Fukaya",
      "screen_name": "fukayatsu",
      "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png",
      "role": "owner",
      "posts_count": 222,
      "joined_at": "2014-07-01T08:10:55+09:00",
      "last_accessed_at": "2019-12-27T16:23:23+09:00",
      "email": "fukayatsu@esa.io",
    },
    {
      "myself": false,
      "name": "TAEKO AKATSUKA",
      "screen_name": "taea",
      "icon": "https://img.esa.io/uploads/production/users/2/icon/thumb_m_2690997f07b7de3014a36d90827603d6.jpg",
      "role": "owner",
      "posts_count": 111,
      "joined_at": "2014-07-01T08:19:26+09:00",
      "last_accessed_at": "2019-08-13T18:07:24+09:00",
      "email": "taea@esa.io",
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 2,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```

## GET /v1/teams/:team_name/members/:screen_name_or_email

指定したscreen_nameもしくはemailに一致するメンバーの情報を取得します。

- `me`を指定すると自身の情報を取得します。

```
GET /v1/teams/docs/members/ppworks
```

```
{
  "myself": true,
  "name": "越川 直人",
  "screen_name": "ppworks",
  "icon": "https://img.esa.io/uploads/production/members/16377/icon/thumb_m_78785723178d961fcb80fff537c56d35.jpeg",
  "role": "owner",
  "posts_count": 84,
  "joined_at": "2016-11-17T20:50:40+09:00",
  "last_accessed_at": "2023-10-03T11:11:54+09:00",
  "email": "ppworks@esa.io"
}
```

## DELETE /v1/teams/:team_name/members/:screen_name_or_email

指定した screen_name もしくは email に一致するメンバーをチームから削除します。

- チームの **owner** である必要があります
- APIで自分自身をチームから削除することはできません。
    - (Webからは可能です)

```
DELETE /v1/teams/docs/members/alice HTTP/1.1
```

```
HTTP/1.1 204 No Content
```


# 記事

ユーザが作成した記事を表します。

- number (Integer)
    - チーム内で記事を特定するためのIDです
    - Example: 123
- name (String)
    - 記事名です。タグやカテゴリー部分は含みません。
    - Example: "hi!"
- tags (Array of String)
    - 記事に紐付けられたタグです。
    - Example: ["api", "dev"]
- category (String)
    - 記事が属するカテゴリです
    - Example: "日報/2015/05/09"
    - 設定されていない場合は `null` になります
- full_name (String)
    - カテゴリとタグを含む、記事名です。
    - Example: "日報/2015/05/09/hi! #api #dev"
- wip (Boolean)
    - 記事がWIP(Working In Progress)状態かどうかを表します。
    - Example: "true"
- body_md (String)
    - Markdownで書かれた記事の本文です
    - Example "# Getting Started"
- body_html (String)
    - HTMLに変換された記事の本文です。
    - Example: `<h1>Getting Started</h1>`
- created_at (DateTime String)
    - 記事が作成された日時です
    - Example: "2014-05-10T12:08:55+09:00"
- updated_at (DateTime String)
    - 記事が更新された日時です。
    - Example: "2014-05-11T19:21:00+09:00"
- message (String)
    - 記事更新時の変更メモです。
    - Example: "Add Getting Started section"
- revision_number(Integer)
    - 記事のリビジョン番号です。
    - Example: 47
- created_by (Object)
    - 記事を作成したユーザを表します。
    - myself (Boolean)
        - 自分自身であるかどうかのフラグです。
    - name (String)
        - ユーザ名です。
        - Example: "Atsuo Fukaya"
    - screen_name (String)
        - ユーザを一意に識別するIDです。
        - Example: "fukayatsu"
    - icon (String)
        - ユーザのアイコンのURLです。
        - Exmaple: "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
- updated_by (Object)
    - 記事を最後に更新したユーザを表します。フィールドは `created_by` と共通です。
    - myself (Boolean)
    - name (String)
    - screen_name (String)
    - icon (String)
- kind(String, "stock" or "flow")
    - 記事の種別を表します
- comments_count(Integer)
    - 記事へのコメント数を表します
    - Example: 1
- tasks_count(Integer)
    - 記事中のタスクの総数を表します
    - Example: 1
- done_tasks_count(Integer)
    - 記事中の完了済みのタスクの総数を表します
    - Example: 1
- stargazers_count(Integer)
    - 記事にStarをしている人数を表します
    - Example: 1
- watchers_count(Integer)
    - 記事をWatchしている人数を表します
    - Example: 1
- star(Boolean)
    - ユーザーが記事をStarしているかどうかを表します
    - Example: true
- watch(Boolean)
    - ユーザーが記事をWatchしているかどうかを表します
    - Example: true

## GET /v1/teams/:team_name/posts
記事の一覧を返却します

```
GET /v1/teams/docs/posts HTTP/1.1
```

### URIクエリ文字列

- q (String)
    - 記事を絞り込むための条件を指定します
    - [#104:  help/記事の検索方法](/posts/104) を参照
- include (String)
    - `comments` を指定するとコメントの配列を含んだレスポンスを返します。
    - `comments,comments.stargazers`を指定するとコメントとコメントに対するStarの配列を含んだレスポンスを返します。
    - `stargazers` を指定するとStarの配列を含んだレスポンスを返します。
    - `stargazers,comments` のように `,` で区切ることで複数指定できます
- sort (String)
    - 設定可能な値
        - `updated` (default)
            - 記事の更新日時
        - `created`
            - 記事の作成日時
        - `number`
            - 記事番号
        - `stars`
            - 記事へのStarの数
        - `watches`
            - 記事へのWatchの数
        - `comments`
            - 記事へのCommentの数
        - `best_match`
            - 総合的な記事のスコア
- order (String)
    - 設定可能な値
        - `desc` (default)
            - 降順
        - `asc`
            - 昇順

```
{
  "posts": [
    {
      "number": 1,
      "name": "hi!",
      "full_name": "日報/2015/05/09/hi! #api #dev",
      "wip": true,
      "body_md": "# Getting Started",
      "body_html": "<h1 id=\"1-0-0\" name=\"1-0-0\">\n<a class=\"anchor\" href=\"#1-0-0\"><i class=\"fa fa-link\"></i><span class=\"hidden\" data-text=\"Getting Started\"> &gt; Getting Started</span></a>Getting Started</h1>\n",
      "created_at": "2015-05-09T11:54:50+09:00",
      "message": "Add Getting Started section",
      "url": "https://docs.esa.io/posts/1",
      "updated_at": "2015-05-09T11:54:51+09:00",
      "tags": [
        "api",
        "dev"
      ],
      "category": "日報/2015/05/09",
      "revision_number": 1,
      "created_by": {
        "myself": true,
        "name": "Atsuo Fukaya",
        "screen_name": "fukayatsu",
        "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
      },
      "updated_by": {
        "myself": true,
        "name": "Atsuo Fukaya",
        "screen_name": "fukayatsu",
        "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
      }
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 1,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```

## GET /v1/teams/:team_name/posts/:post_number
指定された投稿を取得します。

### URIクエリ文字列

- include (String)
    - `comments` を指定するとコメントの配列を含んだレスポンスを返します。
    - `comments,comments.stargazers`を指定するとコメントとコメントに対するStarの配列を含んだレスポンスを返します。
    - `stargazers` を指定するとStarの配列を含んだレスポンスを返します。
 
```
GET /v1/teams/docs/posts/1 HTTP/1.1
```

```
{
  "number": 1,
  "name": "hi!",
  "full_name": "日報/2015/05/09/hi! #api #dev",
  "wip": true,
  "body_md": "# Getting Started",
  "body_html": "<h1 id=\"1-0-0\" name=\"1-0-0\">\n<a class=\"anchor\" href=\"#1-0-0\"><i class=\"fa fa-link\"></i><span class=\"hidden\" data-text=\"Getting Started\"> &gt; Getting Started</span></a>Getting Started</h1>\n",
  "created_at": "2015-05-09T11:54:50+09:00",
  "message": "Add Getting Started section",
  "url": "https://docs.esa.io/posts/1",
  "updated_at": "2015-05-09T11:54:51+09:00",
  "tags": [
    "api",
    "dev"
  ],
  "category": "日報/2015/05/09",
  "revision_number": 1,
  "created_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "updated_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "kind": "flow",
  "comments_count": 1,
  "tasks_count": 1,
  "done_tasks_count": 1,
  "stargazers_count": 1,
  "watchers_count": 1,
  "star": true,
  "watch": true
}
```

## POST /v1/teams/:team_name/posts
記事を新たに投稿します。

- post (Object)
    - name (String, **required**)
        - タイトル自体に`#`を含めたい場合は`&#35;`, `/`を含めたい場合は`&#47;`へそれぞれ置換処理をお願いします。
    - body_md (String)
    - tags (Array of String)
    - category (String)
    - wip (Boolean, default: true)
    - message (String)
    - user(String)
        - チームメンバーのscreen_nameもしくは "esa_bot" を指定することで記事の投稿者を上書きすることができます。
        - このパラメータは **team の owner** だけ が使用することができます。
    - template_post_id(Number)
        - チーム内のテンプレート記事のID(URLのこの部分: /posts/**{id}**)を指定すると、そのテンプレートが適用された**name**と**body**を持つ記事を作成することが出来ます。
```
POST /v1/teams/docs/posts HTTP/1.1
Content-Type: application/json

{
   "post":{
      "name":"hi!",
      "body_md":"# Getting Started\n",
      "tags":[
         "api",
         "dev"
      ],
      "category":"dev/2015/05/10",
      "wip":false,
      "message":"Add Getting Started section"
   }
}
```

```
HTTP/1.1 201 Created
Content-Type: application/json

{
  "number": 5,
  "name": "hi!",
  "full_name": "dev/2015/05/10/hi! #api #dev",
  "wip": false,
  "body_md": "# Getting Started\n",
  "body_html": "<h1 id=\"1-0-0\" name=\"1-0-0\">\n<a class=\"anchor\" href=\"#1-0-0\"><i class=\"fa fa-link\"></i><span class=\"hidden\" data-text=\"Getting Started\"> &gt; Getting Started</span></a>Getting Started</h1>\n",
  "created_at": "2015-05-09T12:12:37+09:00",
  "message": "Add Getting Started section",
  "url": "https://docs.esa.io/posts/5",
  "updated_at": "2015-05-09T12:12:37+09:00",
  "tags": [
    "api",
    "dev"
  ],
  "category": "dev/2015/05/10",
  "revision_number": 1,
  "created_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "updated_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "kind": "flow",
  "comments_count": 0,
  "tasks_count": 0,
  "done_tasks_count": 0,
  "stargazers_count": 0,
  "watchers_count": 1,
  "star": false,
  "watch": false
}
```

## PATCH /v1/teams/:team_name/posts/:post_number
指定された投稿を編集します。

- post (Object)
    - name (String)
    - body_md (String)
    - tags (Array of String)
    - category (String)
    - wip (Boolean)
    - message (String)
    - created_by(String)
        - チームメンバーのscreen_nameもしくは "esa_bot" を指定することで記事の **作成者** を上書きすることができます。
        - このパラメータは **team の owner** だけ が使用することができます。
    - updated_by(String)
        - チームメンバーのscreen_nameもしくは "esa_bot" を指定することで記事の **更新者** を上書きすることができます。
        - このパラメータは **team の owner** だけ が使用することができます。
    - original_revision (Object)
        - body_md (String)
            - 変更前の記事の本文です
        - number (Integer)
            -  変更前の記事のrevision_numberを指定します
        - user (String)
            - 変更前の記事の最終更新者のscreen_nameを指定します

### original_revisionについて
リクエストに正常な `post.body_md` パラメータと `post.original_revision.*` パラメータが存在する場合、記事更新時に3 way mergeが行われます。original_revisionパラメータが存在しない場合は、変更は常に後勝ちになります。

> [release_note/2014/12/23/記事保存時の自動マージ - docs.esa.io](https://docs.esa.io/posts/35)

```
PATCH /v1/teams/docs/posts/5 HTTP/1.1
Content-Type: application/json

{
   "post":{
      "name":"hi!",
      "body_md":"# Getting Started\n",
      "tags":[
         "api",
         "dev"
      ],
      "category":"dev/2015/05/10",
      "wip":false,
      "message":"Add Getting Started section",
      "original_revision": {
          "body_md": "# Getting ...",
          "number":1,
          "user": "fukayatsu"
        }
    }
}
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "number": 5,
  "name": "hi!",
  "full_name": "日報/2015/05/10/hi! #api #dev",
  "wip": false,
  "body_md": "# Getting Started\n",
  "body_html": "<h1 id=\"1-0-0\" name=\"1-0-0\">\n<a class=\"anchor\" href=\"#1-0-0\"><i class=\"fa fa-link\"></i><span class=\"hidden\" data-text=\"Getting Started\"> &gt; Getting Started</span></a>Getting Started</h1>\n",
  "created_at": "2015-05-09T12:12:37+09:00",
  "message": "Add Getting Started section",
  "url": "https://docs.esa.io/posts/5",
  "updated_at": "2015-05-09T12:19:48+09:00",
  "tags": [
    "api",
    "dev"
  ],
  "category": "日報/2015/05/10",
  "revision_number": 2,
  "created_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "updated_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "overlapped": false,
  "kind": "flow",
  "comments_count": 0,
  "tasks_count": 0,
  "done_tasks_count": 0,
  "stargazers_count": 0,
  "watchers_count": 1,
  "star": false,
  "watch": false
}
```


- overlapped (Boolean)
    - 3 way mergeを行いコンフリクトが起きた場合にのみ `true` になります。

## DELETE /v1/teams/:team_name/posts/:post_number
指定された投稿を削除します。


```
DELETE /v1/teams/docs/posts/5 HTTP/1.1
```

```
HTTP/1.1 204 No Content
```

# コメント
ユーザが作成したコメントを表します。

- id
    - コメントを一意に識別するIDです
    - Example: 123
- body_md (String)
    - Markdownで書かれたコメントの本文です
    -  Example: `LGTM!`
- body_html (String)
    - HTMLに変換されたコメントの本文です
    - Example: `<p>LGTM!</p>`
- created_at (DateTime String)
    - コメントが作成された日時です
    - Example: `2014-05-10T12:45:42+09:00`
- updated_at (DateTime String)
    - コメントが更新された日時です
    - Example: `2014-05-18T23:02:29+09:00`
- url (String)
    - コメントのpermalinkです
    - https://docs.esa.io/posts/2#comment-123
- created_by (Object)
    - コメントを作成したユーザを表します。
    - myself (Boolean)
        - 自分自身であるかどうかのフラグです。
    - name (String)
        - ユーザ名です。
        - Example: "Atsuo Fukaya"
    - screen_name (String)
        - ユーザを一意に識別するIDです。
        - Example: "fukayatsu"
    - icon (String)
        - ユーザのアイコンのURLです。
        - Exmaple: "http://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"

## GET /v1/teams/:team_name/posts/:post_number/comments
記事のコメント一覧を更新日の降順で返却します。

```
GET /v1/teams/docs/posts/2/comments HTTP/1.1
```

```
{
  "comments": [
    {
      "id": 1,
      "body_md": "(大事)",
      "body_html": "<p>(大事)</p>",
      "created_at": "2014-05-10T12:45:42+09:00",
      "updated_at": "2014-05-18T23:02:29+09:00",
      "url": "https://docs.esa.io/posts/2#comment-1",
      "created_by": {
        "myself": true,
        "name": "Atsuo Fukaya",
        "screen_name": "fukayatsu",
        "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
      },
      "stargazers_count": 0,
      "star": false
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 1,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```

## GET /v1/teams/:team_name/comments/:comment_id
指定されたコメントを取得します。

```
GET /v1/teams/docs/comments/13 HTTP/1.1
```
### URIクエリ文字列

- include (String)
    - `stargazers` を指定するとStarの配列を含んだレスポンスを返します。

```
{
  "id": 13,
  "body_md": "読みたい",
  "body_html": "<p>読みたい</p>",
  "created_at": "2014-05-13T16:17:42+09:00",
  "updated_at": "2014-05-18T23:02:29+09:00",
  "url": "https://docs.esa.io/posts/13#comment-13",
  "created_by": {
    "myself": false,
    "name": "TAEKO AKATSUKA",
    "screen_name": "taea",
    "icon": "https://img.esa.io/uploads/production/users/2/icon/thumb_m_2690997f07b7de3014a36d90827603d6.jpg"
  },
  "stargazers_count": 0,
  "star": false
}
```

## POST /v1/teams/:team_name/posts/:post_number/comments
記事に新しいコメントを作成します。

- comment (Object)
    - body_md (String, **required**)
    - user(String)
        - チームメンバーのscreen_nameもしくは "esa_bot" を指定することで記事の投稿者を上書きすることができます。
        - このパラメータは **team の owner** だけ が使用することができます。

```
POST /v1/teams/docs/posts/2/comments HTTP/1.1
Content-Type: application/json

{"comment":{"body_md":"LGTM!"}}
```

```
HTTP/1.1 201 Created
Content-Type: application/json

{
  "id": 22767,
  "body_md": "LGTM!",
  "body_html": "<p>LGTM!</p>\n",
  "created_at": "2015-06-21T19:36:20+09:00",
  "updated_at": "2015-06-21T19:36:20+09:00",
  "url": "https://docs.esa.io/posts/2#comment-22767",
  "created_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "stargazers_count": 0,
  "star": false
}
```



## PATCH /v1/teams/:team_name/comments/:comment_id
指定されたコメントを更新します。

- comment (Object)
    - body_md (String)
    - user(String)
        - チームメンバーのscreen_nameもしくは "esa_bot" を指定することで記事の投稿者を上書きすることができます。
        - このパラメータは **team の owner** だけ が使用することができます。

```
PATCH /v1/teams/docs/comments/22767 HTTP/1.1
Content-Type: application/json

{"comment":{"body_md":"LGTM!!!"}}
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 22767,
  "body_md": "LGTM! :sushi:",
  "body_html": "<p>LGTM!!!</p>\n",
  "created_at": "2015-06-21T19:36:20+09:00",
  "updated_at": "2015-06-21T19:40:33+09:00",
  "url": "https://docs.esa.io/posts/2#comment-22767",
  "created_by": {
    "myself": true,
    "name": "Atsuo Fukaya",
    "screen_name": "fukayatsu",
    "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
  },
  "stargazers_count": 0,
  "star": false
}
```

## DELETE /v1/teams/:team_name/comments/:comment_id
指定されたコメントを削除します。

```
DELETE /v1/teams/docs/comments/22767 HTTP/1.1
```

```
HTTP/1.1 204 No Content
```

## GET /v1/teams/:team_name/comments
チーム全体のコメント一覧を作成日の降順で返却します。

```
GET /v1/teams/docs/comments HTTP/1.1
```

```
{
  "comments": [
    {
      "id": 1,
      "body_md": "(大事)",
      "body_html": "<p>(大事)</p>",
      "created_at": "2014-05-10T12:45:42+09:00",
      "updated_at": "2014-05-18T23:02:29+09:00",
      "url": "https://docs.esa.io/posts/2#comment-1",
      "created_by": {
        "myself": true,
        "name": "Atsuo Fukaya",
        "screen_name": "fukayatsu",
        "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
      },
      "stargazers_count": 0,
      "star": false
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 1,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```

# Star

- created_at (DateTime)
    - Starをした日時です。
- body (null or String)
    - 引用Starの本文です。
- user
    - Starをしたユーザです。

## GET /v1/teams/:team_name/posts/:post_number/stargazers

指定された記事にStarをしたユーザ一覧を取得します。

```
GET /v1/teams/docs/posts/2312/stargazers HTTP/1.1
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "stargazers": [
    {
      "created_at": "2016-05-05T11:40:54+09:00",
      "body": null,
      "user": {
        "myself": true,
        "name": "Atsuo Fukaya",
        "screen_name": "fukayatsu",
        "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
      }
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 1,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```

## POST /v1/teams/:team_name/posts/:post_number/star

指定された記事にStarをします。

- body (String)
    - (任意) 引用Starの本文です。

```
POST /v1/teams/docs/posts/2312/star HTTP/1.1

{"body":"foo bar"}
```

```
HTTP/1.1 204 No Content
```

## DELETE /v1/teams/:team_name/posts/:post_number/star

指定された記事へのStarを取り消します。

```
DELETE /v1/teams/docs/posts/2312/star HTTP/1.1
```

```
HTTP/1.1 204 No Content
```

## GET /v1/teams/:team_name/comments/:comment_id/stargazers

指定されたコメントにStarをしたユーザ一覧を取得します。

```
GET /v1/teams/docs/comments/123/stargazers HTTP/1.1
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "stargazers": [
    {
      "created_at": "2016-05-05T11:40:54+09:00",
      "body": null,
      "user": {
        "myself": true,
        "name": "Atsuo Fukaya",
        "screen_name": "fukayatsu",
        "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
      }
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 1,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```


## POST /v1/teams/:team_name/comments/:comment_id/star

指定されたコメントにStarをします。

- body (String)
    - (任意) 引用Starの本文です。

```
POST /v1/teams/docs/comments/123/star HTTP/1.1

{"body":"foo bar"}
```

```
HTTP/1.1 204 No Content
```

## DELETE /v1/teams/:team_name/comments/:comment_id/star

指定されたコメントへのStarを取り消します。

```
DELETE /v1/teams/docs/comments/123/star HTTP/1.1
```

```
HTTP/1.1 204 No Content
```

# Watch

- created_at (DateTime)
    - Watchをした日時です。
- user
    - Watchをしたユーザです。

## GET /v1/teams/:team_name/posts/:post_number/watchers

指定された記事にWatchをしたユーザ一覧を取得します。

```
GET /v1/teams/docs/posts/2312/watchers HTTP/1.1
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "watchers": [
    {
      "created_at": "2016-05-05T11:40:53+09:00",
      "user": {
        "myself": true,
        "name": "Atsuo Fukaya",
        "screen_name": "fukayatsu",
        "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png"
      }
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 1,
  "page": 1,
  "per_page": 20,
  "max_per_page": 100
}
```

## POST /v1/teams/:team_name/posts/:post_number/watch

指定された記事にWatchをします。

```
POST /v1/teams/docs/posts/2312/watch HTTP/1.1
```

```
HTTP/1.1 204 No Content
```

## DELETE /v1/teams/:team_name/posts/:post_number/watch

指定された記事のWatchを取り消します。

```
DELETE /v1/teams/docs/posts/2312/watch HTTP/1.1
```

```
HTTP/1.1 204 No Content
```

# カテゴリ

## POST /v1/teams/:team_name/categories/batch_move

指定されたカテゴリを配下のカテゴリを含めて一括で変更します。

- from (String)
    - 変更元のカテゴリです
- to (String)
    - 変更先のカテゴリです

```
POST /v1/teams/docs/categories/batch_move HTTP/1.1

{
  "from": "/foo/bar/",
  "to": "/baz/"
}

```

```
HTTP/1.1 200 OK

{
  "count": 3,
  "from": "/foo/bar/",
  "to": "/baz/"
}
```

- count:
    - サブカテゴリを含む変更されたカテゴリの数を表します

# タグ

## GET /v1/teams/:team_name/tags

タグ一覧をタグ付けされた記事数の降順で返却します。

- name:
    - タグ名
- posts_count:
    - タグ付けされた記事数

```
GET /v1/teams/docs/tags HTTP/1.1
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "tags": [
    {
      "name": "noexpand",
      "posts_count": 6
    },
    {
      "name": "ChromeExtension",
      "posts_count": 2
    },
    {
      "name": "rubykaigi",
      "posts_count": 2
    },
    {
      "name": "stock",
      "posts_count": 2
    },
    {
      "name": "markdown",
      "posts_count": 2
    },
    {
      "name": "yapcasiaA",
      "posts_count": 1
    },
    {
      "name": "tqrk09",
      "posts_count": 1
    },
    {
      "name": "idobata_io",
      "posts_count": 1
    },
    {
      "name": "RBUC",
      "posts_count": 1
    },
    {
      "name": "hcmpl",
      "posts_count": 1
    },
    {
      "name": "railsdm",
      "posts_count": 1
    },
    {
      "name": "消費税",
      "posts_count": 1
    },
    {
      "name": "tags",
      "posts_count": 1
    },
    {
      "name": "editor",
      "posts_count": 1
    },
    {
      "name": "仕様変更",
      "posts_count": 1
    },
    {
      "name": "yapcasia",
      "posts_count": 1
    }
  ],
  "prev_page": null,
  "next_page": null,
  "total_count": 16,
  "page": 1,
  "per_page": 1000,
  "max_per_page": 1000
}
```

# 共通URLによる招待

* url(String)
    * メンバーがチームへ参加する際にアクセスするURLを表します。

## GET /v1/teams/:team_name/invitation

チームへの招待URLを取得します。
このAPIは **team の owner** だけがご利用可能です。

```
GET /v1/teams/docs/invitation HTTP/1.1
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "url": "https://docs.esa.io/team/invitations/member-c05d112fa34870998ab4da1e98846ae3"
}
```

## POST /v1/teams/:team_name/invitation_regenerator

チームへの招待URLを再発行します。
このAPIは **team の owner** だけがご利用可能です。

```
POST /v1/teams/docs/invitation_regenerator HTTP/1.1
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "url": "https://docs.esa.io/team/invitations/member-58891f72edcbb8ac22f1e5548b0128d9"
}
```

# Emailによる招待

* email(String)
    * 招待したEメールアドレスです
* code (String)
    * 招待の識別子です
    * 削除時に利用します
* expires_at (DateTime String)
    * 招待の有効期限です
* url(String)
    * 招待されたメンバーがチームへ参加する際に使うURLです

## POST /v1/teams/:team_name/invitations

招待したいメンバーへ個別の招待URLを発行し、指定したEメールアドレスへ送信します。
このAPIは **team の owner** だけがご利用可能です。

* member (Object)
    * emails(Array of String)
        * 招待したいメンバーのEメールアドレスを**,**区切りで指定します。
        * 一度の招待上限は、__100__ 件となります。
* force (Boolean)
    * 「新規にチームに参加するアカウントのドメインを制限」している場合も、強制的に招待を送信したい場合、`true`を渡します
```
POST /v1/teams/:team_name/invitations HTTP/1.1
Content-Type: application/json

{
  "member": {
    "emails": ["foo@example.com", "bar@example.com", "other@example.net"]
}
```

```
HTTP/1.1 201 Created
Content-Type: application/json

{
    "invitations": [
        {
            "email": "foo@example.com",
            "code": "mee93383edf699b525e01842d34078e28",
            "expires_at": "2017-08-17T12:00:41+09:00",
            "url": "https://docs.esa.io/team/invitations/mee93383edf699b525e01842d34078e28/join"
        },
        {
            "email": "bar@example.com",
            "code": "m934f1f60732f49d50ee5b3f96841ff13",
            "expires_at": "2017-08-17T12:00:41+09:00",
            "url": "https://docs.esa.io/team/invitations/m934f1f60732f49d50ee5b3f96841ff13/join"
        }
    ],
    "rejected_emails": [
        "other@example.net"
    ]
}
```
## GET /v1/teams/:team_name/invitations

招待中のメンバーの一覧を取得します。
このAPIは **team の owner** だけがご利用可能です。

```
GET /v1/teams/:team_name/invitations HTTP/1.1
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
    "invitations": [
        {
            "email": "foo@example.com",
            "code": "mee93383edf699b525e01842d34078e28",
            "expires_at": "2017-08-17T12:00:41+09:00",
            "url": "https://docs.esa.io/team/invitations/mee93383edf699b525e01842d34078e28/join"
        },
        {
            "email": "bar@example.com",
            "code": "mc542eed211a8e4f1db6ccccb14fcda9d",
            "expires_at": "2017-08-17T12:00:44+09:00",
            "url": "https://docs.esa.io/team/invitations/mc542eed211a8e4f1db6ccccb14fcda9d/join"
        }
    ],
    "prev_page": null,
    "next_page": null,
    "total_count": 2,
    "page": 1,
    "per_page": 20,
    "max_per_page": 100
}
```

## DELETE /v1/teams/:team_name/invitations/:code

招待中のメンバーの招待を削除します。招待時に送信されたメールに記載された招待用のURLは無効となります。
このAPIは **team の owner** だけがご利用可能です。

* code (String)
    * 招待時の識別子を指定します
   
```
DELETE /v1/teams/:team_name/invitations/mee93383edf699b525e01842d34078e28 HTTP/1.1
```

```
HTTP/1.1 204 No Content
```

# Emoji

* code(String)
    * 絵文字を入力する際に使うコードです
* aliases(Array of String)
    * 絵文字に対するエイリアスコードです
* category(String)
    * Custom: カスタム絵文字でアップロードした絵文字です
    * Member: メンバー絵文字です
* raw(String)
    * Unicode 文字です
    * Unicode に絵文字がない場合は `NULL`になります
    * 参考: [ReleaseNotes/2023/09/11/絵文字の追加と更新をしました :partying\_face: - docs.esa.io](https://docs.esa.io/posts/495)
* url(String)
    * 絵文字の画像URLです
    * rawが空の場合は、こちらの画像URLを参照してください

## GET /v1/teams/:team_name/emojis

チームで利用可能な絵文字を取得します。URIクエリ文字列を含めない場合、チーム固有の絵文字だけを取得します。

```
GET /v1/teams/docs/emojis HTTP/1.1
```

### URIクエリ文字列

* include (String)
    * `all`を指定すると、チーム固有の絵文字だけではなく、すべての絵文字を返します。

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "emojis": [
    {
      "code": "grinning",
      "aliases": [
        "grinning"
      ],
      "category": "Smileys & Emotion",
      "raw": "😀",
      "url": "https://assets.esa.io/images/emoji/unicode/1f600.png"
    },
    {
      "code": "smiley",
      "aliases": [
        "smiley"
      ],
      "category": "Smileys & Emotion",
      "raw": "😃",
      "url": "https://assets.esa.io/images/emoji/unicode/1f603.png"
    },
    // ...省略...
  ]
}
```

## POST /v1/teams/:team_name/emojis

新しい絵文字を登録します。

- emoji (Object)
    - code (String, **required**)
        - 登録したい絵文字のコードです。絵文字を入力する際の両端の**:**を含めずに指定して下さい。
    - origin_code (String)
        - 既に登録されている絵文字に対するエイリアス絵文字を作成する際に指定して下さい。
    - image (String or File)
        - BASE64でencodeしたStringを指定して下さい。
        - Content-Type: multipart/form-dataでFileを指定することも可能です。
        -  新しい絵文字を作成する場合に指定して下さい。エイリアス絵文字を作成する際には不要です。
        - 画像の条件
            -  64KB以下
            - 128px x 128px以上
            - GIF or PNG

```
POST /v1/teams/docs/emojis HTTP/1.1
Content-Type: application/json

{
  "emoji": {
    "code": "team_emoji",
    "image": "..." // BASE64 String
  }
}
```

```
HTTP/1.1 201 Created

{
  "code": "team_emoji"
}
```

### multipart/form-dataで送る場合

```
POST /v1/teams/docs/emojis HTTP/1.1
Content-Type: multipart/form-data; boundary=------TestBoundaryi123456789

------TestBoundaryi123456789
Content-Disposition: form-data; name="emoji[code]"

team_emoji
------TestBoundaryi123456789
Content-Disposition: form-data; name="emoji[image]"; filename="emoji.png"
Content-Type: image/png

PNG
// ...省略...
```


## DELETE /v1/teams/:team_name/emojis/:code

登録したチーム固有の絵文字を削除します。

```
DELETE /v1/teams/docs/emojis/team_emoji
```

```
HTTP/1.1 204 No Content
```

# 認証中のユーザ

## GET /v1/user

現在のアクセストークンで認証中のユーザの情報を表します。

- id (Integer)
    - サービス内で一意なユーザIDです
- name (String)
    - ユーザの名前です
- screen_name (String)
    - ユーザのスクリーンネームです
- created_at (DateTime String)
    - ユーザの作成日時です
- updated_at (DateTime String)
    - ユーザの更新日時です
- icon (String)
    - ユーザのアイコンのURLです
- email (String)
    - ユーザのemailアドレスです

### URIクエリ文字列

- include (String)
    - `teams` を指定すると所属するチームの配列を含んだレスポンスを返します。

```
GET /v1/user HTTP/1.1
Content-Type: application/json
```

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 1,
  "name": "Atsuo Fukaya",
  "screen_name": "fukayatsu",
  "created_at": "2014-05-10T11:50:07+09:00",
  "updated_at": "2016-04-17T12:35:16+09:00",
  "icon": "https://img.esa.io/uploads/production/users/1/icon/thumb_m_402685a258cf2a33c1d6c13a89adec92.png",
  "email": "fukayatsu@esa.io"
}
```

# 他サービスからのインポートスクリプトのサンプル
## Qiita Team

[Qiita Teamからのインポート](https://docs.esa.io/posts/333)機能をご利用ください。

## DocBase

=> [esaio/d2e: DocBaseからesa.ioへのインポートスクリプト(サンプル)](https://github.com/esaio/d2e)

## GitHub Wiki

```ruby:import.rb
require 'esa'
require 'json'
require 'pp'
require 'pry'

class Importer
  def initialize(client, wiki_repo_url)
    @client = client

    `git clone #{wiki_repo_url} wiki_data` unless File.exist? 'wiki_data'
    Dir.chdir('wiki_data')
    @file_names = Dir.glob('*.md')
  end
  attr_accessor :client, :file_names

  def wait_for(seconds)
    (seconds / 10).times do
      print '.'
      sleep 10
    end
    puts
  end

  def import(dry_run: true)
    file_names.each do |file_name|

      title = File.basename(file_name)

      params = {
        name:     title,
        category: "Imports/GitHubWiki",
        body_md:  File.read(file_name),
        wip:      false,
        message:  '[skip notice] Imported from GitHub Wiki',
        user:     'esa_bot' # 記事作成者上書き: owner権限が必要
      }

      if dry_run
        pp params
        puts
        next
      end

      print "[#{Time.now}] #{title} => "
      response = client.create_post(params)
      case response.status
      when 201
        puts "created: #{response.body["full_name"]}"
      when 429
        retry_after = (response.headers['Retry-After'] || 20 * 60).to_i
        puts "rate limit exceeded: will retry after #{retry_after} seconds."
        wait_for(retry_after)
        redo
      else
        puts "failure with status: #{response.status}"
        exit 1
      end
    end
  end
end

client = Esa::Client.new(
  access_token: 'xxxxx',
  current_team: 'your-team-name' # 移行先のチーム名(サブドメイン)
)
importer = Importer.new(client, 'https://github.com/[organization]/[repo].wiki.git')

# dry_run: trueで確認後に dry_run: falseで実際にimportを実行
importer.import(dry_run: true)

```

# 今後の実装予定
- Preview API
- Revision API
