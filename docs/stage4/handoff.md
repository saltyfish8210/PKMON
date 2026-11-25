# 孙虹毅 · M06 第二次迭代交付

## 使用顺序

- **运行演示**：解压交付包，安装 JDK 17 或 21，运行 `java -jar PKMon-M06.jar --spring.profiles.active=dev --server.port=4191 --pkmon.study.rules.required-seconds=2`，浏览器打开 `http://127.0.0.1:4191`。注册新账号后进入地图，开始自习，停留至出现精灵，答题后对照图鉴、背包与「我的」。定位是模拟的。dev 模式默认把账号保存在启动目录下的 `data/`；关闭终端即可停止。
- **客户端 / 测试**：读 `docs/api.md`；每个接口附 curl 与真实 JSON。`docs/stage4/examples/nearby.json` 可直接供地图 mock 使用。`scripts/stage4_smoke.py` 使用 Python 3 和 curl，针对独立本地 dev 服务运行；推荐按接口手册创建内存库，不污染日常开发库。
- **内容**：`docs/stage4/test-dataset.md` 列出 8 种精灵、30 道题及标准答案；运行时 JSON 在 `server/src/main/resources/catalog/`，迁移为 `V5__seed_catalog_full.sql`。其余美术资源未到位的物种暂用现有占位图。
- **合入仓库**：代码基于 `stage3@e4a6ccbd9c6235378fe363fe0d013280dc3cde9c`。在干净且匹配该基线的工作树执行 `git apply --check M06.patch`，再 `git apply M06.patch`。交付包亦含完整 client/server 源码（不含构建缓存）。无需同时复制源码和应用补丁。

## 验收记录（2026-11-25，本地）

|范围|已验证|
|---|---|
|正式接口|真实注册/登录、创建任务、连续采样、附近、取题/作答/状态、结束、注销；15 个接口均有真实返回，令牌已注销。|
|附近|半径内、越界、零距离、其他账号、捕获后移除；不把同种的不同遭遇误认为已捕获。|
|收藏|真实服务捕获一次，图鉴 1/8、背包 1 只、概览 1 种/1 次；Flutter 四页用真实响应回放，确认没有演示请求。|
|数据|Flyway V1–V5 从空库运行成功，自动测试逐行比对物种资料、题干、选项和答案；11 次新挑战无相邻十题内重复，同一挑战重开不换题。|
|构建|Spring Boot JAR、Flutter Web release 构建成功。未在实体安卓手机上验收。|
|完整测试|服务端 115/115 通过；Flutter 127/127 通过（开启 `PKMON_REAL_BACKEND=1`，3 项真实后端测试均已执行）。账号密码边界按 4–64 个 Unicode 字符且不超过 72 字节校验；收藏概览在首页、收藏页、返回首页分别请求一次。|

## 协作边界

交付分支：`feature/sunhongyi-stage4`。已完成本地验证；未部署，也未替成员确认验收。区域中心沿用第三阶段数据，不当作校园实测坐标；由地图负责人确认标记样式及真实坐标。开发期演示路由已隔离，保留至团队确认删除，不提前影响旧调用方。
