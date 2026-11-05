-- V2 自习任务驻留持久化：regions / study_tasks / location_samples
-- 归属：迁移由胡豪统一编号与提交；已经应用的迁移不改写。
-- 依据：docs/stage2/members/dongxinyu/design/interfaces.json（2026-11-01 定稿，表名记录为
--       study_task/task_sample，本迁移采用本人 design.txt 第 6 节的复数命名
--       study_tasks/location_samples，与 V1 风格一致）；
--       edu.pkmon.study.domain.StudyTask / DwellState / LocationSample 的字段一一落列。
-- 命名与类型约定同 V1：UUID 字符串 VARCHAR(36)；时间 UTC TIMESTAMP WITH TIME ZONE。

-- 可驻留区域。当前只有演示区域 library_entrance，中心点为候选值（39.9042, 116.4074），
-- 未经真机验证，页面须标注模拟；真机确认后由后续增量迁移修正，不改写本迁移。
CREATE TABLE regions (
    region_id           VARCHAR(64) PRIMARY KEY,   -- 业务键，如 library_entrance
    center_latitude     DOUBLE       NOT NULL,     -- GCJ02
    center_longitude    DOUBLE       NOT NULL,
    enter_radius_meters DOUBLE       NOT NULL,     -- 进入半径（米）
    exit_radius_meters  DOUBLE       NOT NULL,     -- 退出半径（米），不小于进入半径
    enabled             BOOLEAN      NOT NULL,
    coordinate_system   VARCHAR(16)  NOT NULL      -- GCJ02 / WGS84，样本坐标系需一致
);

INSERT INTO regions (region_id, center_latitude, center_longitude,
                     enter_radius_meters, exit_radius_meters, enabled, coordinate_system)
VALUES ('library_entrance', 39.9042, 116.4074, 80.0, 100.0, TRUE, 'GCJ02');

-- 自习任务：任务级元数据 + DwellState 驻留评估状态快照。
-- spawn_id 暂不建外键：董欣毓模块当前经 StubSpawnGateway 只生成编号，孙虹毅的
-- SpawnService 真实接入前 spawns 表中没有对应行；接入后由后续迁移补外键。
CREATE TABLE study_tasks (
    task_id           VARCHAR(36) PRIMARY KEY,
    user_id           VARCHAR(36)  NOT NULL REFERENCES users (user_id),
    region_id         VARCHAR(64)  NOT NULL REFERENCES regions (region_id),
    start_request_id  VARCHAR(36)  NOT NULL,   -- 幂等键：重复开始沿用同一 requestId
    location_source   VARCHAR(16)  NOT NULL,   -- GPS / SIMULATED
    status            VARCHAR(16)  NOT NULL,   -- WAITING/DWELLING/PAUSED/TRIGGERED/ENDED
    pause_reason      VARCHAR(16),             -- OUTSIDE / NO_SIGNAL；仅 PAUSED 时非空
    effective_seconds BIGINT       NOT NULL,   -- 已认可有效停留秒数，服务端权威
    required_seconds  BIGINT       NOT NULL,   -- 触发阈值，创建时写入
    inside_count      INT          NOT NULL,   -- 连续合格样本数（进入/恢复判定）
    outside_count     INT          NOT NULL,   -- 连续越界样本数
    chain_valid       BOOLEAN      NOT NULL,   -- 是否处于已确认的累计链
    last_accepted_at  TIMESTAMP WITH TIME ZONE,
    last_sampled_at   TIMESTAMP WITH TIME ZONE,
    last_latitude     DOUBLE,
    last_longitude    DOUBLE,
    last_sample_inside BOOLEAN     NOT NULL,
    last_sample_id    VARCHAR(36),
    triggered         BOOLEAN      NOT NULL,   -- 是否已触发过遭遇（一次性触发）
    started_at        TIMESTAMP WITH TIME ZONE NOT NULL,
    ended_at          TIMESTAMP WITH TIME ZONE,
    spawn_id          VARCHAR(36),             -- 触发后生成的遭遇编号
    -- 同一用户的重复开始请求幂等：数据库约束兜底，不只靠客户端禁用按钮
    CONSTRAINT uk_study_tasks_start_request UNIQUE (user_id, start_request_id)
);

-- 当前任务查询（status <> 'ENDED'）与冷却判定（同用户同区域最近结束）走索引
CREATE INDEX idx_study_tasks_user_status ON study_tasks (user_id, status);
CREATE INDEX idx_study_tasks_user_region_ended ON study_tasks (user_id, region_id, ended_at);

-- 位置样本：采纳与拒收都落库，拒收原因随接口 sampleAccepted=false 返回。
-- 真实位置属于敏感数据：不进日志、不进截图，仅库存储。
CREATE TABLE location_samples (
    task_id           VARCHAR(36)  NOT NULL REFERENCES study_tasks (task_id),
    sample_id         VARCHAR(36)  NOT NULL,   -- 客户端生成，任务内唯一
    latitude          DOUBLE       NOT NULL,   -- GCJ02
    longitude         DOUBLE       NOT NULL,
    accuracy_meters   DOUBLE       NOT NULL,
    sampled_at        TIMESTAMP WITH TIME ZONE NOT NULL,
    coordinate_system VARCHAR(16)  NOT NULL,   -- 接口候选只接受 GCJ02
    source            VARCHAR(16)  NOT NULL,   -- GPS / SIMULATED
    accepted          BOOLEAN      NOT NULL,
    rejection_reason  VARCHAR(32),             -- RejectionReason 枚举名，采纳时为空
    received_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- 同一任务内 sampleId 唯一：重复样本只记录一次，内容比较在 service 层
    CONSTRAINT uk_location_samples_task_sample UNIQUE (task_id, sample_id)
);
