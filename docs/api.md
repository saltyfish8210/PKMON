# PKMon M06 · 接口手册

基线：`stage3@e4a6ccb`。账号为公共前置；业务分自习、捕获、收藏三组。下文相对路由的统一前缀为 `/api/v1`。除注册、登录外，均传 `Authorization: Bearer <token>`。成功 HTTP 200 且 `code=0`；错误码表在文末。

## 从空库复现

在 `server` 目录执行（JDK 17+、Maven）：

```sh
mvn -DskipTests package
java -jar target/pkmon-server-0.1.0.jar --spring.profiles.active=dev --server.port=4191 --spring.datasource.url=jdbc:h2:mem:m06 --pkmon.study.rules.required-seconds=2
```

另开终端，在仓库根目录运行 `python scripts/stage4_smoke.py`。脚本实际调用 `curl`，创建两个临时账号，从注册登录跑到自习、采样、附近、捕获、收藏、结束和退出。另用 dev 造遭遇验证连续出题；不需要手抄 ID。加 `--examples docs/stage4/examples` 可重新采集；脚本先注销令牌，再保存响应。请勿对正式库运行。

以下为 POSIX shell 单接口示例：`BASE=http://127.0.0.1:4191/api/v1`；`TOKEN` 取 login 的 `data.token`，`TASK_ID`、`SPAWN_ID`、`CHALLENGE_ID` 分别来自创建任务、达标样本、取题响应。采样前 `UTC_NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)`，每个新样本更换 sampleId。示例来自一次隔离的 dev/JDBC/H2 服务运行，时间为 UTC，登录令牌已注销并在归档时脱敏。测试驻留阈值 2 秒，正常默认 600 秒；手册中的另一组经纬度不是此基线的图书馆中心。

## 统计和出题口径

图鉴分母是目录物种数；已收种类数等于背包条目数；收录总只数等于背包各条目数量之和。不要把“种”和“只”直接比较。附近接口只列已生成的遭遇，不会因查询而发奖。地图用模拟定位，显示最近一个标记；接口返回所有匹配项。

固定数据集：`server/src/main/resources/catalog/stage4.json`，包含归属物种、选项和标准答案，仅供服务端/测试使用。V5 补齐既有 V3/V4，不修改旧迁移；`Stage4CatalogTest` 逐项比对。首次出该物种的基础题（新账号第一题）；其后优先从该物种未在最近九个挑战内出现的题中随机选择，耗尽才从公共题池补位，所以连续十次新挑战不重复。重开同一有效挑战不是重新抽题。尚无独立美术的物种复用现有占位图，不返回不存在的资源键。

### POST /auth/register

作用：注册本地账号。

请求：{"username":"m06_demo","password":"example_pass_42","nickname":"演示用户"}

可能错误：40001、40901、50301。

示例：
```sh
curl -sS -X POST "$BASE/auth/register" -H "Content-Type: application/json" --data '{"username":"m06_demo","password":"example_pass_42","nickname":"演示用户"}'
```

返回 200 · [真实响应](stage4/examples/register.json)：
```json
{"code":0,"message":"ok","data":{"userId":"b12e0660-1bf6-494d-8a9d-a3a1ee243d2b","username":"m06_9fab6a94_abe","nickname":"接口验收"}}
```

### POST /auth/login

作用：取得 Bearer 会话。

请求：{"username":"m06_demo","password":"example_pass_42"}

可能错误：40001、40101、50301。

示例：
```sh
curl -sS -X POST "$BASE/auth/login" -H "Content-Type: application/json" --data '{"username":"m06_demo","password":"example_pass_42"}'
```

返回 200 · [真实响应](stage4/examples/login.json)：
```json
{"code":0,"message":"ok","data":{"token":"<REDACTED>","expiresAt":"2026-11-25T02:32:56.369723400Z","user":{"userId":"b12e0660-1bf6-494d-8a9d-a3a1ee243d2b","username":"m06_9fab6a94_abe","nickname":"接口验收"}}}
```

### GET /users/me

作用：查询当前用户。

请求：无请求体。

可能错误：40101、50301。

示例：
```sh
curl -sS -X GET "$BASE/users/me" -H "Authorization: Bearer $TOKEN"
```

返回 200 · [真实响应](stage4/examples/me.json)：
```json
{"code":0,"message":"ok","data":{"userId":"b12e0660-1bf6-494d-8a9d-a3a1ee243d2b","username":"m06_9fab6a94_abe","nickname":"接口验收"}}
```

