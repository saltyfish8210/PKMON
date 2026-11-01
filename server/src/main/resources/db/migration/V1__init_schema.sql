-- V1 初始结构：第二阶段最小持久化范围（用户 / 会话 / 精灵种类 / 题目 / 遭遇 / 挑战 / 作答 / 收录）
-- 归属：迁移由胡豪统一编号与提交；已经应用的迁移不改写，后续变更走 V2+ 增量迁移。
-- 约定：实体 ID 统一为 UUID 字符串（VARCHAR(36)）；时间统一 UTC TIMESTAMP WITH TIME ZONE；
--       字段命名 lower_snake_case。对应 docs/stage2/members/huhao/design/design.txt 第 5、6 节。
-- 本版暂不建 study_tasks / location_samples：驻留字段待董欣毓、赵冠钧定稿后以 V2 增补
-- （见 design/questions.csv Q05）。

CREATE TABLE users (
    user_id       VARCHAR(36) PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL,
    password_hash VARCHAR(100) NOT NULL,   -- 只存加盐散列（BCrypt），不存明文
    nickname      VARCHAR(64)  NOT NULL,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uk_users_username UNIQUE (username)
);

CREATE TABLE auth_sessions (
    session_id   VARCHAR(36) PRIMARY KEY,
    user_id      VARCHAR(36)  NOT NULL REFERENCES users (user_id),
    token_digest VARCHAR(128) NOT NULL,    -- 只存 token 摘要，不存明文 token
    issued_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at   TIMESTAMP WITH TIME ZONE, -- 撤销不删除历史
    CONSTRAINT uk_auth_sessions_token_digest UNIQUE (token_digest)
);

CREATE TABLE species (
    species_id     VARCHAR(36) PRIMARY KEY,
    business_key   VARCHAR(64) NOT NULL,   -- 固定业务键，如 siege_lion
    catalog_number INT,
    name           VARCHAR(64)   NOT NULL,
    description    VARCHAR(1024),
    image_key      VARCHAR(128),
    CONSTRAINT uk_species_business_key UNIQUE (business_key)
);

CREATE TABLE questions (
    question_id       VARCHAR(36) PRIMARY KEY,
    species_id        VARCHAR(36)  NOT NULL REFERENCES species (species_id),
    business_key      VARCHAR(64)  NOT NULL, -- 固定业务键，如 hello_world_001
    question_text     VARCHAR(1024) NOT NULL,
    options_json      CLOB         NOT NULL, -- [{optionId,text},...]
    correct_option_id VARCHAR(36)  NOT NULL, -- 仅服务端判题可见，不下发客户端
    CONSTRAINT uk_questions_business_key UNIQUE (business_key)
);

CREATE TABLE spawns (
    spawn_id    VARCHAR(36) PRIMARY KEY,
    user_id     VARCHAR(36) NOT NULL REFERENCES users (user_id),
    species_id  VARCHAR(36) NOT NULL REFERENCES species (species_id),
    region_id   VARCHAR(64) NOT NULL,    -- 固定业务键，如 library_entrance
    source_type VARCHAR(32) NOT NULL,    -- DEV_SIMULATED / LOCATION 等
    expires_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE challenges (
    challenge_id VARCHAR(36) PRIMARY KEY,
    spawn_id     VARCHAR(36) NOT NULL REFERENCES spawns (spawn_id),
    question_id  VARCHAR(36) NOT NULL REFERENCES questions (question_id),
    status       VARCHAR(16) NOT NULL,   -- OPEN / CAPTURED / EXPIRED
    expires_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uk_challenges_spawn UNIQUE (spawn_id)  -- 一次遭遇最多一个进行中的挑战
);

CREATE TABLE answer_attempts (
    attempt_id   VARCHAR(36) PRIMARY KEY,
    challenge_id VARCHAR(36) NOT NULL REFERENCES challenges (challenge_id),
    request_id   VARCHAR(36) NOT NULL,   -- 幂等键：客户端重试沿用同一 requestId
    option_id    VARCHAR(36) NOT NULL,
    result       VARCHAR(8)  NOT NULL,   -- CORRECT / WRONG
    submitted_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uk_answer_attempts_request UNIQUE (request_id)
);

CREATE TABLE capture_records (
    record_id    VARCHAR(36) PRIMARY KEY,
    user_id      VARCHAR(36) NOT NULL REFERENCES users (user_id),
    species_id   VARCHAR(36) NOT NULL REFERENCES species (species_id),
    spawn_id     VARCHAR(36) NOT NULL REFERENCES spawns (spawn_id),
    challenge_id VARCHAR(36) NOT NULL REFERENCES challenges (challenge_id),
    captured_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    -- 同一遭遇对同一用户最多收录一次：防重复点击 / 网络重试造成重复发奖
    CONSTRAINT uk_capture_user_spawn UNIQUE (user_id, spawn_id)
);
