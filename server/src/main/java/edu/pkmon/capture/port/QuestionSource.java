package edu.pkmon.capture.port;

import edu.pkmon.capture.domain.Question;

import java.util.Optional;

/** 取题端口。题库由他人主责，本模块只读；测试用替身，生产接真实题库。 */
public interface QuestionSource {

    Optional<Question> draw(String speciesId, java.util.List<String> recent);
    Optional<Question> findById(String questionId);
}
