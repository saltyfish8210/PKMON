package edu.pkmon.capture.port;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.pkmon.capture.domain.Question;
import java.io.IOException;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ThreadLocalRandom;

public final class FixtureCatalog implements QuestionSource, SpeciesCatalog {
    public record Catalog(List<Species> species, List<Question> questions) {}
    private final Catalog catalog;

    public FixtureCatalog() {
        try (var input = FixtureCatalog.class.getResourceAsStream("/catalog/stage4.json")) {
            catalog = new ObjectMapper().readValue(input, Catalog.class);
        } catch (IOException error) {
            throw new IllegalStateException("无法读取物种目录", error);
        }
    }

    public Optional<Question> draw(String speciesId, List<String> recent) {
        var nativePool = catalog.questions().stream().filter(question -> question.speciesId().equals(speciesId)).toList();
        if (nativePool.isEmpty()) return Optional.empty();
        if (recent.isEmpty()) return Optional.of(nativePool.get(0));
        var available = nativePool.stream().filter(question -> !recent.contains(question.questionId())).toList();
        if (available.isEmpty()) available = catalog.questions().stream().filter(question -> !recent.contains(question.questionId())).toList();
        return Optional.of(available.get(ThreadLocalRandom.current().nextInt(available.size())));
    }

    public Optional<Question> findById(String questionId) {
        return catalog.questions().stream().filter(question -> question.questionId().equals(questionId)).findFirst();
    }

    public Optional<Species> details(String speciesId) {
        return catalog.species().stream().filter(item -> item.speciesId().equals(speciesId)).findFirst();
    }
    public Optional<String> nameOf(String speciesId) { return details(speciesId).map(Species::name); }
    public int totalSpeciesCount() { return catalog.species().size(); }
    public List<String> allSpeciesIds() { return catalog.species().stream().map(Species::speciesId).toList(); }
}
