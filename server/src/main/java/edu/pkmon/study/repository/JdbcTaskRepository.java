package edu.pkmon.study.repository;

import edu.pkmon.study.domain.DwellState;
import edu.pkmon.study.domain.LocationSample;
import edu.pkmon.study.domain.PauseReason;
import edu.pkmon.study.domain.Region;
import edu.pkmon.study.domain.RejectionReason;
import edu.pkmon.study.domain.StudyTask;
import edu.pkmon.study.domain.TaskStatus;
import edu.pkmon.study.port.TaskRepository;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

/**
 * 任务存储的 JDBC 实现（胡豪，11/05 实现轮），对应 V2 迁移的
 * regions / study_tasks / location_samples 三表，字段与领域记录一一对应。
 *
 * <p>幂等语义由数据库约束兜底：重复开始靠 uk_study_tasks_start_request，
 * 重复样本靠 uk_location_samples_task_sample；冲突时回查已有记录并沿用，
 * 与内存实现的可观察行为一致。</p>
 */
public final class JdbcTaskRepository implements TaskRepository {

    private final JdbcTemplate db;

    public JdbcTaskRepository(JdbcTemplate db) {
        this.db = db;
    }

    private static final RowMapper<StudyTask> TASK = (rs, row) -> new StudyTask(
            rs.getString("task_id"),
            rs.getString("user_id"),
            rs.getString("region_id"),
            rs.getString("start_request_id"),
            rs.getString("location_source"),
            new DwellState(
                    rs.getString("task_id"),
                    TaskStatus.valueOf(rs.getString("status")),
                    rs.getString("pause_reason") == null ? null
                            : PauseReason.valueOf(rs.getString("pause_reason")),
                    rs.getLong("effective_seconds"),
                    rs.getLong("required_seconds"),
                    rs.getInt("inside_count"),
                    rs.getInt("outside_count"),
                    rs.getBoolean("chain_valid"),
                    toInstant(rs.getObject("last_accepted_at", OffsetDateTime.class)),
                    toInstant(rs.getObject("last_sampled_at", OffsetDateTime.class)),
                    (Double) rs.getObject("last_latitude"),
                    (Double) rs.getObject("last_longitude"),
                    rs.getBoolean("last_sample_inside"),
                    rs.getString("last_sample_id"),
                    rs.getBoolean("triggered")),
            rs.getObject("started_at", OffsetDateTime.class).toInstant(),
            toInstant(rs.getObject("ended_at", OffsetDateTime.class)),
            rs.getString("spawn_id"));

    private static final RowMapper<LocationSample> SAMPLE = (rs, row) -> new LocationSample(
            rs.getString("sample_id"),
            rs.getDouble("latitude"),
            rs.getDouble("longitude"),
            rs.getDouble("accuracy_meters"),
            rs.getObject("sampled_at", OffsetDateTime.class).toInstant(),
            rs.getString("coordinate_system"),
            rs.getString("source"));

    private static final RowMapper<Region> REGION = (rs, row) -> new Region(
            rs.getString("region_id"),
            rs.getDouble("center_latitude"),
            rs.getDouble("center_longitude"),
            rs.getDouble("enter_radius_meters"),
            rs.getDouble("exit_radius_meters"),
            rs.getBoolean("enabled"),
            rs.getString("coordinate_system"));

    @Override
    public Optional<StudyTask> findActiveByUser(String userId) {
        return db.query("select * from study_tasks where user_id = ? and status <> 'ENDED'",
                TASK, userId).stream().findFirst();
    }

    @Override
    public Optional<StudyTask> findById(String taskId) {
        return db.query("select * from study_tasks where task_id = ?", TASK, taskId)
                .stream().findFirst();
    }

    @Override
    public Optional<StudyTask> findByStartRequest(String userId, String requestId) {
        return db.query("select * from study_tasks where user_id = ? and start_request_id = ?",
                TASK, userId, requestId).stream().findFirst();
    }

    @Override
    public Optional<StudyTask> findLatestEnded(String userId, String regionId) {
        return db.query("select * from study_tasks where user_id = ? and region_id = ?"
                        + " and ended_at is not null order by ended_at desc limit 1",
                TASK, userId, regionId).stream().findFirst();
    }

