# Ruby を使って EverySense の API で遊んでみよう！

Ruby のインタラクティブシェル irb あるいは pry などを利用して EverySense の API で遊んでみましょう。遊ぶ前にまず EverySense 基礎用語をおさえておきましょう。

## EverySense 基礎用語

https://service.every-sense.com で遊ぶためには最低限以下の用語を抑えておく必要があります。

- **ファームオーナー**: EverySenseにアップロードするデータを持っている人。デバイスのクラスを使って自分のデバイスを登録できます。デバイスを登録すると **デバイスのUUID** を取得できます。
- **レストランオーナー**: EverySenseからデータをダウンロードして活用する人。自分が欲しいデータの条件を **レシピ** として登録し、**レシピのUUID** を取得します。**レシピ** は検索条件で指定した **ファームオーナー** に送ることができます。検索条件はファームオーナーのキーワードから指定できます。
- **デバイスベンダー**: デバイスの開発元やデバイスにとっても詳しいデバイス所有者。デバイスのクラスを定義する権限をもちます。
- **レシピ**: **レストランオーナー** から **ファームオーナー** に送られる欲しいデータの条件。**レストランオーナー** は送られてきたレシピに対してデータを送信しても良いかどうか承認処理を行います。承認されたレシピでは承認した **ファームオーナー** のデバイス or ファーム (?)に送られたデータを取得することができます。
- **デバイスのクラス**: スマートフォンのようにデバイスには複数のセンサが搭載されていると想定されています。デバイスにどのような精度のセンサが搭載されているのか、例えば製品ごとに事前にクラスとして登録しておくことができます。**ファームオーナー** は保持しているデバイスに対応するクラスを選択して、EverySenseに登録することになります。

## アカウントの登録

EverySenseで遊ぶためには、https://service.every-sense.com でアカウントの登録が必要です。以降で出てくる login_name および password は service.every-sense.com で登録したものに置き換えて下さい。

以下ではまずデバイスのデータをアップロード、ダウンロードする方法から触れますので、ファームオーナーならびにレストランオーナーの権限が必要です。まずは、ファームオーナー（「センサー情報を提供される方」）でアカウント登録をして、上記サイトにログイン後、トップページにあるボタンで「レストランオーナー」の権限を申請してください。さらに「デバイスオーナー」の権限も登録しておくと、自分でオリジナルデバイスを登録することもできます。

## JSON over HTTP ゲートウェイで遊ぶっ！

さて、以下順番に遊んでいきましょう。

### Net::HTTP を使ってREST APIに接続し、session_key を取得してみよう！

以下では最も標準的な API である JSON over HTTPゲートウェイについて触れています。irb を起動して以下のコードを貼り付けてみましょう。ただし、your_name, your_password の部分は自分のlogin_name、passwordに置き換えてくださいね。

```ruby
require 'uri'
require 'net/http'
require 'json'
require 'time'

@uri = URI.parse('https://api.every-sense.com:8001/')
@https = Net::HTTP.new(@uri.host, @uri.port)
@https.use_ssl = true
session_req = Net::HTTP::Post.new(@uri + '/session')
session_req.body = {login_name: 'your_name', password: 'your_password'}.to_json
session_req.content_type = 'application/json'
session_res = @https.request(session_req)

session_res.code
session_res.message
session_res.body
```

最後の3行では以下の様な結果が出力されましたか？

```
irb(main):013:0* session_res.code
=> "200"
irb(main):014:0> session_res.message
=> "OK"
irb(main):015:0> session_res.body
=> "{\"code\":0,\"session_key\":\"YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYYY\"}"
```

ここで取得したsession_keyは、デバイスのAPI（/device_data）およびレシピのAPI（/recipe_data）を読み出す際に必要となります。デバイスのAPI (/device_data)は自分自身が登録したデバイスの情報を EverySense のプラットフォームを経由して取得したい場合に利用します。一方、レシピのAPI (/recipe_data) は、ファームオーナーに送ったレシピのうち、承認されたレシピからデータを取得したい場合に利用します。@session_keyに格納しておきましょう。

```ruby
@session_key = JSON.parse(session_res.body)["session_key"]
```

このあと、ここで作成した @uri, @https, @session_key を使ってデバイスやレシピにアクセスしていきます。


### デバイスのデータのアップロードとダウンロード

次にデバイスのデータのアップロード、ダウンロードについて試してみるため、テスト用のデバイス Test_Device を登録してください。デバイスの登録は以下から行えます。

https://service.every-sense.com/ja/devices

デバイスクラスとしてTest_Deviceを選択し、「追加」します。
登録できると、UUIDが表示されます。下記の "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" の部分を表示されたUUIDに置き換えて @device_id に保存し、以降続けていきましょう。

```ruby
@device_id = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
```

デバイスのデータのアップロード、ダウンロードをする際にUUIDが必要になります。

#### デバイスのデータのアップロード

まずはアップロードから試してみましょう。なんと、アップロードには認証は不要です。ということは、デバイスのUUIDを知っている人は誰でもアップロードできてしまうということですね。皆さんUUIDの取り扱いには注意しましょう。

以下のようにURIにデバイスのUUIDを指定して、アップロードしたいデータをPOSTします。ここでは content_type に 'application/json' を指定して、JSON形式のデータをアップロードしてみます。

