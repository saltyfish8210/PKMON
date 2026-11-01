package edu.pkmon.common.config;

import edu.pkmon.common.error.GlobalExceptionHandler;
import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

import javax.sql.DataSource;
import java.time.Clock;

/**
 * 公共模块装配点（主责：胡豪）。启动类 PkmonApplication 位于 edu.pkmon.demo，
 * 组件扫描不覆盖本包，因此与 capture 模块一样通过自动配置注册
 * （见 META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports，
 * 本类排在 CaptureConfig 之前，使这里的 Clock 成为全模块唯一定义）。
 * 全部 @Bean 带 @ConditionalOnMissingBean：业务模块或测试可自行替换实现
 * （例如测试替换为固定时钟），不产生重复定义。
 */
@AutoConfiguration
public class CommonConfig {

    /** 可注入时钟：全模块统一 UTC；测试替换为固定时钟即可独立验证时间边界。 */
    @Bean
    @ConditionalOnMissingBean
    public Clock clock() {
        return Clock.systemUTC();
    }

    /** 统一异常响应兜底。 */
    @Bean
    @ConditionalOnMissingBean
    public GlobalExceptionHandler globalExceptionHandler() {
        return new GlobalExceptionHandler();
    }

    /** 启动检查：就绪前打印数据源与迁移状态，便于交接时核对环境。 */
    @Bean
    @ConditionalOnMissingBean
    public StartupCheckRunner startupCheckRunner(Environment environment, DataSource dataSource,
                                                 ObjectProvider<Flyway> flyway) {
        return new StartupCheckRunner(environment, dataSource, flyway);
    }
}
