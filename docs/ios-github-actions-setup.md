# iOS 打包（GitHub Actions）

仓库：[masakibmz/wallet](https://github.com/masakibmz/wallet)

Workflow：`.github/workflows/ios-build.yml`（push 到 `main` 或手动 **Run workflow**）

## 你需要在 GitHub 填的 Secrets

打开 **Settings → Secrets and variables → Actions → New repository secret**：

| Secret | 说明 |
|--------|------|
| `BUILD_CERTIFICATE_BASE64` | Mac 钥匙串导出的 **Apple Development** `.p12` 做 base64 |
| `P12_PASSWORD` | 导出 p12 时设的密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | **iOS App Development** 描述文件 `.mobileprovision` 的 base64 |
| `KEYCHAIN_PASSWORD` | 任意强密码（CI 临时钥匙串用） |
| `APPLE_TEAM_ID` | [开发者 Membership](https://developer.apple.com/account) 里 10 位 Team ID |
| `PROVISIONING_PROFILE_NAME` | 苹果后台该描述文件的 **Name**（不是文件名） |
| `IOS_BUNDLE_ID` | 可选，默认 `com.wallet.wallet`；若改过 Bundle ID 请与此一致 |

### Mac 上生成 base64（终端）

```bash
base64 -i YourCert.p12 | pbcopy
base64 -i YourProfile.mobileprovision | pbcopy
```

### 苹果后台一次性准备

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) 注册 App ID（与工程 Bundle ID 一致）。
2. [Devices](https://developer.apple.com/account/resources/devices/list) 添加 iPhone **UDID**。
3. [Profiles](https://developer.apple.com/account/resources/profiles/list) 新建 **iOS App Development**，勾选 App ID、证书、设备，下载 `.mobileprovision`。
4. 钥匙串导出 **Apple Development** 证书为 `.p12`。

**切勿**把 p12、描述文件提交进 Git。

## 拿 IPA 装手机

1. **Actions** → 最新成功的 **iOS IPA** → **Artifacts** → 下载 `wallet-ipa`。
2. 解压 `.ipa`，用 **SideStore**（或其它侧载方式）安装。
3. **7 天续签**仍靠 SideStore + Mac 上 SideServer（与 Actions 无关）。

## 常见问题

- **签名失败**：检查 `PROVISIONING_PROFILE_NAME` 是否与后台完全一致；Bundle ID、设备是否在描述文件里。
- **仓库是 Public**：个人记账代码建议 **Settings → General → Change visibility → Private**。
