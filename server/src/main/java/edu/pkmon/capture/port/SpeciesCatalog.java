package edu.pkmon.capture.port;

import java.util.List;
import java.util.Optional;

/**
 * 物种目录端口。图鉴与物种归属他人主责，本模块只读。
 *
 * <p>第三阶段新增 {@link #allSpeciesIds()}，用于图鉴页列出"全部种类"，
 * 无此方法时只能给出已收种类计数，无法展示未收条目。
 */
public interface SpeciesCatalog {

    record Species(String speciesId, int catalogNumber, String name, String description, String imageKey) {}

    Optional<Species> details(String speciesId);

    Optional<String> nameOf(String speciesId);

    int totalSpeciesCount();

    /** 目录中的全部物种标识，顺序稳定（按目录序号或字典序），用于图鉴逐条展示。 */
    List<String> allSpeciesIds();
}
