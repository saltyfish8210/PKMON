package edu.pkmon.user.web;

import edu.pkmon.common.api.ApiResponse;
import edu.pkmon.user.service.AuthFailure;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
public class AccountErrors {
    @ExceptionHandler(AuthFailure.class)
    public ResponseEntity<ApiResponse<Void>> handle(AuthFailure failure) {
        var kind = failure.kind();
        return ResponseEntity.status(kind.httpStatus).body(ApiResponse.error(kind.code, kind.message));
    }
}
