package edu.pkmon.common.error;

import edu.pkmon.demo.PkmonApplication;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 全局异常响应兜底的真实 HTTP 行为：任何未专门处理的错误都返回统一信封。
 * BoomController 仅存在于测试 classpath，用于制造一个抛运行时异常的接口。
 */
@SpringBootTest(classes = PkmonApplication.class)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(GlobalExceptionHandlerTest.BoomController.class)
class GlobalExceptionHandlerTest {

    @RestController
    static class BoomController {
        @GetMapping("/test-common/boom")
        String boom() {
            throw new IllegalStateException("boom");
        }
    }

    @Autowired
    private MockMvc mvc;

    @Test
    @DisplayName("未捕获异常 → HTTP 500 + 统一信封 code=50000，不泄露内部细节")
    void unexpectedExceptionReturnsEnvelope() throws Exception {
        mvc.perform(get("/test-common/boom"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value(50000))
                .andExpect(jsonPath("$.message").value("服务器内部错误"))
                .andExpect(jsonPath("$.data").value(nullValue()));
    }

    @Test
    @DisplayName("未知路径 → HTTP 404 + 统一信封 code=40401")
    void unknownPathReturnsUniformEnvelope() throws Exception {
        mvc.perform(get("/api/v1/no-such-endpoint"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(40401))
                .andExpect(jsonPath("$.data").value(nullValue()));
    }
}
