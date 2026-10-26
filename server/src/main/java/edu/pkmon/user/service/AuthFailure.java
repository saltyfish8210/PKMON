package edu.pkmon.user.service;

/** Safe public errors. Internal exceptions, password hashes and bearer tokens never enter messages. */
public final class AuthFailure extends RuntimeException {
    public enum Kind {
        INVALID_INPUT(400, 40001, "参数不符合账号规则"),
        UNAUTHENTICATED(401, 40101, "账号或凭据无效，请重新登录"),
        USERNAME_TAKEN(409, 40901, "用户名已被使用"),
        UNAVAILABLE(503, 50301, "认证服务暂不可用，请稍后重试");

        public final int httpStatus;
        public final int code;
        public final String message;
        Kind(int httpStatus, int code, String message) {
            this.httpStatus = httpStatus; this.code = code; this.message = message;
        }
    }
    private final Kind kind;
    public AuthFailure(Kind kind) { super(kind.message); this.kind = kind; }
    public Kind kind() { return kind; }
}
