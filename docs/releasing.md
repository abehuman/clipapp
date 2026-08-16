# ClipApp リリース手順

この文書は、ClipAppをMac App Storeを使わずにGitHub Releasesから配布し、
Sparkleで自動更新を届けるための正本である。通常は
`.github/workflows/release.yml`を使い、GitHub-hosted macOS runner上で署名、
Apple Notarization、Release公開、GitHub Pagesへのappcast配信まで自動化する。

## 普段あなたがやることは3つだけ

初回設定が完了した後は、この3つだけ行う。

1. Codexへ「次のバージョンをリリースして」と依頼する。
2. Codexからpush前の確認を求められたら、対象バージョンを確認して承認する。
3. GitHub Actionsの`release`承認ボタンを押し、完了後にダウンロードしたClipAppを
   起動して動作を確認する。

バージョン変更、テスト、commit、tag作成、署名、Notarization、ZIP作成、GitHub
Release、Sparkle appcastの更新はCodexとGitHub Actionsが行う。証明書やAPI Keyの
更新を求められない限り、以下の詳細手順を毎回読む必要はない。

> ここから下は、Codexが作業するとき、初回設定をやり直すとき、または障害から
> 復旧するときの詳細資料である。

## 結論

初回設定が終われば、リリースごとにローカルMacで署名する必要はない。

```text
mainへpush
  → v<version>タグをpush
  → GitHubでrelease Environmentを承認
  → テスト
  → Developer ID署名
  → Apple Notarization
  → Draft Releaseの検証
  → GitHub Release公開
  → GitHub Pagesへappcast公開
  → appcastをmainへ記録
```

通常の`main`へのpushだけではリリースされない。`v1.4.1`のようなタグを
`origin`へpushしたときだけRelease workflowが開始される。

## 用語

| 用語 | 役割 |
| --- | --- |
| Developer ID署名 | ClipAppが正規の開発者によって作られ、改ざんされていないことをmacOSへ示す |
| Notarization | Appleがアプリの署名と悪意あるコードの有無を自動検査する。App Store Reviewではない |
| Sparkle | ClipApp内の「Check for Updates…」と自動更新を提供する |
| appcast | Sparkleへ最新バージョン、ダウンロードURL、署名を伝えるXMLフィード |
| GitHub Environment | Release用Secretsを保管し、署名ジョブの前に手動承認を要求する境界 |

## 作業頻度

| 作業 | 場所 | 頻度 |
| --- | --- | --- |
| Developer ID証明書の作成と`.p12`エクスポート | Xcode / ローカルMac | 初回と証明書更新時 |
| App Store Connect Team API Keyの作成 | App Store Connect | 初回と鍵のローテーション時 |
| Sparkle秘密鍵のエクスポートとバックアップ | ローカルMac | 初回。鍵は原則維持する |
| GitHub `release` EnvironmentとSecretsの設定 | GitHub | 初回と認証情報更新時 |
| GitHub PagesをActions方式へ変更 | GitHub | 初回のみ |
| バージョン更新、テスト、mainへのpush | ローカル | 毎回 |
| バージョンタグのpush | ローカル | 毎回 |
| `release` Environmentの承認 | GitHub Actions | 毎回 |
| ダウンロード版とSparkle更新の実機確認 | Mac | 毎回 |

## 常に守ること

- push先はユーザー所有の`origin`だけとし、Clipy本家の`upstream`へは絶対に
  pushしない。
- 証明書、`.p12`、`.p8`、Sparkle秘密鍵、パスワードをリポジトリ、Issue、
  workflowログ、Release assetへ入れない。
- Base64は暗号化ではない。GitHub Environment Secretsと承認ルールが保護境界で
  ある。
- appcastが参照するRelease assetsを先に公開し、その後にappcastを公開する。
- 公開済みRelease assetを別内容で置き換えない。変更が必要ならバージョンを
  上げ、再ビルド、再署名、再Notarizationする。
- push済みのバージョンタグを移動または再利用しない。
- ZIPはAppleの推奨どおり`ditto -c -k --keepParent`で作成し、
  `--sequesterRsrc`を使用しない。
- GitHub Actionsの成功だけで完了とせず、公開物をMacへダウンロードして確認する。

