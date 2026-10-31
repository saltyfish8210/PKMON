package edu.pkmon.common.config;

import org.flywaydb.core.Flyway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;

import javax.sql.DataSource;
import java.sql.Connection;
import java.util.Arrays;

/**
 * 启动检查：服务就绪前打印一次环境核对信息。
 * 只输出非敏感项（数据库 URL 不含口令），用于交接时快速确认
 * 「连的是哪个库、迁移执行到哪个版本」。数据库不可用时启动直接失败（fail-fast）。
 */
public class StartupCheckRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(StartupCheckRunner.class);

    private final Environment environment;
    private final DataSource dataSource;
    private final ObjectProvider<Flyway> flyway;

    public StartupCheckRunner(Environment environment, DataSource dataSource,
                              ObjectProvider<Flyway> flyway) {
        this.environment = environment;
        this.dataSource = dataSource;
        this.flyway = flyway;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        String[] active = environment.getActiveProfiles();
        String profiles = active.length == 0 ? "(默认)" : String.join(",", active);
        String url;
        try (Connection connection = dataSource.getConnection()) {
            url = connection.getMetaData().getURL();
        }
        Flyway f = flyway.getIfAvailable();
        String migrations = f == null ? "未启用"
                : Arrays.stream(f.info().applied())
                        .map(m -> "V" + m.getVersion() + " " + m.getScript())
                        .toList().toString();
        log.info("PKMon 启动检查 | profiles={} | datasource={} | 已应用迁移={}", profiles, url, migrations);
        if (Arrays.stream(active).anyMatch(p -> p.equalsIgnoreCase("dev") || p.equalsIgnoreCase("test"))) {
            log.warn("当前为 {} profile：开发替身（X-Dev-User）与开发遭遇入口默认开启，正式环境不得使用",
                    profiles);
        }
    }
}
