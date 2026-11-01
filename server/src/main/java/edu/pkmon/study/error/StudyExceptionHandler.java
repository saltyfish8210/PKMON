package edu.pkmon.study.error;

import edu.pkmon.common.api.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 本模块业务错误的响应映射。只处理 study 控制器抛出的 {@link TaskException}，
 * 其余异常交给 common 的全局兜底，避免影响其他模块。
 */
@RestControllerAdvice
public class StudyExceptionHandler {

    /**
     * 业务错误：HTTP 状态与业务码来自异常本身，响应体仍用统一信封。
     *
     * @param e 业务异常
     * @return 统一信封响应
     */
    @ExceptionHandler(TaskException.class)
    public ResponseEntity<ApiResponse<Void>> handle(TaskException e) {
        return ResponseEntity.status(e.httpStatus()).body(ApiResponse.error(e.code(), e.getMessage()));
    }
}