## 初回だけ行う準備

### 1. Release workflowを`main`へ導入する

`.github/workflows/release.yml`、リリース用スクリプト、設定ファイル、この文書を
コミットして`origin/main`へpushする。workflowがGitHubに存在する前にタグを
pushしない。

push前に必ず対象を確認する。

```sh
git status --short --branch
git remote -v
git diff --check
```

`origin`が`https://github.com/abehuman/clipapp.git`、`upstream`が
`https://github.com/Clipy/Clipy.git`であることを確認する。

### 2. Developer ID Application証明書を用意する

GitHub上の一時MacがClipAppへDeveloper ID署名できるよう、証明書と秘密鍵を
パスワード付きPKCS#12ファイルとしてエクスポートする。

1. Xcodeで **Xcode > Settings > Accounts** を開く。
2. Apple Accountとチームを選択する。
3. **Manage Certificates** を開く。
4. `Developer ID Application`証明書を確認する。なければ作成する。
5. 対象証明書をControlクリックし、**Export Certificate** を選ぶ。
6. 暗号化ストレージへ`.p12`として保存し、強い専用パスワードを設定する。

ローカルで次を実行し、`Developer ID Application`が有効なidentityとして
表示されることを確認する。

```sh
security find-identity -v -p codesigning
```

`.p12`とパスワードの両方を取得した人は、Developer ID名義でソフトウェアへ
署名できる。別々に保管し、GitHub登録後も暗号化したオフラインバックアップを
残す。

### 3. App Store Connect Team API Keyを用意する

この鍵はGitHub runnerがAppleのNotary serviceへ認証するために使う。Individual
API Keyは`notarytool`に使えないため、Team API Keyを作成する。

1. App Store Connectで **Users and Access > Integrations** を開く。
2. **App Store Connect API > Team Keys** を選ぶ。
3. **Generate API Key**を選ぶ。
4. `ClipApp GitHub Release`など用途が分かる名前を付ける。
5. Notarizationに必要な最小権限を持つroleを選ぶ。
6. `.p8`をダウンロードする。
7. Key IDとIssuer IDを安全な場所へ控える。

`.p8`は一度しかダウンロードできない。失った場合は古い鍵をrevokeし、新しい
Team API Keyを作成する。

登録前に、アプリを送信しない読み取り操作で認証を確認できる。

```sh
xcrun notarytool history \
  --key /secure/path/AuthKey_KEY_ID.p8 \
  --key-id YOUR_KEY_ID \
  --issuer YOUR_ISSUER_ID
```

### 4. Sparkle秘密鍵をバックアップする

既存のClipAppは`ClipApp/Supporting Files/Info.plist`内の`SUPublicEDKey`を信頼して
更新を検証する。対応する秘密鍵はログインKeychainの
`jp.co.aiv.clipApp`アカウントにある。

Swift packagesが未解決なら、最初に次を実行する。

```sh
xcodebuild -resolvePackageDependencies \
  -project ClipApp.xcodeproj \
  -scheme ClipApp \
  -clonedSourcePackagesDirPath build/SourcePackages
```

秘密鍵を暗号化ストレージへエクスポートする。

```sh
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account jp.co.aiv.clipApp \
  -x /secure/path/clipapp-sparkle-private-key
```

次の2つが同じ公開鍵を表示することをローカルで確認する。

```sh
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account jp.co.aiv.clipApp \
  -p

/usr/libexec/PlistBuddy \
  -c 'Print :SUPublicEDKey' \
  'ClipApp/Supporting Files/Info.plist'
```

秘密鍵の内容は表示、共有、commitしない。この鍵を失うと既存ユーザーへの更新が
困難になるため、GitHubとは別に暗号化バックアップを残す。

### 5. GitHub `release` Environmentを作成する

GitHubで次を開く。

```text
abehuman/clipapp > Settings > Environments > New environment
```

Environment名を正確に`release`とし、次の保護ルールを設定する。

- **Required reviewers**: リリース承認者を指定する。
- 一人運営で自分が開始したrunを自分で承認する場合、
  **Prevent self-review**はOFFにする。
- **Deployment branches and tags**: **Selected branches and tags**を選ぶ。
- Tag ruleとして`v*.*.*`を追加する。

