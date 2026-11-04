package edu.pkmon.user.web;

import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.MapperFeature;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.json.JsonMapper;
import edu.pkmon.common.api.ApiResponse;
import edu.pkmon.user.dto.AuthDtos.*;
import edu.pkmon.user.service.AuthFailure;
import edu.pkmon.user.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.*;
import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
public class AccountWeb {
    private static final int BODY_LIMIT = 4096;
    private static final ObjectReader JSON = JsonMapper.builder()
            .enable(JsonParser.Feature.STRICT_DUPLICATE_DETECTION)
            .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, DeserializationFeature.FAIL_ON_TRAILING_TOKENS)
            .disable(MapperFeature.ALLOW_COERCION_OF_SCALARS)
            .build().reader();
    private final AuthService auth;

    public AccountWeb(AuthService auth) { this.auth = auth; }

    @PostMapping(value="/auth/register", consumes="application/json")
    public ApiResponse<UserView> register(HttpServletRequest request) {
        return ApiResponse.ok(auth.register(body(request, RegisterRequest.class)));
    }

    @PostMapping(value="/auth/login", consumes="application/json")
    public ApiResponse<LoginResult> login(HttpServletRequest request) {
        return ApiResponse.ok(auth.login(body(request, LoginRequest.class)));
    }

    @GetMapping("/users/me")
    public ApiResponse<UserView> me(HttpServletRequest request) {
        return ApiResponse.ok(auth.currentUser(authorization(request)));
    }

    @PostMapping("/auth/logout")
    public ApiResponse<Map<String, Object>> logout(HttpServletRequest request) {
        // The Flutter client sends {}. A bodyless POST is also supported.
        byte[] payload = readLimited(request);
        if (payload.length != 0) {
            Map<?, ?> object = parse(payload, Map.class);
            if (object == null || !object.isEmpty()) throw new AuthFailure(AuthFailure.Kind.INVALID_INPUT);
        }
        auth.logout(authorization(request));
        return ApiResponse.ok(Map.of());
    }

    static String authorization(HttpServletRequest request) {
        var headers = request.getHeaders("Authorization");
        if (!headers.hasMoreElements()) return null;
        String header = headers.nextElement();
        if (headers.hasMoreElements()) throw new AuthFailure(AuthFailure.Kind.UNAUTHENTICATED);
        return header;
    }

    private static <T> T body(HttpServletRequest request, Class<T> type) {
        return parse(readLimited(request), type);
    }

    private static <T> T parse(byte[] bytes, Class<T> type) {
        try {
            var node = JSON.readTree(bytes);
            if (node == null || !node.isObject()) throw new AuthFailure(AuthFailure.Kind.INVALID_INPUT);
            // Jackson coerces numbers to Strings even for some strict mapper configurations.
            for (var values = node.elements(); values.hasNext(); ) {
                if (!values.next().isTextual()) throw new AuthFailure(AuthFailure.Kind.INVALID_INPUT);
            }
            return JSON.forType(type).readValue(node);
        } catch (IOException invalid) {
            throw new AuthFailure(AuthFailure.Kind.INVALID_INPUT);
        }
    }

    private static byte[] readLimited(HttpServletRequest request) {
        try {
            byte[] bytes = request.getInputStream().readNBytes(BODY_LIMIT + 1);
            if (bytes.length <= BODY_LIMIT) return bytes;
        } catch (IOException invalid) {
            throw new AuthFailure(AuthFailure.Kind.INVALID_INPUT);
        }
        throw new AuthFailure(AuthFailure.Kind.INVALID_INPUT);
    }
}