### POST /study/tasks

作用：开始自习；同一请求可重放。

请求：{"regionId":"library_entrance","requestId":"start-001","locationSource":"SIMULATED"}

可能错误：40001、40101、40401、40902、40903、40904。

示例：
```sh
curl -sS -X POST "$BASE/study/tasks" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data '{"regionId":"library_entrance","requestId":"start-001","locationSource":"SIMULATED"}'
```

返回 200 · [真实响应](stage4/examples/tasks.json)：
```json
{"code":0,"message":"ok","data":{"taskId":"740582c4-5fff-4c4f-8ea4-393c76bb56a7","regionId":"library_entrance","status":"WAITING","pauseReason":null,"effectiveSeconds":0,"requiredSeconds":2,"spawnId":null,"serverTime":"2026-11-24T18:32:56.557111700Z","locationSource":"SIMULATED"}}
```

### GET /study/tasks/current

作用：读取当前任务；没有任务时 data.task 为 null。

请求：无请求体。

可能错误：40101。

示例：
```sh
curl -sS -X GET "$BASE/study/tasks/current" -H "Authorization: Bearer $TOKEN"
```

返回 200 · [真实响应](stage4/examples/current.json)：
```json
{"code":0,"message":"ok","data":{"task":{"taskId":"740582c4-5fff-4c4f-8ea4-393c76bb56a7","regionId":"library_entrance","status":"WAITING","pauseReason":null,"effectiveSeconds":0,"requiredSeconds":2,"spawnId":null,"serverTime":"2026-11-24T18:32:56.816847400Z","locationSource":"SIMULATED"}}}
```

### POST /study/tasks/{id}/samples

作用：上传定位样本。sampledAt 为当前 UTC 时间；坐标系须与区域一致。业务拒绝样本时检查 sampleAccepted 与 rejectionReason，不一定是 HTTP 错误。

请求：{"sampleId":"sample-001","latitude":39.9042,"longitude":116.4074,"accuracyMeters":8,"sampledAt":"${UTC_NOW}","coordinateSystem":"GCJ02","source":"SIMULATED"}

可能错误：40001、40101、40301（禁用模拟遭遇）、40401、40902、40903。

示例：
```sh
curl -sS -X POST "$BASE/study/tasks/${TASK_ID}/samples" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data "{\"sampleId\":\"sample-001\",\"latitude\":39.9042,\"longitude\":116.4074,\"accuracyMeters\":8,\"sampledAt\":\"${UTC_NOW}\",\"coordinateSystem\":\"GCJ02\",\"source\":\"SIMULATED\"}"
```

返回 200 · [真实响应](stage4/examples/samples.json)：
```json
{"code":0,"message":"ok","data":{"taskId":"740582c4-5fff-4c4f-8ea4-393c76bb56a7","regionId":"library_entrance","status":"TRIGGERED","pauseReason":null,"effectiveSeconds":2,"requiredSeconds":2,"spawnId":"04467119-54e0-3031-825b-5e59e7af16bc","serverTime":"2026-11-24T18:33:00.211729400Z","sampleAccepted":true,"rejectionReason":null}}
```

### GET /capture/nearby

作用：取本用户有效且未收录的遭遇。坐标为区域坐标系（内置区域 GCJ02）；半径为 0–20000 米，边界含等号。按未舍入距离过滤，再把距离四舍五入到米。没有匹配时 items=[]。

请求：查询参数 `lat`、`lng`、`radius` 均为必填数值。

可能错误：40001、40101。

示例：
```sh
curl -sS -X GET "$BASE/capture/nearby?lat=39.90455&lng=116.4074&radius=200" -H "Authorization: Bearer $TOKEN"
```

返回 200 · [真实响应](stage4/examples/nearby.json)：
```json
{"code":0,"message":"ok","data":{"items":[{"spawnId":"04467119-54e0-3031-825b-5e59e7af16bc","speciesId":"study_spirit","name":"自习精灵","iconKey":"spirit_placeholder","distanceMeters":39,"regionName":"图书馆","latitude":39.9042,"longitude":116.4074}]}}
```

### POST /capture/challenge

作用：取题或复用该遭遇尚未过期的挑战。

请求：{"spawnId":"${SPAWN_ID}"}

可能错误：40001、40101、40401、40903、41001、50302。