Environment承認前には署名ジョブが開始されず、Environment Secretsもrunnerへ
渡らない。承認時にはタグ、対象commit、workflowの変更内容を確認する。

### 6. GitHub Environmentへ認証情報を登録する

Environment variableを1個登録する。

| 名前 | 内容 |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer Team ID。証明書subjectの`OU`またはApple Developer accountで確認する |

Environment secretsを6個登録する。

| 名前 | 内容 |
| --- | --- |
| `APPLE_DEVELOPER_ID_P12_BASE64` | パスワード付き`.p12`のBase64 |
| `APPLE_DEVELOPER_ID_P12_PASSWORD` | `.p12`のエクスポートパスワード |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Team API Key `.p8`のBase64 |
| `APP_STORE_CONNECT_API_KEY_ID` | Team API KeyのKey ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Team API KeyのIssuer ID |
| `SPARKLE_PRIVATE_KEY_BASE64` | エクスポートしたSparkle秘密鍵ファイルのBase64 |

`gh`を使う場合は、秘密情報を標準出力やshell historyへ表示せず登録する。

```sh
gh variable set APPLE_TEAM_ID \
  --env release \
  --repo abehuman/clipapp \
  --body 'YOUR_TEAM_ID'

base64 -i /secure/path/developer-id.p12 | \
  gh secret set APPLE_DEVELOPER_ID_P12_BASE64 \
    --env release --repo abehuman/clipapp
gh secret set APPLE_DEVELOPER_ID_P12_PASSWORD \
  --env release --repo abehuman/clipapp

base64 -i /secure/path/AuthKey_KEY_ID.p8 | \
  gh secret set APP_STORE_CONNECT_API_KEY_BASE64 \
    --env release --repo abehuman/clipapp
gh secret set APP_STORE_CONNECT_API_KEY_ID \
  --env release --repo abehuman/clipapp
gh secret set APP_STORE_CONNECT_API_ISSUER_ID \
  --env release --repo abehuman/clipapp

base64 -i /secure/path/clipapp-sparkle-private-key | \
  gh secret set SPARKLE_PRIVATE_KEY_BASE64 \
    --env release --repo abehuman/clipapp
```

値そのものは再表示せず、名前が揃っていることだけを確認する。

```sh
gh variable list --env release --repo abehuman/clipapp
gh secret list --env release --repo abehuman/clipapp
```

GitHub登録と暗号化オフラインバックアップを確認した後、Downloadsなどに残った
不要な平文コピーを削除する。

### 7. GitHub PagesをActions方式へ変更する

GitHubで次を開く。

```text
Settings > Pages > Build and deployment > Source
```

Sourceを**GitHub Actions**へ変更する。Release workflowはGitHub Release assetsを
公開した後、`docs/`をPages artifactとして明示的にdeployする。

変更直後に既存appcastが引き続き取得できることを確認する。

```sh
curl --fail --location \
  https://abehuman.github.io/clipapp/appcast.xml \
  --output /tmp/clipapp-appcast.xml
xmllint --noout /tmp/clipapp-appcast.xml
```

問題がある場合はPages Sourceを
**Deploy from a branch > main > /docs**へ戻せる。

## 毎回の自動リリース手順

以下では`1.4.1`を例にする。実際には現在公開中のバージョンより大きいsemantic
versionを使う。

### 1. リリース対象を確定する

- リリースに含めるcommitと変更を確認する。
- 意図しない変更、秘密情報、ローカル生成物がないことを確認する。
- 変更された機能に必要な手動テストを完了する。
- 公開後にユーザーへ説明する変更点を整理する。

```sh
git status --short --branch
git log --oneline --decorate -10
git diff --check
```

### 2. バージョンを更新する

`Configurations/ClipApp.xcconfig`の2項目を同じ値にする。

```text
MARKETING_VERSION = 1.4.1
CURRENT_PROJECT_VERSION = 1.4.1
```

両方とも現在のappcastより新しい`<major>.<minor>.<patch>`形式にする。

### 3. テストとバージョン検証を実行する

```sh
xcodebuild \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -scheme ClipApp \
  -project ClipApp.xcodeproj \
  -destination 'platform=macOS' \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  test

scripts/validate-release-version.sh v1.4.1
git diff --check
```

