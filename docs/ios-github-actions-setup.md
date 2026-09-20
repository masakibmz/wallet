# iOS 打包（GitHub Actions）

仓库：[masakibmz/wallet](https://github.com/masakibmz/wallet)

| Workflow | 何时跑 | 需要什么 |
|----------|--------|----------|
| **CI** (`ci.yml`) | 每次 push | 无，只 `flutter test` |
| **iOS IPA** (`ios-build.yml`) | **仅手动 Run workflow** | GitHub Secrets 里的签名材料 |

## 免费 Apple ID + 无 Mac

网页会提示 **Access Unavailable**（未加入 $99 计划）→ **不能**填 Secrets，**不要跑 iOS IPA**。  
请用 **Mac + Xcode + Personal Team** 装手机；或付 $99 后再用 Actions。

## 有 $99 或 Mac 导出证书后

下面按 **Windows + 浏览器 + Secrets**（或 Mac 钥匙串导出）在 Actions 里签名出 IPA。

---

## 一、你要准备的东西（清单）

| 序号 | 东西 | 用来干什么 | 怎么获取 |
|------|------|------------|----------|
| ① | **Apple ID** | 登录苹果开发者网站 | 已有 Apple ID 即可 |
| ② | **iPhone UDID** | 允许装到你这台手机 | Windows：**爱思助手 / 3uTools** 连手机查看；或 Settings 里复制设备信息（工具读的最准） |
| ③ | **App ID（Bundle ID）** | 和工程一致 | 网页注册，默认 **`com.wallet.wallet`** |
| ④ | **Apple Development 证书 + 私钥（.p12）** | 签名 | **Windows OpenSSL** 生成 CSR → 网页下载 `.cer` → 合成 `.p12` |
| ⑤ | **Development 描述文件（.mobileprovision）** | 绑定 App + 证书 + 你的手机 | [Profiles](https://developer.apple.com/account/resources/profiles/list) 网页创建并下载 |
| ⑥ | **Team ID（10 位）** | 填 Secret | [Membership Details](https://developer.apple.com/account#MembershipDetailsCard) |
| ⑦ | **描述文件的 Name** | 填 Secret `PROVISIONING_PROFILE_NAME` | 创建 Profile 时你起的名字，或列表里 **Name** 列 |
| ⑧ | **GitHub Secrets（7 个）** | 交给 Actions | 见下文 |
| ⑨ | **代码已 push 到 GitHub** | 触发 workflow | `git push origin main` |

**不需要本地 Mac。** Actions 自带 macOS 编译机；你要做的是在苹果那边「领钥匙」并贴到 GitHub。

---

## 二、Apple 开发者网站（浏览器，Windows）

1. 打开 [developer.apple.com](https://developer.apple.com) → 用 Apple ID 登录。  
   - 免费账号也能做 **Development** 签名（7 天侧载限制在手机上，和 SideStore 一致）。  
   - 若提示加入 **Apple Developer Program（$99/年）**，侧载用免费即可先不付；网页若某功能必须付费再考虑。

2. **Team ID**  
   - [Account → Membership details](https://developer.apple.com/account#MembershipDetailsCard)  
   - 记下 **Team ID**（10 位字母数字）→ 以后填 `APPLE_TEAM_ID`。

3. **注册 App ID**  
   - [Identifiers → +](https://developer.apple.com/account/resources/identifiers/add/bundleId)  
   - 选 **App IDs → App**  
   - Description 随意；**Bundle ID** 选 Explicit，填：`com.wallet.wallet`  
   - 注册。

4. **注册 iPhone**  
   - [Devices → +](https://developer.apple.com/account/resources/devices/add)  
   - 名称随意；**Device ID** 填 ② 里的 **UDID**  
   - 注册。

5. **创建证书（网页只收 CSR，私钥在 Windows 生成）**  
   - 先做 **第三节 OpenSSL** 得到 `CertificateSigningRequest.certSigningRequest`  
   - [Certificates → +](https://developer.apple.com/account/resources/certificates/add)  
   - 选 **Apple Development** → 上传 CSR → 下载 **`development.cer`**（名字可能不同，是 `.cer` 即可）。

6. **创建描述文件**  
   - [Profiles → +](https://developer.apple.com/account/resources/profiles/add)  
   - 选 **iOS App Development**  
   - 选 App ID：`com.wallet.wallet`  
   - 选刚建的 **Apple Development** 证书  
   - 勾选你的 **iPhone**  
   - **Profile Name** 建议填好记且唯一，例如：`wallet dev masakibmz`  
   - 生成 → **Download** → 得到 `.mobileprovision`  
   - **Profile Name 一字不差** → 填 GitHub Secret `PROVISIONING_PROFILE_NAME`。

---

## 三、Windows 上生成 CSR 和 .p12（OpenSSL）

### 安装 OpenSSL

任选其一：

- 安装 [Git for Windows](https://git-scm.com/download/win)，用 **Git Bash** 里的 `openssl`  
- 或：`winget install ShiningLight.OpenSSL`（装好后用 **PowerShell / cmd** 调 openssl）

以下命令在 **Git Bash** 或已加入 PATH 的终端执行。工作目录示例：`D:\ios-signing`（自己建文件夹）。

```bash
mkdir -p ~/ios-signing
cd ~/ios-signing

# 1. 私钥（勿泄露、勿提交 Git）
openssl genrsa -out ios_dev.key 2048

# 2. CSR（上传到苹果）
openssl req -new -key ios_dev.key -out CertificateSigningRequest.certSigningRequest \
  -subj "/emailAddress=你的邮箱@example.com/CN=Your Name/C=CN"

# 3. 苹果下载的 development.cer 放同目录后，合成 p12
openssl x509 -in development.cer -inform DER -out development.pem -outform PEM
openssl pkcs12 -export -out ios_dev.p12 -inkey ios_dev.key -in development.pem \
  -password pass:这里设p12密码
```

- **`这里设p12密码`**：自己定一串 → GitHub Secret **`P12_PASSWORD`**。  
- **`ios_dev.p12`** → 转 base64 填 **`BUILD_CERTIFICATE_BASE64`**。  
- **`ios_dev.key` / p12** 只放本机安全处，**不要** push 到 GitHub。

若 `development.cer` 是 PEM 文本开头 `-----BEGIN CERTIFICATE-----`，把第 3 步改成 `-inform PEM`。

---

## 四、Windows 上转 Base64（填 GitHub）

PowerShell（路径改成你的）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\ios-signing\ios_dev.p12")) | Set-Clipboard
# 已复制 → 粘贴到 Secret BUILD_CERTIFICATE_BASE64

[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\ios-signing\wallet.mobileprovision")) | Set-Clipboard
# 粘贴到 Secret BUILD_PROVISION_PROFILE_BASE64
```

---

## 五、GitHub Secrets（7 个）

仓库 → **Settings → Secrets and variables → Actions → New repository secret**

| Secret | 填什么 |
|--------|--------|
| `BUILD_CERTIFICATE_BASE64` | 第四节 p12 的 base64 |
| `P12_PASSWORD` | 合成 p12 时 `pass:` 后面的密码 |
| `BUILD_PROVISION_PROFILE_BASE64` | `.mobileprovision` 的 base64 |
| `KEYCHAIN_PASSWORD` | **自己随便设**（如 `MyCiKeychain2026!`，仅 CI 用） |
| `APPLE_TEAM_ID` | 第二节 Team ID |
| `PROVISIONING_PROFILE_NAME` | 例如 `wallet dev masakibmz`（与网页 Name 完全一致） |
| `IOS_BUNDLE_ID` | 可选；不填则 workflow 默认 `com.wallet.wallet` |

---

## 六、跑 Actions、装手机

1. 代码 push 到 `main`，或 **Actions → iOS IPA → Run workflow**。  
2. 成功后在 run 页面 **Artifacts** 下载 `wallet-ipa`，解压得 `.ipa`。  
3. **SideStore** 安装；7 天续签需 SideStore + SideServer（与 Actions 无关）。

---

## 七、获取 iPhone UDID（Windows）

1. 安装 [爱思助手](https://www.i4.cn/) 或 3uTools。  
2. USB 连接 iPhone，信任电脑。  
3. 设备信息里复制 **UDID**（40 位左右十六进制）。

---

## 常见问题

- **Actions 报缺少 Secrets**：对照第五节是否 7 个都建了（`IOS_BUNDLE_ID` 可不建）。  
- **签名失败 / provisioning profile doesn't match**：Bundle ID、Profile Name、描述文件是否包含该 UDID、证书是否与 Profile 里选的一致。  
- **免费 Apple ID**：Development 证书/描述文件有效期有限，过期后网页重新生成 p12/profile，更新 Secrets 再跑 workflow。  
- **仓库 Public**：建议改为 Private。