示例：
```sh
curl -sS -X POST "$BASE/capture/challenge" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data "{\"spawnId\":\"${SPAWN_ID}\"}"
```

返回 200 · [真实响应](stage4/examples/challenge.json)：
```json
{"code":0,"message":"ok","data":{"challengeId":"e0b9d184-1b88-4d6f-9eeb-27a0e1f565ce","spawnId":"04467119-54e0-3031-825b-5e59e7af16bc","speciesId":"study_spirit","speciesName":"自习精灵","questionId":"study_spirit_001","questionText":"连续学习 25 分钟后休息 5 分钟，这种时间管理方法通常叫什么？","options":[{"optionId":"A","text":"番茄工作法"},{"optionId":"B","text":"康奈尔笔记法"},{"optionId":"C","text":"费曼学习法"}],"expiresAt":"2026-11-24T18:38:00.577213Z","sourceType":"DEV_SIMULATED"}}
```

### POST /capture/answer

作用：提交选项。重试请复用 requestId；不同作答使用新 ID。

请求：{"challengeId":"${CHALLENGE_ID}","requestId":"answer-001","optionId":"A"}

可能错误：40001、40101、40401、40902、41001、50302。

示例：
```sh
curl -sS -X POST "$BASE/capture/answer" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data "{\"challengeId\":\"${CHALLENGE_ID}\",\"requestId\":\"answer-001\",\"optionId\":\"A\"}"
```

返回 200 · [真实响应](stage4/examples/answer.json)：
```json
{"code":0,"message":"ok","data":{"challengeId":"e0b9d184-1b88-4d6f-9eeb-27a0e1f565ce","requestId":"d6cfc5d9-c1d4-461e-a2a2-bebfff436494","result":"CORRECT","captureRecordId":"c9b655c1-241f-42ca-9a1a-adb35d949250","speciesId":"study_spirit"}}
```

### POST /capture/status

作用：查询挑战状态与最近作答。

请求：{"challengeId":"${CHALLENGE_ID}"}

可能错误：40001、40101、40401。

示例：
```sh
curl -sS -X POST "$BASE/capture/status" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data "{\"challengeId\":\"${CHALLENGE_ID}\"}"
```

返回 200 · [真实响应](stage4/examples/status.json)：
```json
{"code":0,"message":"ok","data":{"challengeId":"e0b9d184-1b88-4d6f-9eeb-27a0e1f565ce","status":"CAPTURED","captureRecordId":"c9b655c1-241f-42ca-9a1a-adb35d949250","expiresAt":"2026-11-24T18:38:00.577213Z","lastAttempt":{"requestId":"d6cfc5d9-c1d4-461e-a2a2-bebfff436494","result":"CORRECT","submittedAt":"2026-11-24T18:33:00.703724Z"}}}
```

### GET /collection/summary

作用：查询已收物种数、全目录数和收录总只数。

请求：无请求体。

可能错误：40101。

示例：
```sh
curl -sS -X GET "$BASE/collection/summary" -H "Authorization: Bearer $TOKEN"
```

返回 200 · [真实响应](stage4/examples/summary.json)：
```json
{"code":0,"message":"ok","data":{"collectedSpeciesCount":1,"totalSpeciesCount":8,"captureCount":1}}
```

### GET /collection/dex

作用：按目录编号列出八种；零收录也返回名称、简介、立绘键。

请求：无请求体。

可能错误：40101。

示例：
```sh
curl -sS -X GET "$BASE/collection/dex" -H "Authorization: Bearer $TOKEN"
```