テスト失敗、version不一致、現在のappcast以下のversionがある場合は先へ進まない。

### 4. リリース準備をcommitして`origin/main`へpushする

```sh
git status --short
git add Configurations/ClipApp.xcconfig
git diff --cached
git diff --cached --check
git commit -m "Prepare ClipApp 1.4.1 release"
git push origin main
```

機能変更やリリースノートも同じrelease commitへ含める場合は、対象パスを明示的に
stageする。`git add .`で意図しないファイルを含めない。

この`main` pushでは通常CIだけが動き、アプリはまだ公開されない。

### 5. `origin/main`とrelease commitが一致することを確認する

```sh
git fetch origin main
git status --short --branch
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)"
```

worktreeがcleanで、ローカル`HEAD`と`origin/main`が一致してからタグを作る。

### 6. annotated version tagをpushする

```sh
version=1.4.1
git tag -a "v$version" -m "Release ClipApp $version"
git push origin "v$version"
```

このtag pushがRelease workflowの開始操作である。タグは
`origin/main`上のrelease commitを指していなければならない。

### 7. Validate jobを確認する

GitHubで次を開く。

```text
Actions > Release > 対象のv1.4.1 run
```

`Validate release` jobはSecretsを使う前に次を確認する。

- タグが`v<major>.<minor>.<patch>`形式である。
- タグ、`MARKETING_VERSION`、`CURRENT_PROJECT_VERSION`が一致する。
- release commitが`origin/main`上にある。
- タグ内、現在の`main`、公開中のappcastより新しいversionである。
- 全テストが成功する。

ここで失敗した場合、署名Secretsはrunnerへ渡らず、Releaseも公開されない。

### 8. `release` Environmentを承認する

Validate成功後、署名jobは`Waiting`状態になる。

```text
Review deployments > release > Approve and deploy
```

承認前に次を確認する。

- 対象repositoryが`abehuman/clipapp`である。
- タグとversionが意図したものか。
- タグが指すcommitが確認済みrelease commitか。
- Release workflow自体に未確認の変更がないか。

承認すると、Secretsを使った署名、AppleへのNotarization送信、GitHub Releaseの
一般公開まで自動で進む。

### 9. 4つのjobが完了するまで待つ

1. **Validate release**: version、main、公開appcast、テストを検証する。
2. **Sign, notarize, and publish**: 一時Keychainへ証明書を読み込み、署名、
   Notarization、staple、ZIP、Sparkle署名、Draft検証、Release公開を行う。
   2種類のZIPは作成直後とDraftから再取得した後の両方で展開され、arm64 / x86_64
   署名、stapled ticket、Gatekeeper判定、versionが検証される。
3. **Publish Sparkle feed**: 署名済みappcastをGitHub Pagesへdeployする。
4. **Record published appcast**: 公開済みappcastを`main`へbot commitする。

workflowは公開済みRelease assetsを上書きしない。GitHub-hosted runner上の
`.p12`、`.p8`、Sparkle秘密鍵、一時Keychainはjob終了時に削除され、runner自体も
破棄される。

### 10. GitHub上の公開結果を確認する

Releaseに最低限、次が存在することを確認する。

```text
ClipApp-1.4.1-distribution.zip
ClipApp-1.4.1-distribution.zip.sha256
ClipApp-1.4.1.zip
ClipApp-1.4.1.zip.sha256
```

`.delta`が生成された場合は、その`.delta`と`.sha256`も存在することを確認する。

```sh
gh release view v1.4.1 --repo abehuman/clipapp
curl --fail --location \
  https://abehuman.github.io/clipapp/appcast.xml \
  --output /tmp/clipapp-appcast-1.4.1.xml
xmllint --noout /tmp/clipapp-appcast-1.4.1.xml
```

さらに`main`へ次の形式のbot commitが追加されていることを確認する。

```text
Publish ClipApp 1.4.1 update feed
```

## 公開後のMac実機確認

### 1. ブラウザから配布ZIPをダウンロードする

GitHub Releaseページをブラウザで開き、
`ClipApp-<version>-distribution.zip`をダウンロードする。ブラウザ経由にすることで
macOSのquarantine属性を含む、実ユーザーに近い状態を確認できる。

