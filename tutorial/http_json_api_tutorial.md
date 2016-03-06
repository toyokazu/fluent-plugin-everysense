# Ruby を使って EverySense の API で遊んでみよう！

Ruby のインタラクティブシェル irb あるいは pry などを利用して EverySense の API で遊んでみましょう。以下では最も標準的な API である JSON over HTTPゲートウェイについて触れています。irb を起動して以下のコードを貼り付けてみましょう。ただし、login_name および password は以下のURIからご自身で登録したものに書き換えて下さい。

https://service.every-sense.com/

以下ではまずデバイスのデータをアップロード、ダウンロードする方法から触れますので、ファームオーナー（「センサー情報を提供される方」）でアカウント登録をしてください。

```ruby
require 'uri'
require 'net/http'
require 'json'

uri = URI.parse('https://api.every-sense.com:8001/')
https = Net::HTTP.new(uri.host, uri.port)
https.use_ssl = true
session_req = Net::HTTP::Post.new(uri + '/session')
session_req.body = {login_name: 'your_name', password: 'your_password'}.to_json
session_req.content_type = 'application/json'
session_res = https.request(session_req)

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

ここで取得した session_key は、デバイスのデータ（/device_data）およびレシピのデータ（/recipe_data）を読み出す際に必要となります。

```ruby
session_key = JSON.parse(session_res.body)["session_key"]
```

次にデバイスのデータのアップロード、ダウンロードについて試してみるため、テスト用のデバイス Test_Device を登録してください。デバイスの登録は以下から行えます。

https://service.every-sense.com/ja/devices

デバイスクラスとしてTest_Deviceを選択し、「追加」します。
登録できると、UUIDが表示されます。
XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX

デバイスのデータのアップロード、ダウンロードをする際にUUIDが必要になります。

まずはアップロードから試してみましょう。なんと、アップロードには認証は不要です。ということは、デバイスのUUIDが知っている人は誰でもアップロードできてしまう？？皆さんUUIDの取り扱いには注意しましょう。

URIにデバイスのUUIDを指定して、アップロードしたいデータをPOSTします。ここでは content_type に 'application/json' を指定して、JSON形式のデータをアップロードしてみます。

```ruby
upload_req = Net::HTTP::Post.new(uri + '/device_data/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX')
upload_req.body = {test_data: {data1: "hoge", data2: 123}}.to_json
upload_req.content_type = 'application/json'
upload_res = https.request(upload_req)
upload_res.body
```

最後の応答に以下のように 'code: 0' が返されていればアップロード成功です。

```
irb(main):023:0> upload_res.body
=> "{\"code\":0}"
```

データの取得にはログインID (UUID) + パスワードあるいは、session_keyが要求されます。以下では session_key を利用しています。

```ruby
get_res = https.get(uri + "/device_data/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX?session_key=#{session_key}")
get_res.body
```

しばらくはキャッシュされているので、getすると同じデータがダウンロードされます。そのため、
実際には from, to でデータが登録された期間を指定して必要なデータをすることになります。

```ruby
get_res = https.get(uri + "/device_data/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX?session_key=#{session_key}&from=2016-03-06-06:20&to=2016-03-06-07:00")
get_res.body
```

from, to の時刻はUTCで指定してください。

次に「センサー情報収集」のため、レストランオーナーとしてレシピを登録、確認する方法について見ていきます。レストランオーナーになるためには、service.every-sense.com の右上の設定メニューから「レストランオーナー」の登録を行った上で、「オーナー切替」で「レストランオーナー」として作業してください。

https://service.every-sense.com/

ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ


```ruby
recipe_data = https.get(uri + "/recipe_data/ZZZZZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZZZZZZZZZ.xml?session_key=#{session_key}&from=2016-03-06-07:00&to=2016-03-06-07:50")
recipe_data.body
```
