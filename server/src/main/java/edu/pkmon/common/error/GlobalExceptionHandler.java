package edu.pkmon.common.error;

import edu.pkmon.common.api.ApiResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * 全局异常响应兜底（主责：胡豪）。
 * 业务模块已声明的处理器优先匹配（例如 capture 的 ApiException/IllegalArgumentException
 * 由 capture 自己的 ApiExceptionHandler 处理），本类只兜住没有专门处理的情况，
 * 保证任何错误都按统一信封返回、不泄露堆栈与内部细节。
 * 错误码沿用组内约定：40001 参数错误 / 40401 资源不存在 / 50000 服务器内部错误。
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /** 请求形状不合法：缺参数、类型不匹配、请求体 JSON 无法解析。 */
    @ExceptionHandler({MissingServletRequestParameterException.class,
            MethodArgumentTypeMismatchException.class, HttpMessageNotReadableException.class})
    public ResponseEntity<ApiResponse<Void>> handleBadRequest(Exception e) {
        return ResponseEntity.badRequest().body(ApiResponse.error(40001, "参数错误"));
    }

    /** 未匹配到任何接口路径。 */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNotFound(NoResourceFoundException e) {
        return ResponseEntity.status(404).body(ApiResponse.error(40401, "接口或资源不存在"));
    }

    /** 其余未捕获异常：记日志（含堆栈，仅服务端可见），对外只给统一文案。 */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpected(Exception e) {
        log.error("未处理异常", e);
        return ResponseEntity.status(500).body(ApiResponse.error(50000, "服务器内部错误"));
    }
}