ZIPを展開し、`ClipApp.app`を`/Applications`へ移動して通常どおり開く。

### 2. 署名、Notarization、CPU architectureを確認する

```sh
app_path=/Applications/ClipApp.app
codesign --verify --deep --strict --all-architectures --verbose=4 "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"
lipo -archs "$app_path/Contents/MacOS/ClipApp"
```

- `codesign`が成功する。
- `stapler validate`が成功する。
- Gatekeeper assessmentが`Notarized Developer ID`としてacceptedになる。
- `lipo`が`arm64`と`x86_64`を含む。
- `ClipApp.app/Contents/Frameworks/Sparkle.framework`が存在する。

### 3. ClipAppの主要機能を確認する

- 設定でコピー音をONにし、`Command+C`で音が鳴る。
- コピー音をOFFにし、`Command+C`で音が鳴らない。
- `Command+Shift+V`で最初の選択可能項目が選択済みになる。
- 続けてReturnだけで貼り付けできる。
- ChromeまたはEdgeのaddress barで確認する。
- GitHub repository searchで確認する。
- Codex promptで確認する。
- GitHub **Go to file**で確認する。
- Login Item登録と、sign outまたは再起動後の起動を確認する。
- Accessibility permissionの付与と貼り付けを確認する。

### 4. Sparkleによる旧版からの更新を確認する

現在公開中の1つ前のバージョンをインストールしたMacで
**Check for Updates…**を実行する。

- 新versionが表示される。
- signature errorが出ない。
- downloadとinstallが完了する。
- ClipAppが再起動する。
- 再起動後のversionが新versionになっている。
- 更新後の署名とNotarizationが有効である。
- 既存設定、履歴、Accessibility behaviorが維持される。

例として最初の自動リリースが`1.4.1`なら、`1.4.0 → 1.4.1`を確認する。

## 失敗時の対応

| 失敗地点 | 公開状態 | 対応 |
| --- | --- | --- |
| Validateで失敗 | Secrets未使用、Releaseなし | version、main、テスト、appcastを修正する。code変更が必要なら新しいversionとtagを使う |
| 署名またはNotarizationで失敗 | Releaseなし | notary logと証明書/API Keyを確認する。公開しない |
| Draft asset検証で失敗 | Draftのみ | 原因が一時的なら`Re-run failed jobs`。code変更が必要なら新versionを作る |
| Release公開後にPagesが失敗 | Releaseは公開済み、旧appcastのまま | **Re-run failed jobs**だけを実行する |
| Pages成功後にappcast commitが失敗 | live appcastは新しいがmain未記録 | **Re-run failed jobs**だけを実行する |
| 公開後にアプリ不具合を発見 | Releaseとappcastは公開済み | assetを差し替えず、versionを上げて新しいReleaseを作る |

公開済みReleaseが存在するときに**Re-run all jobs**を実行すると、workflowは
公開済みassetsの置き換えを拒否して意図的に失敗する。後段だけが失敗した場合は
必ず**Re-run failed jobs**を使う。

push済みtagのcodeを修正する必要がある場合、tagを移動して再利用しない。次の
patch versionを作る。

## 認証情報の更新

### Developer ID証明書

証明書の期限切れ、revoke、交換時は新しい`.p12`を作り、次を更新する。

- `APPLE_DEVELOPER_ID_P12_BASE64`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`

有効期限内で秘密鍵も残っている既存のDeveloper ID Application証明書は、そのまま
使ってよい。理由なく新しい証明書へ切り替えない。

証明書を交換するときは、既存Secretsを更新する前に同じMac上で署名・Notarization
済みのRelease buildを作成し、`scripts/create-update-archive.sh`でZIP化した後、
次を通す。

```sh
scripts/verify-release-archive.sh \
  /path/to/ClipApp-<version>.zip \
  <version> \
  update
```

さらに、別のMacまたはクリーンな利用者環境でも展開後のappを確認する。新しい
証明書での配布物が確認できるまで、既知の正常な旧証明書をrevokeしない。

### App Store Connect Team API Key

鍵を失った、漏えいした、またはローテーションする場合は新しいTeam API Keyを
作り、次を更新する。

- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`

