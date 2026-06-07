[English](README.md) | [中文](README.zh-CN.md) | **[日本語](README.ja.md)** | [Deutsch](README.de.md)

---

# Catodo

Flutter で構築されたクロスプラットフォームのタスク管理アプリ。スマートなビュー、AI アシスタント、WebDAV によるシームレスなデバイス間同期でタスクを管理します。

## 機能

- **タスク管理** - 優先度、タグ、グループ、期限、複数リマインダー付きでタスクの作成・編集・完了・削除
- **スマートビュー** - リストビュー、日別ビュー（今日に集中 / 期限切れ非表示）、アイゼンハワーマトリックスによる優先度ベースの整理
- **繰り返しタスク** - 毎日・毎週・毎月の繰り返しルールを設定、完了時に次のインスタンスを自動生成
- **WebDAV 同期** - 3つの競合解決モード（自動マージ・ローカル優先・リモート優先）とソフト削除伝播による増分デバイス間同期
- **AI アシスタント** - 自然言語で LLM エージェントと対話し、タスクの作成・更新・分解・管理
- **データのインポート/エクスポート** - `.ics` カレンダー形式と `.catodo` 完全バックアップ形式（機密設定の含む/含まない選択可能）
- **ローカル通知** - アプリ再起動後も維持されるスケジュールリマインダー
- **マルチプラットフォーム** - Android、iOS、Windows、macOS、Linux、Web

## インストール

### 前提条件

- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.12.0
- Dart SDK >= 3.12.0
- Android：Android SDK（minSdkVersion 21+）
- iOS：Xcode 15+、CocoaPods
- デスクトップ：対応プラットフォームのビルドツール

### ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/your-username/catodo.git
cd catodo

# 依存関係をインストール
flutter pub get

# Isar スキーマを生成
dart run build_runner build --delete-conflicting-outputs

# 接続済みデバイスまたはエミュレータで実行
flutter run
```

### リリースビルド

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release

# Web
flutter build web --release
```

## 使い方

### タスク管理

| 操作 | 方法 |
|------|------|
| タスクを作成 | 下部バーの **+** ボタンをタップ、フォームに入力、**保存** をタップ |
| タスクを編集 | タスクカードをタップしてエディタを開く |
| タスクを完了 | タスクカードの丸いチェックボックスをタップ |
| タスクを削除 | タスクエディタを開き、下部までスクロール、**タスクを削除** をタップ、確認 |
| 優先度を設定 | タスクフォームで なし / 低 / 中 / 高 を選択 |
| リマインダーを設定 | タスクフォームで **リマインダーを追加** をタップ、日時を選択 |
| 繰り返しを設定 | フォームで **繰り返しタスク** をオンにし、毎日/毎週/毎月と間隔を選択 |

### ビュー

- **リストビュー**（デフォルト）- グループとタグフィルター付きの全アクティブタスク
- **日別ビュー** - 期限日ごとにグループ化、全て / 今日に集中 / 期限切れ非表示 を切り替え可能
- **アイゼンハワーマトリックス** - 緊急度と重要度（優先度）に基づく4象限ビュー

### WebDAV 同期

1. **設定 > WebDAV 同期** に移動
2. WebDAV サーバーの URL、ユーザー名、パスワードを入力
3. **接続テスト** をタップして確認
4. **設定を保存** をタップ
5. 同期モードを選択：
   - **自動マージ**（デフォルト）- 競合時に最新の `updatedAt` を採用
   - **ローカル優先** - 競合時にローカルバージョンを優先
   - **リモート優先** - 競合時にリモートバージョンを優先
6. **同期開始** をタップ

### AI アシスタント

1. **設定 > AI アシスタント** に移動し、LLM プロバイダーを設定（OpenAI、DeepSeek、豆包、GLM、Qwen、Kimi、またはカスタムエンドポイント）
2. API キーとモデル名を入力し、**設定を保存** をタップ
3. 下部ナビゲーションの **AI** タブに切り替え
4. 自然にチャット - AI エージェントがタスクの作成、分解、タグ追加、優先度設定などを行います
5. 低リスク操作（作成、タグ、グループ、優先度）は自動実行、高リスク操作（更新、完了、削除）は確認が必要

### データのインポート/エクスポート

**設定 > データ管理** に移動：

