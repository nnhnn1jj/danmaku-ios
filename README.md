# 弹幕助手 iOS 版（MVP）

iPhone 上播放本地视频、叠一层实时弹幕。

## 能做什么

- 从「文件」App 导入视频（会复制进 App 自己的目录，之后直接播）
- AVPlayer 播放，支持拖动进度、±10 秒
- 弹幕浮层：滚动 / 顶部 / 底部三种模式，字号、透明度、速度、行数、强制白色都能调
- 弹幕来源：
  - **B站**：贴 BV 号或视频链接，自动查 cid 拉 `comment.bilibili.com/{cid}.xml`
  - **弹弹play**：按视频文件名自动匹配（需在设置里填自己的 AppId / AppSecret）

## 不能做什么

- iOS 不允许 App 在别的播放器上画浮层，所以只能播 App 内的视频，挂不了 Infuse / nPlayer
- 爱奇艺 / 腾讯 / 优酷那几个源没做（接口要签名 + 风控，工作量太大）
- 本地 ASS/SRT 弹幕导入没做

## 编译成 IPA（不需要 Mac）

iOS 的 ipa 只能在 macOS 上编，这里借 GitHub 的免费 macOS 机器：

1. 在 GitHub 新建一个仓库（public，Actions 免费）
2. 把这个文件夹里**所有文件**传上去（网页拖拽即可，注意包含 `.github` 文件夹）
3. 仓库页 → **Actions** → 左边选 `build-ipa` → **Run workflow**
4. 等 5～10 分钟，进这次运行，最下面 **Artifacts** 下载 `DanmakuIOS-ipa`，解压得 `DanmakuIOS.ipa`

> 产物是**未签名**的 ipa，直接装不了，要自己签。

## 装到 iPhone

用 **Sideloadly**（Windows 直接装）或 **AltStore / SideStore**（手机上）：

1. 装上签名工具，登录你的 Apple ID（免费账号即可）
2. 把 `DanmakuIOS.ipa` 丢进去签名安装
3. 免费 Apple ID 签的 App 有效期 **7 天**，到期重签一次；最多同时签 3 个 App

首次打开若提示「不受信任的开发者」，去 设置 → 通用 → VPN与设备管理 里信任一下。

## 用法

1. 点左上角空白处的导入按钮选视频（首次会问文件权限）
2. 点 🔍 找弹幕：
   - 贴 `BV1xx411c7mD` 这种 BV 号 → 载入
   - 或在设置里填好弹弹play 的 AppId/AppSecret，直接「按文件名匹配」
3. 弹幕自动跟着时间轴滚；工具栏可以关弹幕、清空、调样式

## 目录结构

```
project.yml                  XcodeGen 工程描述（CI 里生成 .xcodeproj）
Sources/                     全部 Swift 源码
.github/workflows/build-ipa.yml   GitHub Actions：编出未签名 ipa
```

## 已知限制

- 弹幕多的时候 Canvas 每帧重绘，低端机可能掉帧
- B站接口偶发 412 风控，等一会儿再试
- 弹弹play 匹配靠文件名，文件名太乱就匹配不准，可以手动改成规范名字
