# PKMon 后端（Spring Boot）

课程演示用的后端服务。**题目、选项和正确答案都在这里**——客户端只负责显示后端下发的题目和上报选项。

> 仓库根目录的 [`../README.md`](../README.md) 有完整的构建、启动和验收步骤；
> 本文记录后端结构、接口和改动位置。

---

## 一、构建与启动

**前提**：JDK 17 或更高（需要 `javac`，只有 JRE 不行）和 Maven 3.9+。

```bash
cd server
mvn clean package
java -jar target/pkmon-server-0.1.0.jar
```

产物：

```text
target/pkmon-server-0.1.0.jar          # 可直接运行的完整包
target/pkmon-server-0.1.0.jar.original # 未打包依赖的原始 jar，可忽略
```

看到 `Tomcat started on port 4180` 即就绪。
第一次构建要下载依赖，之后走本地缓存。

只编译不跑测试：`mvn package -DskipTests`。

### 启动后的两个入口

| 地址 | 内容 |
|---|---|
| `http://127.0.0.1:4180/` | 网页版 App（需要先把 `client/build/web/` 放进 `src/main/resources/static/` 并重新打包） |
| `http://127.0.0.1:4180/test/hello` | 后端健康检查，返回 `hello world` |

网页版和接口由同一个服务托管，浏览器请求天然同源，**不需要配 CORS**。

### 配置

`src/main/resources/application.properties`：

```properties
server.address=127.0.0.1
server.port=4180
spring.application.name=PKMon-stage1-demo
```

命令行覆盖：

```bash
# 换端口
java -jar target/pkmon-server-0.1.0.jar --server.port=4181

# 让同网段真机访问
java -jar target/pkmon-server-0.1.0.jar --server.address=0.0.0.0
```

默认只监听 `127.0.0.1`；安卓模拟器经 `10.0.2.2` 可以访问，真机不行。

### 数据库与 profile（第二阶段新增，胡豪维护）

嵌入式 H2，免安装；迁移由 Flyway 管理（`src/main/resources/db/migration/`，胡豪统一编号）。

| profile | 数据库 | 用途 |
|---|---|---|
| 默认（无） | 内存库 `jdbc:h2:mem:pkmon` | 直接启动验证，不写磁盘 |
| `dev` | 文件库 `./data/pkmon-dev`（在 `server/data/`，不入库） | 联调，重启后数据保留 |
| `test` | 内存库 `pkmon_test` | 自动化测试专用独立库 |

```bash
# 用 dev profile 启动（重启后数据保留）
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

数据库口令读环境变量 `PKMON_DB_PASSWORD`（默认空）。启动日志中的
「PKMon 启动检查」一行可核对当前连的库与迁移版本。
全量环境说明见 `../docs/stage2/baselines/environment.txt`。

---

## 二、要改题目，改哪个文件

**`src/main/java/edu/pkmon/demo/DemoService.java`**

### 题干、选项、精灵名 —— `challenge()` 方法

```java
return Map.of("challengeId", token, "spawnId", spawnId, "name", "攻城狮",
    "question", "执行 print(\"hello world\") 之后，控制台会输出什么？",
    "options", List.of(
        Map.of("id","A","text","hello world"),
        Map.of("id","B","text","\"hello world\"（连引号一起输出）"),
        Map.of("id","C","text","什么都不输出，只是定义了一个字符串")),
    "source", "演示题：编程基础常识，非真实校史题");
```

### 正确答案 —— `answer()` 方法

```java
boolean success = "A".equals(option);   // 选 A 算对
```

> 如果正确答案不再是 A，还要同步修改
> `src/test/java/edu/pkmon/demo/DemoServiceTest.java` 里的错误答案/正确答案断言，
> 否则 `mvn package` 会失败。

### 提示语 —— `answer()` 方法

```java
"message", success ? "攻城狮已收入图鉴" : "这次没有答对，回到地图再试一次"
```

Java 字符串里的双引号必须写成 `\"`。

---

## 三、接口清单

统一前缀 `/api/v1`，除建会话外都要带 `X-Demo-Session` 头。

| 方法 | 路径 | 请求体 | 返回 |
|---|---|---|---|
| GET | `/test/hello` | — | 纯文本 `hello world` |
| POST | `/api/v1/demo/sessions` | `{}` | `sessionId` |
| GET | `/api/v1/demo/state` | — | `nearby` / `captured` / `count` / `totalSpecies` |
| POST | `/api/v1/demo/explore` | `{}` | 同上（把 `nearby` 置 true） |
| POST | `/api/v1/demo/reset` | `{}` | 同上（清空本会话） |
| POST | `/api/v1/capture/challenge` | `{"spawnId":"library-001"}` | 题干 + 选项（**不含答案**） |
| POST | `/api/v1/capture/answer` | `{"challengeId":"...","optionId":"A"}` | `success` / `message` / `count` |

统一响应信封：`{"code":0,"message":"ok","data":{...}}`，`code == 0` 表示成功。

完整的命令行验证脚本见根目录 README 的「攻城狮捕获流程」。

---

## 四、设计上的关键点（改代码时别破坏）

1. **正确答案不下发给客户端**。`challenge()` 只返回题干和选项。
   测试 `challengeNeverDisclosesAnswer` 在守着这条。
2. **判题在服务端**。客户端只上报选了哪个字母（`optionId`）。
3. **同一道题只能答一次**。`Challenge.result` 一旦写入就返回缓存值，重复提交拿到首次结果（幂等）。
   答错后要重新调 `capture/challenge` 换新 token。
4. **状态全在内存**。重启服务，所有会话和进度清零，没有数据库。
5. **会话隔离**。每个 `sessionId` 有独立的 `nearby` / `captured`，多人同时演示互不干扰。

---

## 五、网页静态资源

`src/main/resources/static/` 用于存放 `client/build/web/` 的构建产物。
这些文件是**编译产物，已被 `.gitignore` 排除**，仓库里只保留 `.gitkeep`。

更新网页版的流程：

```bash
cd client
flutter build web --release

# 回到仓库根目录（Git Bash / macOS / Linux）
find server/src/main/resources/static -mindepth 1 ! -name .gitkeep -delete
cp -r client/build/web/. server/src/main/resources/static/

# PowerShell 等价写法
# Get-ChildItem server/src/main/resources/static -Exclude .gitkeep |
#   Remove-Item -Recurse -Force
# Copy-Item client/build/web/* server/src/main/resources/static/ -Recurse -Force

cd server
mvn clean package
```
