package edu.pkmon.capture.port;

import edu.pkmon.capture.domain.Question;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 题库与物种目录的开发期固定数据，同时作为题库/图鉴种子内容的来源。
 *
 * 分工（见 docs/stage2/project/decisions.csv「题库职责」）：领域内容与读取由孙虹毅负责，
 * 种子数据的装载与迁移由胡豪负责，闫昕协调。
 * 当前只有 1 种精灵（siege_lion）与 1 道题（hello_world_001）；扩充属于后续范围，
 * 不得报告为已完成。
 */
public final class FixtureCatalog implements QuestionSource, SpeciesCatalog {

    private static final Question HELLO_WORLD = new Question(
            "hello_world_001",
            "siege_lion",
            "执行 print(\"hello world\") 之后，控制台会输出什么？",
            List.of(
                    new Question.OptionValue("A", "hello world"),
                    new Question.OptionValue("B", "\"hello world\"（连引号一起输出）"),
                    new Question.OptionValue("C", "什么都不输出，只是定义了一个字符串")),
            "A");

    private static final Map<String, String> SPECIES_NAMES = Map.of("siege_lion", "攻城狮");

    private static final Map<String, Question> QUESTIONS = Map.of("siege_lion", HELLO_WORLD);

    @Override
    public Optional<Question> findBySpeciesId(String speciesId) {
        return Optional.ofNullable(QUESTIONS.get(speciesId));
    }

    @Override
    public Optional<String> nameOf(String speciesId) {
        return Optional.ofNullable(SPECIES_NAMES.get(speciesId));
    }

    @Override
    public int totalSpeciesCount() {
        return SPECIES_NAMES.size();
    }
}
