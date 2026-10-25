# 同事必读 —— WorkBuddy 插件安装包（5.3.0-wb1）

> 这个包里是什么、怎么装、装坏了怎么退，全在这份文件里。
> 如果你是把这个包丢给 AI 让它装，**把 `INSTALL-FOR-AI.md` 给它**，那份是写给 AI 看的。

---

## 一句话说明

这是 **DeepSeek Harness（DSH）** 的一个插件，叫 `dsh-connect-workbuddy`。
它把你电脑上已经登录的 WorkBuddy 账号接进 DSH，当作模型来源使用。

**注意：DSH ≠ WorkBuddy。** 这个插件装在 DSH 里，不是装在 WorkBuddy 桌面端里。

这个包基于官方 5.3.0 版本，额外加了 6 个改动（下面有清单）。
官方原版是 MIT 许可，作者 LaoDing，原仓库
`https://github.com/dingminhua/dsh-connect-workbuddy`。

---

## 你需要先有的东西

| 要求 | 说明 |
|---|---|
| Windows 10 / 11 | 只支持 Windows |
| DeepSeek Harness 已装好 | 并且**至少启动过一次**（要它自己生成配置目录） |
| WorkBuddy 已登录 | 插件复用你 WorkBuddy 的登录状态，不需要另外注册 |

**不需要**：git、npm、pnpm、联网下载。包里东西是全的。

---

## 怎么装（三种方式，选一种）

### 方式一：让 AI 装（最省事，推荐）

1. 把整个压缩包**解压**到一个文件夹（不要直接在压缩包里点）。
2. 打开解压后的文件夹，把 `INSTALL-FOR-AI.md` 丢给你的 AI 助手，说：
   > 按这个文件把插件装好
3. AI 会自己检查环境、执行安装、跑校验。装完它会告诉你结果。
4. **你只需要做一件事：把 DeepSeek Harness 完全退出再重新打开**（托盘图标也要退）。

### 方式二：自己跑脚本

解压后，在那个文件夹里按住 `Shift` + 右键 →「在此处打开 PowerShell 窗口」，然后：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

看到 `[wb-install] all patch markers present` 和 `DONE` 就是成功了。

然后验证一下（只读，不改任何东西）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1
```

要看到 `[wb-verify] RESULT: OK`。

最后**完全退出 DSH 再打开**。

### 方式三：手动复制（不推荐，除非脚本被拦）

脚本可能被公司的杀毒/策略拦。那就手动来：

1. 找到你的 DSH 配置目录。一般是 `C:\Users\<你的用户名>\.dsh`，
   也可能是别的盘（这个目录有可能是个快捷链接，右键看「目标」）。
2. 进到 `profiles\desktop\`。
3. 把包里 `payload\dsh-connect-workbuddy\` 整个文件夹，复制到
   `profiles\desktop\node_modules\dsh-connect-workbuddy\`
   （如果原来就有这个文件夹，**先把它改名备份**，别直接覆盖）。
4. 打开 `profiles\desktop\package.json`，在 `"dependencies"` 里加一行：
   ```json
   "dsh-connect-workbuddy": "file:vendor/dsh-connect-workbuddy"
   ```
   并把 `payload` 那份也复制到 `profiles\desktop\vendor\dsh-connect-workbuddy\`。
5. 在 `"dsh": { "profile": { "bundles": [ ... ] } }` 数组里加一项
   `"dsh-connect-workbuddy"`。
6. 把包里 `deps\` 下的三个文件夹复制到 `profiles\desktop\node_modules\` 下
   （**如果已经有同名的就别覆盖**）：
   - `@deepseek-ai\schemastery`
   - `@deepseek-ai\cosmokit`
   - `@standard-schema\spec`

改 JSON 的时候注意逗号别弄错。改完重启 DSH。

---

## 装完怎么确认成功

重启 DSH 后，按顺序看这三件事：

1. **设置 → 插件管理**：列表里应该有 `DSH Connect WorkBuddy`。
2. **模型选择器**：能看到 WorkBuddy 的模型。`DeepSeek-V4.1-Flash` 这个条目后面
   有一个小小的 **1017** 蓝色标签，而且**没有** `· x0.11` 这种倍率后缀。
3. **输入框右下角的积分小标签**：点开，面板里应该有一个**进度条**显示
   「已用 x / 100」，还有一个**一键签到**按钮。

三条都满足 = 装好了。

---

## 这 6 个改动是什么

| # | 改动 | 你能看到的效果 |
|---|---|---|
| 1 | 去掉积分倍率后缀 | 模型名后面不再显示 `· x0.11` |
| 2 | 加 `1017` 小标签 | 模型名后面有个淡蓝色小圆角标签写着 1017 |
| 3 | 一键签到 | 积分面板里多一个「一键签到」按钮，一次签完所有账号 |
| 4 | 100 积分进度条 | 面板顶部显示当前账号「已用 x / 100」 |
| 5 | 满 100 自动切换 | 当前账号用满 100 积分，自动换到另一个账号，计数器归零 |
| 6 | 国际版也显示签到按钮 | 国际版账号也能看到按钮（见下方说明） |

### 关于第 6 条，有个必须说清的事

**国际版服务端目前没有签到活动。** 这不是插件的问题，我实测过上游接口：

```
POST workbuddy.ai /v2/billing/meter/checkin-activity-status
→ {"active":false, "start_time":"", "theme_name":"", "season":0}

