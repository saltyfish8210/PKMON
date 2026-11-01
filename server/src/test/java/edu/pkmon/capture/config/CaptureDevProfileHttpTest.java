package edu.pkmon.capture.config;

import edu.pkmon.demo.PkmonApplication;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * dev profile 下的开发期能力：身份替身与开发遭遇入口默认开启。
 * 这里验证的是开发可用性，不代表认证或真实定位已实现。
 */
@SpringBootTest(classes = PkmonApplication.class)
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class CaptureDevProfileHttpTest {

    @Autowired
    private MockMvc mvc;

    @Test
    @DisplayName("dev profile：带开发身份头可正常访问业务接口")
    void businessApiWorksWithDevIdentity() throws Exception {
        mvc.perform(get("/api/v1/collection/summary").header("X-Dev-User", "u-dev-test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0))
                .andExpect(jsonPath("$.data.captureCount").value(0));
    }

    @Test
    @DisplayName("dev profile：缺少身份头仍是 401，不因 profile 放宽身份校验")
    void missingHeaderStillRejected() throws Exception {
        mvc.perform(get("/api/v1/collection/summary"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(40101));
    }

    @Test
    @DisplayName("dev profile：开发遭遇入口可用，并如实标注模拟来源")
    void devSpawnIsAvailableInDevProfile() throws Exception {
        mvc.perform(post("/api/v1/dev/spawns")
                        .header("X-Dev-User", "u-dev-test")
                        .contentType(APPLICATION_JSON)
                        .content("{\"regionId\":\"library_entrance\",\"speciesId\":\"siege_lion\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.sourceType").value("DEV_SIMULATED"));
    }
}
