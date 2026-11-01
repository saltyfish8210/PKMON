package edu.pkmon.capture.config;

import edu.pkmon.capture.error.ApiErrorCode;
import edu.pkmon.capture.error.ApiException;
import edu.pkmon.capture.port.UnavailableCurrentUserProvider;
import edu.pkmon.capture.repository.memory.InMemorySpawnRepository;
import edu.pkmon.capture.service.SpawnService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * 开发期开关的拒绝路径测试。
 * 依据：胡豪 design/questions.csv「开发替身默认开启」的后续动作——仅 dev/test 开启并补拒绝测试。
 */
class CaptureSwitchTest {

    private static final Clock CLOCK =
            Clock.fixed(Instant.parse("2026-10-25T12:00:00Z"), ZoneOffset.UTC);

    @Test
    @DisplayName("未接入认证时身份一律拒绝（50301），不做任何猜测")
    void unavailableIdentityRejects() {
        ApiException error = assertThrows(ApiException.class,
                () -> new UnavailableCurrentUserProvider().currentUserId());

        assertEquals(ApiErrorCode.AUTH_NOT_READY, error.errorCode());
        assertEquals(503, error.errorCode().httpStatus().value());
    }

    @Test
    @DisplayName("关闭开发遭遇时，即使参数合法也拒绝（40301）且不创建遭遇机会")
    void disabledDevSpawnIsRejected() {
        SpawnService spawnService = new SpawnService(CLOCK, new InMemorySpawnRepository(), false);

        ApiException error = assertThrows(ApiException.class,
                () -> spawnService.createDevSpawn("u-1", "library_entrance", "siege_lion"));

        assertEquals(ApiErrorCode.DEV_ONLY, error.errorCode());
        assertEquals(403, error.errorCode().httpStatus().value());
    }

    @Test
    @DisplayName("无 profile 时开发能力默认关闭")
    void noProfileMeansDevDisabled() {
        MockEnvironment environment = new MockEnvironment();

        assertFalse(CaptureConfig.devLikeProfile(environment));
    }

    @Test
    @DisplayName("dev 与 test profile 默认开启开发能力，大小写不敏感")
    void devAndTestProfilesEnableDev() {
        MockEnvironment dev = new MockEnvironment();
        dev.setActiveProfiles("dev");
        MockEnvironment test = new MockEnvironment();
        test.setActiveProfiles("TEST");

        assertTrue(CaptureConfig.devLikeProfile(dev));
        assertTrue(CaptureConfig.devLikeProfile(test));
    }

    @Test
    @DisplayName("其他 profile（含 prod）不视为开发环境")
    void otherProfilesDoNotEnableDev() {
        MockEnvironment prod = new MockEnvironment();
        prod.setActiveProfiles("prod", "staging");

        assertFalse(CaptureConfig.devLikeProfile(prod));
    }
}