```ruby
upload_req = Net::HTTP::Post.new(@uri + "/device_data/#{@device_id}")
upload_req.body = {test_data: {data1: "hoge", data2: 123}}.to_json
upload_req.content_type = 'application/json'
upload_res = @https.request(upload_req)
upload_res.body
```

最後の応答に以下のように 'code: 0' が返されていればアップロード成功です。

```
irb(main):023:0> upload_res.body
=> "{\"code\":0}"
```

#### デバイスのデータのダウンロード

データの取得にはログインID (UUID) + パスワードあるいは、session_keyが要求されます。以下では session_key を利用しています。

```ruby
device_data_res = @https.get(@uri + "/device_data/#{@device_id}?session_key=#{@session_key}")
device_data_res.body
```

しばらくはキャッシュされているので、getすると同じデータがダウンロードされます。そのため、
実際には from, to でデータが登録された期間を指定して必要なデータをすることになります。

```ruby
@from = (Time.now.utc - 86400).iso8601 # 1日前から 例) "2016-03-11T03:57:23Z"
@to = (Time.now.utc + 86400).iso8601 # 1日後まで 例) "2016-03-13T03:57:23Z"
device_data_res = @https.get(@uri + "/device_data/#{@device_id}?session_key=#{@session_key}&from=#{@from}&to=#{@to}")
device_data_res.body
```

指定した期間に含まれるデータは以下のように配列形式で返されます。

```
[50] pry(main)> device_data_res.body
=> "[{\"test_data\":{\"data1\":\"hoge\",\"data2\":123}},{\"test_data\":{\"data1\":\"hoge\",\"data2\":123}},{\"test_data\":{\"data1\":\"hoge\",\"data2\":123}},{\"test_data\":{\"data1\":\"hoge\",\"data2\":123}},{\"test_data\":{\"data1\":\"hoge\",\"data2\":123}}]"
[51] pry(main)> JSON.parse(device_data_res.body)
=> [{"test_data"=>{"data1"=>"hoge", "data2"=>123}},
 {"test_data"=>{"data1"=>"hoge", "data2"=>123}},
 {"test_data"=>{"data1"=>"hoge", "data2"=>123}},
 {"test_data"=>{"data1"=>"hoge", "data2"=>123}},
 {"test_data"=>{"data1"=>"hoge", "data2"=>123}}]
```

データが含まれない場合は空の配列が返されます。from, to の時刻はUTCで指定してください。 @from を適当に変えて、先ほどアップロードしたデータが表示される場合と表示されない場合をそれぞれ確認してみてください。


### レシピからのデータのダウンロード

次に「センサー情報収集」のため、レストランオーナーとしてレシピを登録、確認する方法について見ていきます。レストランオーナーになるためには、service.every-sense.com のログイン後画面から「レストランオーナー」の登録を行った上で、「オーナー切替」で「レストランオーナー」を選択して作業してください。

https://service.every-sense.com/

レストランオーナーに切り替えると、トップ画面に「レシピを作成」というメニューが表示されます。このメニューからレシピを作成してください。

レシピの作成が完了するとレシピのUUIDが表示されます。以降ではこのUUIDを @recipe_id に保存して利用します。また、ダウンロードする際のデータ形式として @format に 'json' を指定しておきましょう。

```ruby
@recipe_id = "ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ"
@format = 'json'
```

レシピを経由してデータを取得するにはファームーオーナーからレシピの承認を得る必要があります。レシピの宛先として特に条件を指定しなければ、条件に一致する全てのファームまたはファームオーナーにレシピが送信されます。レシピの受信にはしばらく時間がかかりますが、1分ほどまって、右上メニューから「ファームオーナー」にオーナーを切り替えると、「オーダー」に先ほど登録したレシピが表示されているはずです。「却下」になっているスライダーを「承認」に切り替えると、オーダーの状態が「稼働」に変わります。これでレシピからのデータ受信準備は完了です。

レシピからのデータダウンロード時のURIは以下のとおりです。うまくダウンロードできましたか？

```ruby
recipe_data_res = @https.get(@uri + "/recipe_data/#{@recipe_id}.#{@format}?session_key=#{@session_key}&from=#{@from}&to=#{@to}")
recipe_data_res.body
```

### session_keyの無効化について

device_dataにはlogin_name、passwordでもアクセスできますが、毎回提示すると login_name、passwordが奪われる可能性が高くなるため、今回代わりにsession_keyを用いてアクセスしました。ただし、session_keyが他人に奪われるとsession_keyが有効な期間不正にアクセスされる可能性があるため、利用が終わったらsession_keyを無効化するようにしましょう。以下の手順でsession_keyを無効化できます。

```ruby
del_session_req = Net::HTTP::Delete.new(@uri + "/session/#{@session_key}")
del_session_res = @https.request(del_session_req)
del_session_res.body
```

以下のように 'code: 0' が返されていれば削除成功です。

```
irb(main):037:0> del_session_res.body
=> "{\"code\":0}"
```

現状はsession_keyにはかなり長い時間の有効期間が与えられているようで、1日たってもアクセスできました (^^;; 忘れずに無効化しておきましょう。
