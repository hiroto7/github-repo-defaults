# GitHubリポジトリの標準設定（PoC）

個人で複数のリポジトリを管理していると、CI、Dependabot、マージ方式、
Rulesetなど、よく似た設定をリポジトリごとに繰り返すことになります。

このリポジトリは、それらの共通設定をプロファイルとしてコード化し、
GitHub CLI（`gh`）を使って新しいリポジトリへ適用するための
概念実証（PoC）です。

コマンドは安全のためdry-runが既定です。`--apply`を付けない限り、
GitHub上の設定は変更しません。

```console
# 変更予定を表示するだけ
./bin/repo-bootstrap hiroto7/example --profile python

# 内容を確認したうえでGitHubへ適用する
./bin/repo-bootstrap hiroto7/example --profile python --apply
```

## プロファイル

| プロファイル | 必須チェック | 想定用途 |
| --- | --- | --- |
| `python` | `test` | Ubuntuで動かすPythonサービスやCLI |
| `python-macos` | `test (macos-latest)`、`test (ubuntu-latest)`、`package-macos` | macOSアプリとして配布するPythonアプリケーション |
| `node-web` | `build`、`e2e` | Playwrightを使用するNode.js Webアプリケーション |
| `tooling` | `test` | シェルスクリプトを中心としたリポジトリ管理ツール |

各プロファイルのCIとDependabotのひな形は、
[`assets/templates/`](skills/bootstrap-github-repo/assets/templates/)以下にあります。対象リポジトリへ対応する
`.github`ディレクトリを導入し、初回コミットをpushしてCIが動く状態にしてから、
同じプロファイルのRulesetを適用してください。

`node-web`では、同じテンプレートの`scripts/`も導入します。`package.json`に
バージョンを固定した`@playwright/test`とKnipを開発依存関係として追加し、
`test:e2e`を`bash ./scripts/run-e2e-in-docker.sh`、`knip`を実行するnpm scriptに設定します。
CIとローカルのE2Eは同じDockerコマンドを使い、Dockerイメージのバージョンは
`@playwright/test`から決まります。ローカル実行にもDockerが必要です。
PlaywrightのDependabot更新は、他のminor・patch更新と分けて確認します。
アプリに合わせたPlaywrightのテストとKnipの入口設定を用意してからCIを必須化してください。

このPoCは、別のリポジトリへファイルを自動でcommit・pushしません。
アプリケーション固有のコマンドを確認してから導入できるよう、
ファイル配置とGitHub設定の適用を意図的に分けています。

## `--apply`で変更する設定

`--apply`を付けると、対象リポジトリへ次の設定を適用します。

- squash mergeを有効化
- merge commitとrebase mergeを無効化
- マージ後の作業ブランチを自動削除
- プロファイルに対応する`standard-main` Rulesetを作成または更新
- `python-macos`では、`v*`タグを保護する`release-tags` Rulesetも作成または更新

`standard-main` Rulesetでは、次の条件を必須にします。

- `main`の削除とforce pushを禁止
- linear historyと署名付きコミット
- Pull Request経由の変更
- 未解決のレビュースレッドがないこと
- プロファイルで定義されたGitHub Actionsチェックの成功

個人リポジトリで無理なく使えるよう、承認レビュー数は0件です。
Pull Requestは他者の承認ではなく、CIゲート、変更内容の確認、
作業単位の記録として利用する想定です。

Rulesetは名前と対象種別を使って作成・更新します。同じプロファイルを再適用すると、
管理対象のRulesetを重複作成せずに更新します。このツールが管理していない
Rulesetには触れません。

## 導入手順

1. 対象リポジトリに、対応する`skills/bootstrap-github-repo/assets/templates/<profile>/.github`の内容を配置します。
2. アプリ名、パッケージコマンド、E2Eテストなどを対象リポジトリに合わせます。`node-web`では上記の依存関係、npm script、Dockerランナーも設定します。
3. 初回コミットをpushし、GitHub Actionsのチェック名がプロファイルと一致することを確認します。
4. `repo-bootstrap`を`--apply`なしで実行し、変更予定を確認します。
5. 問題がなければ`--apply`を付けて設定とRulesetを適用します。

Rulesetを先に適用すると、必須チェックがまだ存在しないため、最初の変更を
マージできなくなる可能性があります。CIを先に動かしてから適用してください。

## Codex Skill

同じ手順をCodexから繰り返し利用できるよう、
[`bootstrap-github-repo`](skills/bootstrap-github-repo/) Skillを同梱しています。

GitHub上のSkillを正本とし、各PCのCodex Skillsディレクトリにはインストールした
コピーを置く想定です。ローカルのコピーを直接編集せず、このリポジトリで変更、
テスト、レビューしてから再インストールしてください。

Skillは対象リポジトリの技術構成を調査し、プロファイル選択、テンプレート調整、
CI確認、dry-run、Ruleset適用後の再確認までを案内します。実際のGitHub設定変更は、
Skill内の決定的な`repo-bootstrap`スクリプトが担当します。

## 必要なものと制約

- リポジトリ管理権限で認証済みの`gh`
- `jq`
- 初回ファイルをpush済みのGitHubリポジトリ
- リポジトリの公開範囲とGitHubプランでRulesetを利用できること

同梱しているWorkflowは出発点です。すべてのアプリケーションでそのまま使える
汎用ビルド定義ではありません。パッケージ生成やE2Eなど、アプリケーション固有の
処理は各リポジトリ側で管理してください。

## テスト

次のコマンドで、シェル構文、Ruleset JSON、Workflow YAML、dry-run、
Rulesetの作成・更新経路を検証できます。

```console
./tests/test_repo_bootstrap.sh
```
