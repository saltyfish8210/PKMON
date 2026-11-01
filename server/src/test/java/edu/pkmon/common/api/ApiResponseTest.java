package edu.pkmon.common.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** 统一响应信封的序列化形状，对照接口约定 pkmon-stage2-candidate。 */
class ApiResponseTest {

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    @DisplayName("成功信封：{\"code\":0,\"message\":\"ok\",\"data\":{...}}")
    void okEnvelopeMatchesContract() throws Exception {
        JsonNode node = mapper.readTree(
                mapper.writeValueAsString(ApiResponse.ok(Map.of("userId", "u-1"))));
        assertEquals(0, node.get("code").asInt());
        assertEquals("ok", node.get("message").asText());
        assertEquals("u-1", node.get("data").get("userId").asText());
    }

    @Test
    @DisplayName("失败信封：{\"code\":40001,\"message\":\"参数错误\",\"data\":null}")
    void errorEnvelopeMatchesContract() throws Exception {
        JsonNode node = mapper.readTree(
                mapper.writeValueAsString(ApiResponse.error(40001, "参数错误")));
        assertEquals(40001, node.get("code").asInt());
        assertEquals("参数错误", node.get("message").asText());
        assertTrue(node.get("data").isNull());
    }
}