返回 200 · [真实响应](stage4/examples/dex.json)：
```json
{"code":0,"message":"ok","data":{"collectedSpeciesCount":1,"totalSpeciesCount":8,"entries":[{"speciesId":"siege_lion","name":"攻城狮","catalogNumber":1,"description":"背着键盘穿过机房，专爱拆解程序的小谜题。","imageKey":"assets/sprites/siege_lion.png","count":0,"firstCapturedAt":null},{"speciesId":"study_spirit","name":"自习精灵","catalogNumber":2,"description":"它守在图书馆入口，把一段段专心的时间收进沙漏。","imageKey":"assets/sprites/spirit_placeholder.png","count":1,"firstCapturedAt":"2026-11-24T18:33:00.703724Z"},{"speciesId":"ink_owl","name":"墨羽鸮","catalogNumber":3,"description":"它在阅览室的灯下校对引文，从不折书角。","imageKey":"assets/sprites/spirit_placeholder.png","count":0,"firstCapturedAt":null},{"speciesId":"fern_fox","name":"蕨尾狐","catalogNumber":4,"description":"尾巴卷成嫩蕨的形状，会沿着温室的阴影散步。","imageKey":"assets/sprites/spirit_placeholder.png","count":0,"firstCapturedAt":null},{"speciesId":"orbit_cat","name":"星轨猫","catalogNumber":5,"description":"在天文台的窗台上，它用尾尖描出星轨。","imageKey":"assets/sprites/spirit_placeholder.png","count":0,"firstCapturedAt":null},{"speciesId":"wave_otter","name":"听波獭","catalogNumber":6,"description":"它伏在实验台边，用胡须感受音叉的振动。","imageKey":"assets/sprites/spirit_placeholder.png","count":0,"firstCapturedAt":null},{"speciesId":"prism_deer","name":"棱光鹿","catalogNumber":7,"description":"阳光穿过鹿角时，走廊的白墙上会出现彩带。","imageKey":"assets/sprites/spirit_placeholder.png","count":0,"firstCapturedAt":null},{"speciesId":"bridge_beaver","name":"筑桥狸","catalogNumber":8,"description":"它在模型工坊搭小桥，总要先试一试承重。","imageKey":"assets/sprites/spirit_placeholder.png","count":0,"firstCapturedAt":null}]}}
```

### GET /collection/bag

作用：仅列出已拥有的物种，按最近收录时间倒序。

请求：无请求体。

可能错误：40101。

示例：
```sh
curl -sS -X GET "$BASE/collection/bag" -H "Authorization: Bearer $TOKEN"
```

返回 200 · [真实响应](stage4/examples/bag.json)：
```json
{"code":0,"message":"ok","data":{"totalCount":1,"speciesCount":1,"entries":[{"speciesId":"study_spirit","name":"自习精灵","count":1,"latestCapturedAt":"2026-11-24T18:33:00.703724Z"}]}}
```

### POST /study/tasks/{id}/end

作用：结束当前任务。

请求：{"requestId":"end-001"}

可能错误：40001、40101、40401。

示例：
```sh
curl -sS -X POST "$BASE/study/tasks/${TASK_ID}/end" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data '{"requestId":"end-001"}'
```

返回 200 · [真实响应](stage4/examples/end.json)：
```json
{"code":0,"message":"ok","data":{"taskId":"740582c4-5fff-4c4f-8ea4-393c76bb56a7","regionId":"library_entrance","status":"ENDED","pauseReason":null,"effectiveSeconds":2,"requiredSeconds":2,"spawnId":"04467119-54e0-3031-825b-5e59e7af16bc","serverTime":"2026-11-24T18:33:04.565119200Z","locationSource":"SIMULATED"}}
```

### POST /auth/logout

作用：撤销当前会话；请求体可为空或 {}。

请求：{}

可能错误：40001、40101、50301。

示例：
```sh
curl -sS -X POST "$BASE/auth/logout" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" --data '{}'
```

返回 200 · [真实响应](stage4/examples/logout.json)：
```json
{"code":0,"message":"ok","data":{}}
```

## 兼容与废弃

- 正式新增：`GET /capture/nearby`、`POST /capture/status`；旧的 `GET /capture/challenges/{challengeId}` 继续兼容，返回结构相同。
- `/api/v1/demo/*` 标为 `@Deprecated`，仅 dev 注册：sessions、state、explore、reset、capture/challenge、capture/answer。客户端不调用；其他 profile 返回 404。2026-12-10 后由团队确认删除，本次不提前删除。`/test/hello` 不受影响。

## 错误码

|HTTP|code|含义|
|---|---|---|
|400|40001|参数、JSON、坐标或范围无效|
|401|40101|凭据无效、未登录或会话不可用|
|403|40301|开发期模拟遭遇未开放|
|404|40401|接口、区域、任务、遭遇或挑战不存在；跨用户按不存在处理|
|409|40901|用户名已使用|
|409|40902|同一请求编号或采样编号对应不同内容|
|409|40903|自习状态不允许；捕获时表示遭遇已收录|
|409|40904|自习任务仍在冷却期|
|410|41001|挑战或遭遇已过期|
|503|50301|身份上下文或认证服务不可用|
|503|50302|题库不可用|
|500|50000|未预期服务端异常；不用于正常业务分支|
