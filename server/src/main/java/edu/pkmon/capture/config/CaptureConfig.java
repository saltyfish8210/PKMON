package edu.pkmon.capture.config;

import edu.pkmon.capture.error.ApiExceptionHandler;
import edu.pkmon.capture.port.CurrentUserProvider;
import edu.pkmon.capture.port.DevHeaderCurrentUserProvider;
import edu.pkmon.capture.port.FixtureCatalog;
import edu.pkmon.capture.port.UnavailableCurrentUserProvider;
import edu.pkmon.capture.repository.Repositories.AnswerAttemptRepository;
import edu.pkmon.capture.repository.Repositories.CaptureRecordRepository;
import edu.pkmon.capture.repository.Repositories.ChallengeRepository;
import edu.pkmon.capture.repository.Repositories.SpawnRepository;
import edu.pkmon.capture.repository.memory.InMemoryAnswerAttemptRepository;
import edu.pkmon.capture.repository.memory.InMemoryCaptureRecordRepository;
import edu.pkmon.capture.repository.memory.InMemoryChallengeRepository;
import edu.pkmon.capture.repository.memory.InMemorySpawnRepository;
import edu.pkmon.capture.service.CaptureService;
import edu.pkmon.capture.service.CollectionService;
import edu.pkmon.capture.service.SpawnService;
import edu.pkmon.capture.web.CaptureController;
import edu.pkmon.capture.web.CollectionController;
import edu.pkmon.capture.web.DevSpawnController;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.AutoConfiguration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.core.env.Environment;

import java.time.Clock;
import java.util.Arrays;

/**
 * 本模块的装配点。启动类 PkmonApplication 位于 edu.pkmon.demo 且由胡豪主责，
 * 其组件扫描范围不含 edu.pkmon.capture，因此本模块通过 Spring Boot 自动配置注册自己
 * （见 META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports），
 * 不修改启动类。若日后启动类改为扫描 edu.pkmon，本类所有 @Bean 会因
 * @ConditionalOnMissingBean 自动让位，不会产生重复定义。
 *
 * 开关的安全默认（依 docs/stage2/project/decisions.csv 与胡豪 questions.csv
 * 「开发替身默认开启」一条）：开发期能力默认关闭，只有激活 dev 或 test profile 时才默认开启，
 * 也可用同名属性显式覆盖。
 *   pkmon.capture.dev-user-header    开发期身份替身（X-Dev-User 请求头，不是认证）
 *   pkmon.capture.dev-spawn-enabled  开发遭遇入口 /api/v1/dev/spawns
 *   pkmon.capture.in-memory-store    内存仓储替身；真实持久化实现接入前必须为 true，
 *                                    否则本模块没有可用仓储，应用无法启动
 * 正式环境需要：dev-user-header=false、dev-spawn-enabled=false、in-memory-store=false（接入真库后）。
 */
@AutoConfiguration
public class CaptureConfig {

    private static final Logger log = LoggerFactory.getLogger(CaptureConfig.class);

    static boolean devLikeProfile(Environment environment) {
        return Arrays.stream(environment.getActiveProfiles())
                .anyMatch(profile -> profile.equalsIgnoreCase("dev") || profile.equalsIgnoreCase("test"));
    }

    @Bean
    @ConditionalOnMissingBean
    public Clock captureClock() {
        return Clock.systemUTC();
    }

    @Bean
    @ConditionalOnMissingBean
    public FixtureCatalog fixtureCatalog() {
        return new FixtureCatalog();
    }

    @Bean
    @ConditionalOnMissingBean
    public CurrentUserProvider currentUserProvider(
            Environment environment,
            @Value("${pkmon.capture.dev-user-header:#{null}}") Boolean devUserHeader) {
        boolean enabled = devUserHeader != null ? devUserHeader : devLikeProfile(environment);
        if (enabled) {
            log.warn("capture 开发期身份替身已启用：身份取自 {} 请求头，仅限开发与测试；"
                    + "正式环境请设置 pkmon.capture.dev-user-header=false", DevHeaderCurrentUserProvider.HEADER);
            return new DevHeaderCurrentUserProvider();
        }
        return new UnavailableCurrentUserProvider();
    }

    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnProperty(name = "pkmon.capture.in-memory-store", havingValue = "true", matchIfMissing = true)
    public SpawnRepository spawnRepository() {
        return new InMemorySpawnRepository();
    }

    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnProperty(name = "pkmon.capture.in-memory-store", havingValue = "true", matchIfMissing = true)
    public ChallengeRepository challengeRepository() {
        return new InMemoryChallengeRepository();
    }

    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnProperty(name = "pkmon.capture.in-memory-store", havingValue = "true", matchIfMissing = true)
    public AnswerAttemptRepository answerAttemptRepository() {
        return new InMemoryAnswerAttemptRepository();
    }

    @Bean
    @ConditionalOnMissingBean
    @ConditionalOnProperty(name = "pkmon.capture.in-memory-store", havingValue = "true", matchIfMissing = true)
    public CaptureRecordRepository captureRecordRepository() {
        return new InMemoryCaptureRecordRepository();
    }

    @Bean
    @ConditionalOnMissingBean
    public SpawnService spawnService(Clock clock, SpawnRepository spawnRepository,
                                     Environment environment,
                                     @Value("${pkmon.capture.dev-spawn-enabled:#{null}}") Boolean devSpawnEnabled) {
        boolean enabled = devSpawnEnabled != null ? devSpawnEnabled : devLikeProfile(environment);
        if (enabled) {
            log.warn("capture 开发遭遇入口已启用：/api/v1/dev/spawns 仅限开发与测试；"
                    + "正式环境请设置 pkmon.capture.dev-spawn-enabled=false");
        }
        return new SpawnService(clock, spawnRepository, enabled);
    }

    @Bean
    @ConditionalOnMissingBean
    public CaptureService captureService(Clock clock, SpawnRepository spawnRepository,
                                         ChallengeRepository challengeRepository,
                                         AnswerAttemptRepository answerAttemptRepository,
                                         CaptureRecordRepository captureRecordRepository,
                                         FixtureCatalog fixtureCatalog) {
        return new CaptureService(clock, spawnRepository, challengeRepository,
                answerAttemptRepository, captureRecordRepository, fixtureCatalog, fixtureCatalog);
    }

    @Bean
    @ConditionalOnMissingBean
    public CollectionService collectionService(SpawnRepository spawnRepository,
                                               CaptureRecordRepository captureRecordRepository,
                                               FixtureCatalog fixtureCatalog) {
        return new CollectionService(spawnRepository, captureRecordRepository, fixtureCatalog);
    }

    @Bean
    @ConditionalOnMissingBean
    public DevSpawnController devSpawnController(SpawnService spawnService,
                                                 CurrentUserProvider currentUserProvider) {
        return new DevSpawnController(spawnService, currentUserProvider);
    }

    @Bean
    @ConditionalOnMissingBean
    public CaptureController captureController(CaptureService captureService,
                                               CurrentUserProvider currentUserProvider) {
        return new CaptureController(captureService, currentUserProvider);
    }

    @Bean
    @ConditionalOnMissingBean
    public CollectionController collectionController(CollectionService collectionService,
                                                     CurrentUserProvider currentUserProvider) {
        return new CollectionController(collectionService, currentUserProvider);
    }

    @Bean
    @ConditionalOnMissingBean
    public ApiExceptionHandler apiExceptionHandler() {
        return new ApiExceptionHandler();
    }
}
