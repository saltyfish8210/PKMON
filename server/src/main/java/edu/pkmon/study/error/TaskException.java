package edu.pkmon.study.error;

/**
 * 任务操作失败。HTTP 状态与业务码分开携带，控制器只做映射，不再判断业务规则。
 */
public final class TaskException extends RuntimeException {

    private static final long serialVersionUID = 1L;

    private final int httpStatus;
    private final int code;

    private TaskException(int httpStatus, int code, String message) {
        super(message);
        this.httpStatus = httpStatus;
        this.code = code;
    }

    /**
     * 资源不存在或不属于当前用户。
     *
     * @param message 说明
     * @return 40401 异常
     */
    public static TaskException notFound(String message) {
        return new TaskException(404, 40401, message);
    }

    /**
     * 参数错误。
     *
     * @param message 说明
     * @return 40001 异常
     */
    public static TaskException badRequest(String message) {
        return new TaskException(400, 40001, message);
    }

    /**
     * 同一请求编号携带了不同内容。
     *
     * @param message 说明
     * @return 40902 异常
     */
    public static TaskException requestConflict(String message) {
        return new TaskException(409, 40902, message);
    }

    /**
     * 当前状态不允许该操作。
     *
     * @param message 说明
     * @return 40903 异常
     */
    public static TaskException stateConflict(String message) {
        return new TaskException(409, 40903, message);
    }

    /**
     * 任务仍在冷却期。
     *
     * @param message 说明
     * @return 40904 异常
     */
    public static TaskException coolingDown(String message) {
        return new TaskException(409, 40904, message);
    }

    /**
     * HTTP 状态码。
     *
     * @return 状态码
     */
    public int httpStatus() {
        return httpStatus;
    }

    /**
     * 业务码。
     *
     * @return 业务码
     */
    public int code() {
        return code;
    }
}
