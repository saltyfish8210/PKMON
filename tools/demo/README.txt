PKMon 演示构建与验证

运行成品：解压完整 Windows x64 包，双击“启动演示.cmd”。用户说明在 docs/stage2/demo/使用说明.txt。

从源码重建（Windows PowerShell）
1. 使用 Flutter 3.47.6（Dart 3.13.5）、JDK 17、Maven 3.9 和当前仓库源码。
2. 指定一个尚不存在的输出目录。脚本不会覆盖已有演示包或数据库。
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/demo/package-demo.ps1 -Build -IncludeRuntime -OutputDirectory C:\pkmon-demo -JavaHome C:\tools\jdk17 -FlutterHome C:\tools\flutter -MavenExecutable C:\tools\maven\bin\mvn.cmd
   把上述路径替换为本机实际绝对路径。第一次构建需要网络下载工具依赖。
3. 已分别完成客户端测试、网页构建和后端 clean verify 时，可以省略 -Build，复用 client/build/web 与 server/target 中的产物。
4. 脚本会把网页嵌入同一个 JAR，并可使用 jlink 创建 Windows Java 运行环境。运行目录由启动器固定，数据库不会散落到随机工作目录。
5. 说明文档、截图和验证结果需随本次版本一同交付。build-info.json 保存构建时提交号、本地改动状态和 JAR SHA256。

真实浏览器验收
安装 Node.js 与 Playwright，并有 Chrome 或 Playwright Chromium；录屏需要 Playwright 的 ffmpeg。
设置 JAVA_HOME 为 JDK 17 目录，PKMON_DEMO_JAR 为完整 JAR 路径，PKMON_EVIDENCE_DIR 为新证据目录。
可通过 CHROME_PATH 指定已安装 Chrome 的完整路径。
运行 node tools/demo/verify-demo.cjs。
脚本自动启动独立测试服务和临时文件数据库，不使用或清空演示账号的数据。验证结束自动关闭自己启动的服务。
测试覆盖完整页面操作、正式接口身份隔离、重复作答、服务重启持久化、网络错误重试、退出与会话撤销；浏览器禁止外网资源访问。
只有 verification.json 中 passed=true 才能称为本次真实浏览器验收通过。Android 真机结果不由此脚本替代。

数据和 Git
只提交源码、构建脚本、必要说明及不含敏感信息的测试证据；不提交 data/、logs/、运行时、JAR 或个人账号密码。
先 git status，保留已有个人改动；更新主线使用正常 fetch/merge，不使用强制推送、hard reset 或 git clean 清理他人文件。
大型演示包、视频通过交付压缩包分发，以版本号和 SHA256 对应源码。

开源字体
NotoSansSC.ttf 来源：https://github.com/google/fonts/tree/main/ofl/notosanssc
完整 SIL Open Font License 随 client/assets/fonts/OFL.txt 提供；字体原样随包分发，用于离线显示中文。
Roboto.ttf 来源：https://github.com/google/fonts/tree/main/ofl/roboto ，许可见 client/assets/fonts/Roboto-OFL.txt。它作为 Flutter 渲染器的默认字体随包提供。引擎可能尝试额外的字形回退请求；验收期间全部外网请求被阻断，以完整页面操作和可读截图确认课堂流程不依赖这些请求。
