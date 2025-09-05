# LuCI App: Smart模型更新

用于 Openclash的Smart模型更新。

## 配置

- 在`仓库Git地址`中输入配置的git地址，并点击立即更新
- 通过日志查看更新详情
- 自用git为：`https://github.com/PlanetEditorX/openclash.git`,仓库主要为一些脚本，以及 `Model.bin`模型文件。逻辑为：OpenClash手动或定时更新，将收集到的`smart_weight_data.csv`文件上传，触发Github Actions，调用私有训练仓库`https://github.com/PlanetEditorX/Mihomo-AI-Trainer/tree/main`，训练仓库将训练文件存储并训练后，生成模型。
- `smart_weight_data.csv`模型文件仅在训练仓库中长期存在，不会在`PlanetEditorX/openclash.git`仓库中存在，避免后期训练文件过大，每次都会拉取大量的数据，每天生成的训练文件会作为新内容追加到训练仓库中。
