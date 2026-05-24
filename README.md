# เฝ้าระวังแผ่นดินไหว — 24/7 YouTube Live スタック

タイ77県の地震モニターを、VPS上から YouTube へ24時間流し続ける一式。

---

## これは何をするか
1. VPS の中で仮想画面を立ち上げ、`quake-thailand.html` を全画面表示
2. その画面 + 音声を FFmpeg がエンコード
3. YouTube Live へ RTMP で流し続ける
4. 落ちても `restart: always` で自動復帰 → 24h 無人運転

USGS のデータはブラウザが直接取りに行く（60秒ごと更新）。県境データはローカル同梱なので外部に依存しない。

---

## 必要なもの
- **VPS 1台**（推奨: Ubuntu 22.04 / 2 vCPU / 2GB RAM / $5〜10/月）
  - 720p なら 1〜2 vCPU で十分。1080p にするなら 2 vCPU 以上
  - 提供元の例: Hetzner / DigitalOcean / Vultr / Linode（どれでも可）
- **YouTube チャンネル**（ライブ配信が有効化されていること。初回は有効化に最大24h）

---

## セットアップ（5ステップ）

### 1. VPS に Docker を入れる
```bash
curl -fsSL https://get.docker.com | sh
```

### 2. このフォルダを VPS に置く
（`scp` でもいいし、git に上げて clone でもいい）
```bash
# 例: ローカルから
scp -r stream/ user@<VPSのIP>:~/
```

### 3. YouTube のストリームキーを取得
YouTube Studio → 作成 → ライブ配信 → 「ストリームキー」の長い文字列をコピー。
配信タイプは「24時間配信を許可」を選ぶ（自動停止を切る）。

### 4. .env を作る
```bash
cd ~/stream
cp .env.example .env
nano .env          # STREAM_KEY= に貼り付けて保存
```

### 5. 起動
```bash
docker compose up -d --build
```

数十秒後、YouTube Studio のライブ管理画面に映像が来る。「公開」にすれば配信開始。

---

## 運用

| やりたいこと | コマンド |
|---|---|
| ログを見る | `docker compose logs -f` |
| 止める | `docker compose down` |
| 再起動 | `docker compose restart` |
| 画面を更新（HTML差し替え後） | `app/` を更新して `docker compose up -d --build` |
| 画質を上げる | `.env` の WIDTH/HEIGHT/BITRATE を変えて再ビルド |

---

## BGM を付ける（任意）
無音でも配信は成立するが、YouTube 的には音があった方が良い。
`app/bgm.mp3` にロイヤリティフリーの曲を置くと、自動でループ再生される。
（著作権フリーの環境音・アンビエントを推奨。著作権付き楽曲は配信停止リスク）

---

## コスト目安（月）
- VPS: $5〜10（720p） / $15〜20（1080p）
- USGS データ: $0
- ドメイン（任意）: 年 $10 程度
- **合計: 月 $5〜20 で永続**

---

## 重要な注意（正直な開示）
- 各県の「揺れの強さ」は **震源の位置と規模からの推定値**。タイには高密度の実測網がないため。
  `quake-thailand.html` 内の `estIntensity()` は簡易式（科学的に正確ではない）。
  公式な数値として名乗るなら、正式な距離減衰式（GMPE）に差し替えること。
- 画面に「ค่าประมาณ（推定値）/ 資金を募って実測器を設置していく」と明示済み。
  これは「精度は低いと正直に開示しつつ共創する」という設計思想に沿ったもの。