| 操作 | 形式 | 説明 |
|------|------|------|
| インポート | `.ics` | カレンダーファイルからタスクをインポート |
| インポート | `.catodo` | Catodo 完全バックアップから復元 |
| エクスポート | `.ics` | アクティブなタスクをカレンダーファイルとしてエクスポート |
| エクスポート | `.catodo` | 全タスクと設定をエクスポート（機密データの含む/含まない選択可能） |

## 設定

### AI プロバイダー設定

`SharedPreferences` に保存：

| キー | 説明 |
|------|------|
| `ai_provider_id` | プロバイダー ID（`openai`、`deepseek`、`doubao`、`glm`、`qwen`、`moonshot`、`custom`） |
| `ai_api_url` | API エンドポイント URL |
| `ai_api_key` | API キー |
| `ai_model` | モデル名 |

### WebDAV 設定

`SharedPreferences` に保存：

| キー | 説明 |
|------|------|
| `webdav_url` | WebDAV サーバー URL |
| `webdav_username` | ユーザー名 |
| `webdav_password` | パスワード |
| `sync_mode` | 競合解決モード（`autoMerge`、`localFirst`、`remoteFirst`） |

### 日別ビュー設定

| キー | 説明 |
|------|------|
| `day_view_mode` | ビューフィルター（`all`、`focusToday`、`hideOverdue`） |

## プロジェクト構成

```
lib/
├── main.dart                    # アプリのエントリ、ナビゲーション、リマインダースケジューリング
├── models/
│   ├── task.dart                # Task モデル（Isar Collection）
│   └── filter.dart              # TaskFilter モデル
├── data/
│   └── task_dao.dart            # データアクセスオブジェクト
├── services/
│   ├── database_service.dart    # Isar シングルトン管理
│   ├── webdav_service.dart      # WebDAV 同期サービス
│   ├── ai_service.dart          # AI API クライアント
│   ├── ai_agent.dart            # AI エージェントのアクション定義と実行
│   ├── nlp_service.dart         # 自然言語解析サービス
│   ├── ics_service.dart         # ICS ファイルの解析と生成
│   ├── catodo_io_service.dart   # .catodo 形式のインポート/エクスポート
│   ├── notification_service.dart # 通知サービス（条件付きエクスポート）
│   ├── repeat_task_service.dart  # 繰り返しタスク生成サービス
│   └── llm_provider_registry.dart # LLM プロバイダー定義
├── providers/
│   ├── isar_provider.dart       # Isar インスタンスプロバイダー
│   ├── task_providers.dart      # タスク関連プロバイダー
│   ├── webdav_provider.dart     # WebDAV 設定と同期モード
│   └── day_view_provider.dart   # 日別ビューモード
└── ui/
    ├── screens/                 # ページウィジェット
    └── components/              # 再利用可能な UI コンポーネント
```

## 開発

### テストの実行

```bash
# ユニットテスト
flutter test

# 静的解析
flutter analyze

# モデル変更後に Isar スキーマを再生成
dart run build_runner build --delete-conflicting-outputs
```

### アーキテクチャ

アプリはレイヤードアーキテクチャを採用：

```
UI レイヤー（画面、コンポーネント）
    ↓
状態管理レイヤー（Riverpod プロバイダー）
    ↓
サービスレイヤー（WebDAV、AI、通知など）
    ↓
データレイヤー（TaskDao、Isar データベース）
```

## コントリビュート

コントリビュートを歓迎します！参加方法：

1. リポジトリを **フォーク**
2. フィーチャーブランチを **作成**：`git checkout -b feature/your-feature-name`
3. 明確で説明的なコミットメッセージで変更を **コミット**
4. 変更を **テスト**：`flutter test` と `flutter analyze` を実行
5. フォークに **プッシュ**：`git push origin feature/your-feature-name`
6. `main` ブランチに対して Pull Request を **作成**

### ガイドライン

- 既存のコードスタイルとプロジェクト構成に従う
- 新機能にはテストを追加
- PR は単一の関心事に集中させる
- パブリック API と複雑なロジックにはドキュメントを記載
- `flutter analyze` が警告なしで通ることを確認

## ライセンス

このプロジェクトは GNU General Public License v3.0 の下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照してください。

## お問い合わせ

- **プロジェクトメンテナー**：[Issue を作成](https://github.com/your-username/catodo/issues)
- **バグ報告**：[GitHub Issues](https://github.com/your-username/catodo/issues)
- **機能リクエスト**：[GitHub Issues](https://github.com/your-username/catodo/issues)
