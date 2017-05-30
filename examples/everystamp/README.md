# EveryStampおよびEveryPostのデータ蓄積

ここではfluentd (fluent-plugin-everysense, fluent-plugin-elasticsearch) を用いて，EverySenseサーバから取得したデータをElasticSearchに蓄積し，Kibanaで可視化する事例を紹介します．


## ElasticSearchおよびKibanaのセットアップ

ElasticSearchについて，詳細はElasticSearchのページをご参照ください．

https://www.elastic.co/downloads/elasticsearch

Linuxの場合は以下のページにある方法でパッケージ管理システム (apt, yum) を用いてインストールするのが簡単です．

https://www.elastic.co/guide/en/elasticsearch/reference/5.0/deb.html


Kibanaも同様にパッケージ管理システムを用いてインストールできます．

https://www.elastic.co/guide/en/kibana/5.0/deb.html

インストールが完了したらサービスを開始します．

```
sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable elasticsearch.service
sudo /bin/systemctl start elasticsearch.service
sudo /bin/systemctl enable kibana.service
sudo /bin/systemctl start kibana.service
```

ブラウザで http://localhost:5601/ にアクセスするとKibanaの画面が表示されます．


## fluentd のセットアップ

fluentdのインストールにはRubyが必要です．

```
### rbenvのインストール
sudo mkdir /usr/local/rbenv
sudo chown your_account:your_account_group /usr/local/rbenv
git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv
cd /usr/local/rbenv && src/configure && make -C src
echo 'export PATH="/usr/local/rbenv/bin:$PATH"' >> ~/.bashrc
echo 'export RBENV_ROOT="/usr/local/rbenv"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
### ruby-buildのインストール
git clone https://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build
### rubyのインストール
rbenv install 2.4.1
rbenv global 2.4.1
```
以下fluentdと必要なpluginのインストールです．

```
### fluentdのインストール
gem install fluent-plugin-everysense fluent-plugin-elasticsearch
```


## ElasticSearchでのmappingの作成

everysense-mapping.json ファイルを用いてmappingを作成します．

```
curl -XPUT 'http://localhost:9200/everysense'
curl -XPUT 'http://localhost:9200/everysense/everystamp/_mapping' -d @everysense-mapping.json
```

KibanaのSettingsのindex nameとしてpiotを指定し，時間属性としてtimestampを指定して，index patternを作成します．farm_uuidなどはグラフ化の際にsub-bucketsとして指定することがあるため，keyword型で登録しています．


## fluentdの設定

everysense.conf ファイルを用いてfluentdを立ち上げます．

```
fluentd -c everysense.conf -vvv
```

これでEverySense ServerにアップロードされたデータをElasticSearchに格納できるようになりました．

fluentdをデーモンとして起動する方法については以下のページなどを参照してください．

"fluentdをsystemdで管理する" (matetsuだもんで)
http://matetsu.hatenablog.com/entry/2015/12/08/015444
