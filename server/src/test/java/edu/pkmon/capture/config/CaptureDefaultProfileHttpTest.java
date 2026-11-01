package edu.pkmon.capture.config;

import edu.pkmon.demo.PkmonApplication;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 默认配置（无 dev/test profile）下的启动与拒绝行为。
 * 期望：应用能正常启动，但开发期身份与开发遭遇入口都关闭，不带身份头一律 503 或 401。
 */
@SpringBootTest(classes = PkmonApplication.class)
@AutoConfigureMockMvc
class CaptureDefaultProfileHttpTest {

    @Autowired
    private MockMvc mvc;

    @Test
    @DisplayName("默认配置：业务接口拒绝，返回 50301 而不是放行")
    void businessApiRejectsWithoutIdentity() throws Exception {
        mvc.perform(get("/api/v1/collection/summary"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value(50301));
    }

    @Test
    @DisplayName("默认配置：开发遭遇入口同样被拒绝")
    void devSpawnRejectedByDefault() throws Exception {
        mvc.perform(post("/api/v1/dev/spawns")
                        .contentType(APPLICATION_JSON)
                        .content("{\"regionId\":\"library_entrance\",\"speciesId\":\"siege_lion\"}"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value(50301));
    }

    @Test
    @DisplayName("默认配置：旧演示接口不受影响")
    void demoEndpointsStillWork() throws Exception {
        mvc.perform(post("/api/v1/demo/sessions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(0));
    }
}