    @Override
    public StudyTask insert(StudyTask task) {
        try {
            db.update("insert into study_tasks (task_id, user_id, region_id, start_request_id,"
                            + " location_source, status, pause_reason, effective_seconds, required_seconds,"
                            + " inside_count, outside_count, chain_valid, last_accepted_at, last_sampled_at,"
                            + " last_latitude, last_longitude, last_sample_inside, last_sample_id, triggered,"
                            + " started_at, ended_at, spawn_id)"
                            + " values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    task.taskId(), task.userId(), task.regionId(), task.startRequestId(),
                    task.locationSource(), task.state().status().name(), pauseReason(task),
                    task.state().effectiveSeconds(), task.state().requiredSeconds(),
                    task.state().insideCount(), task.state().outsideCount(), task.state().chainValid(),
                    utc(task.state().lastAcceptedAt()), utc(task.state().lastSampledAt()),
                    task.state().lastLatitude(), task.state().lastLongitude(),
                    task.state().lastSampleInside(), task.state().lastSampleId(),
                    task.state().triggered(), utc(task.startedAt()), utc(task.endedAt()),
                    task.spawnId());
            return task;
        } catch (DuplicateKeyException conflict) {
            // (userId, startRequestId) 唯一：并发重复开始时回查已有任务并沿用，不新建
            return findByStartRequest(task.userId(), task.startRequestId())
                    .orElseThrow(() -> conflict);
        }
    }

    @Override
    public void save(StudyTask task) {
        int updated = db.update("update study_tasks set status = ?, pause_reason = ?,"
                        + " effective_seconds = ?, required_seconds = ?, inside_count = ?,"
                        + " outside_count = ?, chain_valid = ?, last_accepted_at = ?, last_sampled_at = ?,"
                        + " last_latitude = ?, last_longitude = ?, last_sample_inside = ?, last_sample_id = ?,"
                        + " triggered = ?, ended_at = ?, spawn_id = ? where task_id = ?",
                task.state().status().name(), pauseReason(task),
                task.state().effectiveSeconds(), task.state().requiredSeconds(),
                task.state().insideCount(), task.state().outsideCount(), task.state().chainValid(),
                utc(task.state().lastAcceptedAt()), utc(task.state().lastSampledAt()),
                task.state().lastLatitude(), task.state().lastLongitude(),
                task.state().lastSampleInside(), task.state().lastSampleId(),
                task.state().triggered(), utc(task.endedAt()), task.spawnId(), task.taskId());
        if (updated == 0) {
            insert(task);
        }
    }

    @Override
    public Optional<Region> findRegion(String regionId) {
        return db.query("select * from regions where region_id = ?", REGION, regionId)
                .stream().findFirst();
    }

    @Override
    public Optional<LocationSample> findSample(String taskId, String sampleId) {
        return db.query("select * from location_samples where task_id = ? and sample_id = ?",
                SAMPLE, taskId, sampleId).stream().findFirst();
    }

    @Override
    public void saveSample(String taskId, LocationSample sample, boolean accepted,
            RejectionReason reason) {
        try {
            db.update("insert into location_samples (task_id, sample_id, latitude, longitude,"
                            + " accuracy_meters, sampled_at, coordinate_system, source, accepted,"
                            + " rejection_reason) values (?,?,?,?,?,?,?,?,?,?)",
                    taskId, sample.sampleId(), sample.latitude(), sample.longitude(),
                    sample.accuracyMeters(), utc(sample.sampledAt()), sample.coordinateSystem(),
                    sample.source(), accepted, reason == null ? null : reason.name());
        } catch (DuplicateKeyException alreadyRecorded) {
            // (taskId, sampleId) 唯一：重复样本只记录一次，内容比较在 service 层完成
        }
    }

    private static String pauseReason(StudyTask task) {
        return task.state().pauseReason() == null ? null : task.state().pauseReason().name();
    }

    private static OffsetDateTime utc(Instant time) {
        return time == null ? null : time.atOffset(ZoneOffset.UTC);
    }

    private static Instant toInstant(OffsetDateTime time) {
        return time == null ? null : time.toInstant();
    }
}
