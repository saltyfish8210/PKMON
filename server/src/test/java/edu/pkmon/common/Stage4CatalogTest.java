package edu.pkmon.common;

import com.fasterxml.jackson.databind.ObjectMapper;
import edu.pkmon.capture.port.FixtureCatalog;
import edu.pkmon.demo.PkmonApplication;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(classes = PkmonApplication.class)
class Stage4CatalogTest {
    @Autowired JdbcTemplate db;
    @Autowired FixtureCatalog catalog;
    @Test void everyMigratedRowMatchesTheRuntimeCatalog() throws Exception {
        var mapper = new ObjectMapper();
        assertEquals(8, catalog.totalSpeciesCount());
        assertEquals(8, db.queryForObject("select count(*) from species", Integer.class));
        assertEquals(30, db.queryForObject("select count(*) from questions", Integer.class));
        for (String id : catalog.allSpeciesIds()) {
            var species = catalog.details(id).orElseThrow();
            var row = db.queryForMap("select * from species where species_id=?", id);
            assertEquals(species.catalogNumber(), row.get("catalog_number"));
            assertEquals(species.name(), row.get("name"));
            assertEquals(species.description(), row.get("description"));
            assertEquals(species.imageKey(), row.get("image_key"));
            assertTrue(db.queryForObject("select count(*) from questions where species_id=?", Integer.class, id) >= 3);
        }
        for (var row : db.queryForList("select * from questions")) {
            var question = catalog.findById((String)row.get("question_id")).orElseThrow();
            assertEquals(question.speciesId(), row.get("species_id"));
            assertEquals(question.questionText(), row.get("question_text"));
            assertEquals(question.correctOptionId(), row.get("correct_option_id"));
            assertEquals(mapper.valueToTree(question.options()), mapper.readTree((String)row.get("options_json")));
        }
    }
}
