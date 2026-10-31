package edu.pkmon.common.api;

/**
 * 统一响应信封：成功 {"code":0,"message":"ok","data":{...}}，
 * 失败 {"code":40001,"message":"参数错误","data":null}（接口约定 pkmon-stage2-candidate）。
 * 新模块（user/study 等）统一使用本类型；capture 模块历史代码使用同构的
 * CaptureDtos.ApiEnvelope，字段名与语义一致，后续可平滑收敛。
 */
public record ApiResponse<T>(int code, String message, T data) {

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(0, "ok", data);
    }

    public static <T> ApiResponse<T> error(int code, String message) {
        return new ApiResponse<>(code, message, null);
    }
}
