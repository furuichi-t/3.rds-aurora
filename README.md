terraform学習の過程として作ったものです。　公式ハンズオンを元にしています。  
公式ハンズオン：https://aws.amazon.com/jp/getting-started/hands-on/migrate-rdsmysql-to-auroramysql/?ref=gsrchandson  
参考文献：https://qiita.com/asflash8/items/090a92f6390e0de9f649  
  
variables.tfファイルにDBのユーザーネームとパスワードの変数がありますので、自身の好きな値に書き換えて使ってください。
またこちらはRDSからAuroraへの移行が目的ですので、2回applyする必要があります。  

Auroraレプリカを昇格させるのに、null_resourceまたはAWSCLIで対応できるという事を知り勉強になりました。
terraform管理でも一回きりの作業ならawscliコマンドでマネコンを使わなくても対応できるのかなと。

  
