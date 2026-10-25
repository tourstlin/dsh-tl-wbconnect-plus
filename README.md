# dsh-tl-wbconnect-plus

`dsh-connect-workbuddy` **5.3.0-wb1** —— 个人本地补丁构建（patched build），供自用与同事安装。

> **这不是原创项目。** 上游是 [dingminhua/dsh-connect-workbuddy](https://github.com/dingminhua/dsh-connect-workbuddy)
> 5.3.0，MIT 协议，© 2026 LaoDing。本仓库只是在其已发布的构建产物上打了 6 处本地补丁后重新打包，
> 版权归原作者所有，原 `LICENSE` 全文保留在仓库根目录与 `payload/dsh-connect-workbuddy/LICENSE`。

## 这是什么

一个 DeepSeek Harness（DSH，Electron 应用）的插件，把本机已登录的 WorkBuddy 账号接入 DSH 作为模型
提供方。**不是** WorkBuddy 桌面端插件。上游功能包括：按上游目录读取各模型积分倍率、逐模型图片输入
开关、多账号切换与账号池自动换号、每日签到、卡片与输入框胶囊积分读数。

## 相对上游 5.3.0 的差异

6 处补丁，全部直接改在**编译产物**上（`lib/index.js` 458,845 B，`lib/client.js` 531,455 B），
没有 TypeScript 源码——上游发布包只带构建输出：

| # | 补丁 | 文件 |
|---|---|---|
| 1 | 模型标签去掉积分倍率后缀 | `lib/index.js` |
| 2 | `deepseek-v4.1-flash` 加 `1017` 小角标 | `lib/client.js` |
| 3 | 输入框积分区一键每日签到 | `lib/index.js` + `lib/client.js` |
| 4 | 选中账号的 100 积分进度条 | `lib/index.js` + `lib/client.js` |
| 5 | 进度条满 100 时自动换号交接 | `lib/index.js` + `lib/client.js` |
| 6 | 全局区域也显示签到按钮 | `lib/client.js` |

每处补丁的定位锚点、改动前后代码和校验方法见 [`PATCHES.md`](PATCHES.md)。

## 安装

- 给 AI 代理看的： [`INSTALL-FOR-AI.md`](INSTALL-FOR-AI.md)
- 给人看的： [`README-同事必读.md`](README-同事必读.md)

离线安装，不需要 git / npm / pnpm / 网络。平台 Windows 10/11，PowerShell 5.1 或 7+，Node 22.19+ 或 24+。

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\verify.ps1     # 校验 6 处补丁是否都在
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1  # 回滚
```

## 说明

- 本仓库为个人维护的二次分发，不保证跟随上游更新；上游发布新版后需按 `PATCHES.md` 记录的锚点重新 rebase。
- 补丁涉及积分额度与账号池逻辑，属于本机自用改造，请自行确认符合所使用服务的使用条款。
- 安装脚本会写入 DSH 的插件目录并修改其配置，运行前请先备份。

## License

MIT，© 2026 LaoDing。见 [`LICENSE`](LICENSE) 与 [`payload/dsh-connect-workbuddy/THIRD_PARTY_NOTICES.md`](payload/dsh-connect-workbuddy/THIRD_PARTY_NOTICES.md)。
