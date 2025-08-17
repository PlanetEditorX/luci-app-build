# luci-app-build
## 项目介绍
简单的luci应用创建模板，fork项目后将`luci-app-hello`替换为需要的应用进行编译测试。
基于`OpenWRT 24.10.2`，使用的SDK是`https://downloads.openwrt.org/releases/24.10.2/targets/mediatek/filogic/openwrt-sdk-24.10.2-mediatek-filogic_gcc-13.3.0_musl.Linux-x86_64.tar.zst`

## 工作流介绍
1. luci-app-build-v0
- 初始化测试，无需任何文件，直接运行该工作流就会编译生成hello的ipk文件
2. luci-app-build-v1
- 单包编译，会将仓库下的第一个`luci-app-xxx`编译
3. luci-app-build-v2
- 多包编译，会将仓库下的所有`luci-app-xxx`编译，运行时如果仓库有多个`luci-app-xxx`，则会将除`luci-app-hello`外的其它软件包编译。如果仓库只有`luci-app-hello`，才会编译`luci-app-hello`