新しい鍵でNotarizationが成功したことを確認してから古い鍵をrevokeする。漏えい
が疑われる場合は確認を待たず、古い鍵を直ちにrevokeする。

### Sparkle秘密鍵

Sparkle秘密鍵は既存インストールが信頼する公開鍵と対になっている。通常のRelease
ごとに変更しない。失った場合や漏えいした場合は、Sparkleのkey rotation手順を
別途計画し、単純に新しい鍵へ差し替えない。

### GitHubのbranch protection

`Record published appcast` jobは`GITHUB_TOKEN`で`main`へcommitをpushする。
後から`main`へbranch protectionやrulesetを追加する場合は、workflowによる
appcast pushが許可されるか確認する。許可されない場合、ReleaseとPagesは成功しても
appcast記録jobだけが失敗する。

## 手動リリースへの復旧

GitHub Actionsが長時間利用できない場合のみ、次の手動手順を使う。自動workflowと
手動workflowを同じversionで並行実行しない。

### 1. ローカル署名設定

```sh
cp Configurations/CodeSigning-Local.xcconfig.example \
  Configurations/CodeSigning-Local.xcconfig
```

ローカルファイルへ正しいTeam IDを設定する。このファイル、証明書、秘密鍵は
commitしない。

### 2. XcodeでArchiveとNotarization

1. `ClipApp` schemeと`Any Mac`を選ぶ。
2. **Product > Archive**を実行する。
3. **Window > Organizer**を開く。
4. **Distribute App > Developer ID > Upload**を選ぶ。
5. Apple NotarizationがAcceptedになるまで待ち、notary logを確認する。
6. Notarization済みappをexportする。送信前のappを配布しない。

### 3. 配布ZIPとSparkle ZIPを作成する

```sh
version=1.4.1
app_path=/path/to/notarized/ClipApp.app
distribution_dir=/path/to/release/distribution
updates_dir=/path/to/release/sparkle-archives

scripts/create-release-archive.sh \
  "$app_path" "$version" "$distribution_dir"
scripts/create-update-archive.sh \
  "$app_path" "$version" "$updates_dir"

scripts/verify-release-archive.sh \
  "$distribution_dir/ClipApp-$version-distribution.zip" \
  "$version" \
  distribution
scripts/verify-release-archive.sh \
  "$updates_dir/ClipApp-$version.zip" \
  "$version" \
  update
```

`distribution_dir`にはライセンス同梱の手動配布ZIP、`updates_dir`にはSparkle用の
app-only ZIPを置く。`*-distribution.zip`をSparkle archives directoryへ入れない。
検証スクリプトはZIPを実際に展開し、両アーキテクチャのDeveloper ID署名、stapled
ticket、Gatekeeper判定、versionを確認する。

### 4. 署名済みappcastを生成する

```sh
scripts/generate-appcast.sh "$updates_dir" "$version"
```

必要に応じて古い`ClipApp-<version>.zip`も`updates_dir`へ置き、deltaを生成する。
`docs/appcast.xml`や署名済みrelease notesを手編集せず、変更後はgeneratorを
再実行する。

### 5. 公開順序を守る

1. Draft GitHub Releaseを作る。
2. 2種類のZIP、SHA-256、deltaとそのSHA-256を添付する。
3. Draft assetsをダウンロードして検証する。
4. GitHub Releaseを公開する。
5. Release assetsのURLが取得できることを確認する。
6. `docs/appcast.xml`をcommitし、`origin/main`へpushする。
7. GitHub Pagesのlive appcastとRelease URLを確認する。
8. 旧版からSparkle updateを実行する。

## 公式参考資料

- [Apple: Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Apple: Share signing certificates with another Mac](https://developer.apple.com/documentation/xcode/sharing-your-teams-signing-certificates)
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Packaging Mac software for distribution](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution)
- [Apple: Customizing the notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Apple: App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)
- [GitHub: Deployments and environments](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)
- [GitHub: Using secrets in GitHub Actions](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- [GitHub: Installing an Apple certificate on macOS runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [GitHub: Using custom workflows with GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Sparkle documentation](https://sparkle-project.org/documentation/)
- [Sparkle: Publishing an update](https://sparkle-project.org/documentation/publishing/)
