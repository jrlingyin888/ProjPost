# JJPost GitHub Releases 更新流程

这份文档说明如何发布 JJPost 新版本，以及如何验证 App 内的“检查更新”提示。

## 当前更新逻辑

JJPost 使用 GitHub Releases 做方案 A 更新：

1. App 启动后请求 `https://api.github.com/repos/jrlingyin888/ProjPost/releases/latest`。
2. App 用代码里的 `ProductBranding.appVersion` 和 GitHub 最新 tag 比较，例如 `1.1.0` 和 `v1.2.0`。
3. 如果 GitHub 最新版本更高，App 弹出更新提示。
4. 用户点击 `Download Update / 下载更新` 后，App 打开 GitHub Release 页面。
5. 用户手动下载 zip、解压并替换旧的 `JJPost.app`。

注意：这个版本不会自动下载、解压、替换或重启 App。

## 重要限制

- GitHub Releases 页面一定会显示 `Source code (zip)` 和 `Source code (tar.gz)`，这是 GitHub 自动生成的，不能隐藏或删除。
- 给用户下载时，应明确让用户下载 Assets 里的 `JJPost-<version>-dev-id.zip`。
- 现在 GitHub 上已有的 `v1.0.0` 包没有内置检查更新代码，所以打开它不会弹更新提示。
- 要测试更新提示，需要使用“包含 updater 代码但版本号低于 latest release”的测试包。

## 发布正式版本

以下示例以 `v1.1.0` 为例。

正式发布前，建议先通过 PR 或本地 merge 把功能分支合并到 `main`，再从 `main` 打包和创建 Release。

### 1. 确认版本号

确认代码版本：

```bash
rg -n 'appVersion' Sources/ProjPostCore/Branding/ProductBranding.swift
```

应看到：

```swift
public static let appVersion = "1.1.0"
```

### 2. 跑测试

```bash
swift test
```

要求：所有测试通过。

### 3. 打包 App

```bash
APP_VERSION=1.1.0 scripts/package_app.sh
```

产物：

```text
dist/JJPost.app
```

### 4. 校验签名

```bash
codesign --verify --deep --strict --verbose=2 dist/JJPost.app
```

要求输出类似：

```text
dist/JJPost.app: valid on disk
dist/JJPost.app: satisfies its Designated Requirement
```

当前未做 Apple 公证，所以这条通常会显示未公证，这是预期：

```bash
spctl --assess --type execute --verbose=2 dist/JJPost.app
```

常见结果：

```text
dist/JJPost.app: rejected
source=Unnotarized Developer ID
```

### 5. 生成 Release zip

先确认 `dist/JJPost.app` 是刚打包的版本，再生成 zip：

```bash
APP_VERSION=1.1.0 BUILD_IF_MISSING=0 scripts/release_zip.sh
```

产物：

```text
dist/JJPost-1.1.0-dev-id.zip
```

### 6. 创建 GitHub Release

如果 `v1.1.0` 还不存在：

```bash
gh release create v1.1.0 dist/JJPost-1.1.0-dev-id.zip \
  --repo jrlingyin888/ProjPost \
  --target main \
  --title "JJPost v1.1.0" \
  --notes "JJPost v1.1.0 release."
```

如果 `v1.1.0` 已经存在，需要重新上传 zip：

```bash
gh release upload v1.1.0 dist/JJPost-1.1.0-dev-id.zip \
  --repo jrlingyin888/ProjPost \
  --clobber
```

### 7. 确认 latest release

```bash
gh release list --repo jrlingyin888/ProjPost --limit 5
```

确认 `v1.1.0` 显示为 `Latest`。

## 用户安装更新

当用户看到 App 内更新提示后：

1. 点击 `Download Update / 下载更新`。
2. 在 GitHub Release 页面下载 `JJPost-<version>-dev-id.zip`。
3. 退出正在运行的 JJPost。
4. 解压 zip，得到新的 `JJPost.app`。
5. 把新的 `JJPost.app` 拖到原来的安装位置，通常是 `/Applications`。
6. macOS 提示是否替换时，选择替换。
7. 重新打开 JJPost。

如果 macOS 提示无法打开未公证 App：

1. 打开 `System Settings > Privacy & Security`。
2. 在安全提示区域点击 `Open Anyway / 仍要打开`。
3. 再次打开 JJPost。

## 本地测试更新提示

因为 GitHub 上的 `v1.0.0` 包没有 updater，不能用它测试更新弹窗。测试时需要临时做一个“低版本但包含 updater”的本地测试包。

以下示例假设 GitHub latest release 已经是 `v1.1.0`。

### 1. 新建临时测试分支

```bash
git switch -c codex/update-popup-local-test
```

### 2. 临时降低代码版本号

打开：

```text
Sources/ProjPostCore/Branding/ProductBranding.swift
```

把：

```swift
public static let appVersion = "1.1.0"
```

临时改成：

```swift
public static let appVersion = "1.0.1"
```

注意：这只是本地测试，不要提交这个改动。

### 3. 打测试包

```bash
APP_VERSION=1.0.1 scripts/package_app.sh
```

### 4. 启动测试包

```bash
open dist/JJPost.app
```

预期结果：

- App 启动后请求 GitHub latest release。
- 如果 latest 是 `v1.1.0`，会弹出更新提示。
- 点击 `Download Update / 下载更新` 会打开 GitHub `v1.1.0` Release 页面。

### 5. 清理临时测试改动

测试完成后，不要提交临时版本号。恢复文件：

```bash
git restore Sources/ProjPostCore/Branding/ProductBranding.swift
```

回到原来的功能分支：

```bash
git switch codex/jjpost-multilingual
```

删除临时测试分支：

```bash
git branch -D codex/update-popup-local-test
```

## 下次版本的正常验证方式

从 `v1.1.0` 开始，用户手上的 App 已经内置 updater。以后发布 `v1.2.0` 时：

1. 用户打开 `v1.1.0`。
2. App 检测 GitHub latest 是 `v1.2.0`。
3. App 弹出更新提示。
4. 用户打开 GitHub Release 页面并手动下载安装。

这时就不需要再做“低版本测试包”的临时操作。