POST workbuddy.ai /v2/billing/meter/daily-checkin
→ {"code":10001, "msg":"签到活动未开启或已过期"}
```

对比国内版同一天：`{"active":true, "season":10, "theme_name":"Buddy加油站"}`。

所以国际版点签到按钮会提示「本区当前没有签到活动（国际版暂未开放）」，
而不是像原版那样**按钮直接消失**。等腾讯哪天在国际版开了这个活动，
按钮就自动能用了，不用再改代码。

---

## 出问题了怎么办

### 装完 DSH 打不开 / 插件报错
先跑 `uninstall.ps1` 退回去：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

它会恢复你原来的插件、清掉新增的配置项。然后重启 DSH。

### 想手动恢复配置
安装脚本每次都会备份 `package.json`，文件名是
`package.json.bak-wb-<时间戳>`。把它复制回 `package.json` 覆盖即可。

原来的插件目录也会被改名成
`node_modules\dsh-connect-workbuddy.bak-wb-<时间戳>`，改名回去就行。

### 插件列表里看不到
说明配置没生效。检查 `package.json` 里这两处都提到了
`dsh-connect-workbuddy`：

- `dependencies` 里有一行
- `dsh.profile.bundles` 数组里有一项

两处都要有。

### 提示找不到某个包
`deps\` 里的三个依赖没复制过去。重新跑一次 `install.ps1`
（已经存在的依赖它会跳过，不会覆盖），或者按方式三第 6 步手动复制。

---

## 以后更新插件会怎样

**你的改动不会丢。** 因为安装脚本在 `package.json` 里写的是：

```json
"dsh-connect-workbuddy": "file:vendor/dsh-connect-workbuddy"
```

`file:` 前缀的意思是「从这个本地路径装」。所以以后就算你跑
`pnpm install` 或 `pnpm update`，它也是重新链接这个**改过的**副本，
不会从 npm 拉一个原版把改动冲掉。

代价是：**官方以后发新版，你不会自动拿到**。想要新版的话，
得重新走一遍补丁流程（`PATCHES.md` 里记了每一处改在哪）。

---

## 文件清单

```
INSTALL-FOR-AI.md          给 AI 看的安装手册（含排错决策树）
README-同事必读.md          本文件
PATCHES.md                 6 个改动的技术细节 + 以后怎么重新打补丁
install.ps1                安装脚本
uninstall.ps1              卸载/回滚脚本
verify.ps1                 只读校验脚本
payload/dsh-connect-workbuddy/   插件本体
deps/                      三个运行时依赖（仅缺的时候才装）
```

---

## 许可

MIT License，Copyright (c) 2026 LaoDing。
本包是修改后的再分发，原始 `LICENSE` 与 `THIRD_PARTY_NOTICES.md`
已原样保留在 `payload/dsh-connect-workbuddy/` 内。
6 个改动同样以 MIT 条款提供。
