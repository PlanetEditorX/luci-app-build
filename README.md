# luci-app-build
## 项目介绍
简单的luci应用创建模板，fork项目后将`luci-app-hello`替换为需要的应用进行编译测试。

支持**双包格式**输出：

| 格式 | 适用 OpenWrt 版本 | 包管理器 | SDK | Feed 分支 | 产物命名 |
|---|---|---|---|---|---|
| `.ipk` | 24.10.x 及更早 | opkg | 24.10.2 | `openwrt-24.10` | `luci-app-xxx_1.0-r1_all.ipk` |
| `.apk` | **25.12.x 及更新** | apk (apk-tools v3) | 25.12.5 | `openwrt-25.12` | `luci-app-xxx-1.0-r1.apk` |

- 24.10 SDK：`https://downloads.openwrt.org/releases/24.10.2/targets/mediatek/filogic/openwrt-sdk-24.10.2-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst`
- 25.12 SDK：`https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/filogic/openwrt-sdk-25.12.5-mediatek-filogic_gcc-14.3.0_musl.Linux-x86_64.tar.zst`

## 工作流介绍
1. luci-app-build-v0（`.yml-save`，已停用存档）
- 初始化测试，无需任何文件，直接运行该工作流就会编译生成hello的ipk文件
2. luci-app-build-v1
- 单包编译，会将仓库下的第一个`luci-app-xxx`编译
- 新增 `format` 输入项：选 `apk`（25.12）或 `ipk`（24.10），一次运行编译一种格式
3. luci-app-build-v2
- 多包编译，会将仓库下的所有`luci-app-xxx`编译（`luci-app-hello` 除外）
- 新增 `variant` 输入项：`both`（默认，ipk+apk 全出）/ `ipk` / `apk`
- 矩阵维度 = 包 × 格式，4 个包就 8 个并行 job；Release 里同时挂 ipk 和 apk

## 为什么必须换 SDK（而不是加个开关）
包格式由 SDK 编译时的 `CONFIG_USE_APK` 决定，它作用于**整个工具链**（包格式、产物命名、仓库索引、签名方式）：

| 维度 | ipk（`CONFIG_USE_APK=n`） | apk（`CONFIG_USE_APK=y`） |
|---|---|---|
| 产物后缀 | `.ipk`（ar 归档） | `.apk`（tar 包） |
| 命名分隔符 | 下划线 `_` | 连字符 `-` |
| 仓库索引 | `Packages` / `Packages.gz` | `packages.adb` |
| 设备端数据库 | `/usr/lib/opkg/` | `/lib/apk/db/` |
| 源配置 | `/etc/opkg/distfeeds.conf` | `/etc/apk/repositories.d/distfeeds.list` |
| 安装命令 | `opkg install xxx.ipk` | `apk add --allow-untrusted xxx.apk` |

- 24.10 SDK 只能出 ipk，25.12 SDK 默认 `CONFIG_USE_APK=y` 只能出 apk（已实测 25.12 分支的 `config/Config-build.in` 中 `default y`）。
- 因此工作流是**两条并行的 SDK 分支**，而不是同一 SDK 输出两种格式。

## 设备端安装
```sh
# OpenWrt 24.10 及更早
opkg update && opkg install /tmp/luci-app-xxx_1.0-r1_all.ipk

# OpenWrt 25.12 及更新
apk add --allow-untrusted /tmp/luci-app-xxx-1.0-r1.apk
```

## ⚠️ Lua 应用在 25.12 上的运行时依赖
本项目里的应用（`luci-app-hello` / `luci-app-keepalived-ha` / `luci-app-model-update`）
把页面装在 `/usr/lib/lua/luci/...`，属于 **Lua 版 LuCI 应用**。25.12 中 Lua 运行时已从
`luci-base` 里拆出为独立包，只有装了下面两个包页面才会显示：

```sh
apk add luci-lua-runtime luci-compat
```

如果希望装包即生效，可在应用的 `Makefile` 的 `DEPENDS` 里补上
`+luci-lua-runtime +luci-compat`（两个版本分支的 feed 里都存在这两个包，已实测）。

## 常见问题
- **编译成功但找不到产物**：工作流用通配符 `find bin/packages -name "*<pkg>*.apk"` 查找，
  失败时会把该包的所有产物列出来。注意 apk 文件名不带架构后缀（`PKGARCH:=all` → `arch:noarch`）。
- **依赖报错 / 编译崩溃**：优先怀疑 feed 分支与 SDK 版本不匹配，必须成对使用
  （24.10 SDK + `openwrt-24.10`，25.12 SDK + `openwrt-25.12`）。
- **宿主依赖**：25.12 的宿主工具链多需要 `file gawk gettext libelf-dev libssl-dev rsync unzip`，
  工作流已一并安装。
