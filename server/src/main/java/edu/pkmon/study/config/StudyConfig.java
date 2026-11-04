package edu.pkmon.study.config;

import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.study.domain.DwellRules;
import edu.pkmon.study.domain.DwellEvaluator;
import edu.pkmon.study.domain.Region;
import edu.pkmon.study.error.StudyExceptionHandler;
import edu.pkmon.study.port.SpawnGateway;
import edu.pkmon.study.port.TaskRepository;
import edu.pkmon.study.repository.InMemoryTaskRepository;
import edu.pkmon.study.service.DwellStudyTaskService;
import edu.pkmon.study.service.StudyTaskService;
import edu.pkmon.study.web.StudyController;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;

import java.time.Clock;

/**
 * 自习任务模块的装配点。启动类在 edu.pkmon.demo 且组件扫描不含本模块，因此用 Spring Boot
 * 自动配置注册自己（见 META-INF/spring/...AutoConfiguration.imports），并全部使用
 * {@code @ConditionalOnMissingBean}，后续接 JDBC 仓库或孙虹毅的遭遇服务时直接覆盖。
 */
@AutoConfiguration
@EnableConfigurationProperties(StudyRulesProperties.class)
public class StudyConfig {

    private static final Logger log = LoggerFactory.getLogger(StudyConfig.class);

    /**
     * 规则参数。
     *
     * @param properties 配置
     * @return 不可变规则
     */
    @Bean
    @ConditionalOnMissingBean
    public DwellRules studyRules(StudyRulesProperties properties) {
        return properties.toRules();
    }

    /**
     * 规则判定器。
     *
     * @param rules 规则参数
     * @return 判定器
     */
    @Bean
    @ConditionalOnMissingBean
    public DwellEvaluator dwellEvaluator(DwellRules rules) {
        return new DwellEvaluator(rules);
    }

    /**
     * 开发期时钟；capture 模块已注册时让位。
     *
     * @return UTC 时钟
     */
    @Bean
    @ConditionalOnMissingBean
    public Clock studyClock() {
        return Clock.systemUTC();
    }

    /**
     * 区域定义。真实中心点由赵冠钧确认后经配置覆盖；未确认前使用候选中心，演示区域必须标注模拟。
     *
     * @param rules 规则参数
     * @param regionId 区域业务键
     * @param latitude 中心纬度
     * @param longitude 中心经度
     * @return 区域
     */
    @Bean
    @ConditionalOnMissingBean(name = "studyRegion")
    public Region studyRegion(DwellRules rules,
            @Value("${pkmon.study.region.id:library_entrance}") String regionId,
            @Value("${pkmon.study.region.latitude:39.9042}") double latitude,
            @Value("${pkmon.study.region.longitude:116.4074}") double longitude,
            @Value("${pkmon.study.region.coordinate-system:GCJ02}") String coordinates) {
        log.warn("study 区域使用候选中心点 {}（{},{}），未经真机验证；正式数据由 region 表提供", regionId, latitude, longitude);
        return new Region(regionId, latitude, longitude, rules.enterRadiusMeters(), rules.exitRadiusMeters(), true, coordinates);
    }

    /**
     * 任务存储。第三阶段由 JDBC 实现覆盖。
     *
     * @param region 区域
     * @return 内存仓库
     */
    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnProperty(name = "pkmon.study.in-memory-store", havingValue = "true", matchIfMissing = true)
    public TaskRepository taskRepository(Region region) {
        return new InMemoryTaskRepository(region);
    }

    /**
     * 驻留达标后将遭遇写入捕获模块的当前仓储。
     *
     * @return 可用于挑战的遭遇端口
     */
    @Bean
    @ConditionalOnMissingBean
    public SpawnGateway spawnGateway(edu.pkmon.capture.service.SpawnService spawns,
            @Value("${pkmon.study.spawn-gateway:capture}") String mode) {
        if ("stub".equals(mode)) return new StubSpawnGateway();
        if (!"capture".equals(mode)) throw new IllegalArgumentException("未知遭遇模式 " + mode);
        return (user, region, task, now, simulated) ->
                spawns.fromStudyTask(user, region, task, now, simulated).spawnId();
    }

    /**
     * 任务服务。
     *
     * @param repository 仓库
     * @param spawnGateway 遭遇端口
     * @param evaluator 规则判定器
     * @param clock 时钟
     * @return 服务
     */
    @Bean
    @ConditionalOnMissingBean
    public StudyTaskService studyTaskService(TaskRepository repository, SpawnGateway spawnGateway,
            DwellEvaluator evaluator, Clock clock) {
        return new DwellStudyTaskService(repository, spawnGateway, evaluator, clock);
    }

    /**
     * 业务错误映射。@RestControllerAdvice 不在组件扫描范围，必须显式注册为 Bean。
     *
     * @return 异常处理器
     */
    @Bean
    @ConditionalOnMissingBean
    public StudyExceptionHandler studyExceptionHandler() {
        return new StudyExceptionHandler();
    }

    /**
     * 控制器。
     *
     * @param service 任务服务
     * @param currentUser 身份端口（认证接入前由 capture 模块的开发期替身提供）
     * @return 控制器
     */
    @Bean
    @ConditionalOnMissingBean
    public StudyController studyController(StudyTaskService service, CurrentUserProvider currentUser) {
        return new StudyController(service, currentUser);
    }
}
