# Win Finder

一款让你有家的感觉的 macOS 文件管理器 — 专为从 Windows 转来的用户打造。

🇬🇧 [English](README.md) &nbsp; 🇮🇹 [Italiano](README.it.md) &nbsp; 🇩🇪 [Deutsch](README.de.md) &nbsp; 🇪🇸 [Español](README.es.md) &nbsp; 🇨🇳 中文 &nbsp; [🇲🇬 Malagasy ❤️](README.mg.md)

![Win Finder screenshot](docs/screenshot.png)

## 为什么选择 Win Finder？

macOS 是一个优秀的操作系统。但如果你在 Windows 上工作了多年，Finder 会让你感到不对劲，这种感觉难以言表：没有可编辑的路径栏，没有内联搜索，右键没有"新建文件"，Delete 键不删除文件。这些小问题累积起来造成持续的摩擦。

Win Finder 解决了这些问题。它是一款原生 macOS 文件管理器，围绕 Windows 用户已经熟悉的工作流程构建。

## 功能特性

- **可编辑路径栏** — 始终可见，占工具栏宽度的 80%。点击它，输入路径，按回车。与 Windows 资源管理器完全相同。
- **面包屑导航** — 路径栏将每个文件夹显示为可点击的标记。点击任意段落导航到该位置。点击 `>` 分隔符查看该层级的子文件夹。点击右侧空白区域切换到可编辑文本模式。
- **内联搜索** — 搜索框始终显示在路径栏旁边。默认递归搜索所有子文件夹。支持通配符（`*.pdf`、`doc*`）。结果显示相对路径。
- **侧边栏** — 收藏夹（桌面、文档、下载、图片）、位置、设备和最近路径 — 跨会话保存。
- **Windows 资源管理器风格列表** — 名称、修改日期、大小列，点击标题排序。文件夹始终置顶。
- **彩色文件图标** — 来自 [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors) Vivid 套装的 404 个文件类型图标。PDF 是红色，ZIP 是紫色，Swift 文件是橙色。
- **右键上下文菜单** — 打开、打开方式、复制、剪切、粘贴、重命名、压缩为 ZIP、新建文件夹、新建文件、AirDrop、删除。
- **键盘快捷键** — `Delete` 移至废纸篓，`Shift+Delete` 永久删除（需确认），`Cmd+C` / `Cmd+V` 复制粘贴文件。
- **按键选择** — 按字母键跳转到以该字母开头的第一个文件。再次按键循环匹配项。
- **拖放** — 在两个 Win Finder 窗口之间，以及与侧边栏之间。拖动时按住 `Cmd` 为复制而非移动。
- **多选** — `Shift+点击` 范围选择，`Cmd+点击` 切换单个项目。
- **AirDrop** 右键菜单 — 无需打开 Finder 直接共享文件。
- **实时文件系统监控** — 磁盘上文件变化时列表自动更新。
- **扩展系统** — 通过 JSON 文件向右键菜单添加自定义操作。支持嵌套子菜单、分隔符、自定义图标和上下文过滤。通过 **Win Finder → 管理扩展** 管理一切。
- **多语言** — 支持英语 🇬🇧、意大利语 🇮🇹、德语 🇩🇪、西班牙语 🇪🇸、简体中文 🇨🇳 和马达加斯加语 🇲🇬 ❤️。界面语言自动跟随系统语言。

## 扩展系统

任何应用程序都可以通过在 `~/.config/winfinder/actions/` 中创建包含 `action.json` 文件和可选 `icon.png` 的文件夹来与 Win Finder 集成。

**字段说明：**
- `name` — 菜单中显示的标签
- `extensions` — 要匹配的文件扩展名，或 `["*"]` 匹配所有文件
- `context` — 操作出现的位置：`"file"`、`"folder"`、`"background"`
- `command` — 要运行的 shell 命令，`{file}` 替换为选中文件路径
- `submenu` — 嵌套项目数组
- `icon` — PNG 图标文件的可选路径
- `separator` — 设为 `true` 作为菜单分隔线

## 安装

### 系统要求
- macOS 13 Ventura 或更高版本
- Apple Silicon 或 Intel Mac

### 从源码构建

```bash
git clone https://github.com/Skimmenthal13/winfinder.git
cd winfinder
open winfinder.xcodeproj
```

然后在 Xcode 中按 `Cmd+R` 构建并运行。

## 贡献

Win Finder 是开源项目，欢迎贡献。如果你从 Windows 切换过来，发现有什么不对劲，请开一个 issue。

1. Fork 仓库
2. 创建分支（`git checkout -b feature/你的功能`）
3. 提交更改
4. 开启 Pull Request

## 致谢

文件类型图标来自 [@dmhendricks](https://github.com/dmhendricks) 的 [file-icon-vectors](https://github.com/dmhendricks/file-icon-vectors) — 一个包含 400+ SVG 图标的精彩集合，CC BY-SA 4.0 许可证。感谢将其提供给社区。

## 许可证

MIT — 随便用。

---

由 [@Skimmenthal13](https://github.com/Skimmenthal13) 构建 — 一个厌倦了与 Finder 抗争的 Windows 难民。

> 🤖 整个项目使用 [Claude Code](https://claude.ai/code) 进行 **vibe coding** 构建 — 从第一行 Swift 代码到扩展系统、面包屑导航和文件图标。无需羞耻，只有骄傲。

## 法律信息
- [隐私政策](https://skimmenthal13.github.io/winfinder/privacy-policy.html)
- [服务条款](https://skimmenthal13.github.io/winfinder/terms-of-service.html)