-- V3 题库与图鉴种子：siege_lion / hello_world_001
-- 归属：领域内容由孙虹毅负责（capture/port/FixtureCatalog.java 为当前权威来源），
--       本迁移只负责把同一内容装载入库；扩充题库属于后续范围，不算本次完成项。
-- 实体 ID 直接沿用业务键，与 FixtureCatalog 的内存目录保持一致，便于后续切换读取来源。
-- correct_option_id 仅服务端判题可见，任何接口不得下发（见 V1 注释与接口约定）。

INSERT INTO species (species_id, business_key, catalog_number, name, description, image_key)
VALUES ('siege_lion', 'siege_lion', 1, '攻城狮',
        '攻城狮：PKMon 第二阶段示例精灵，题目围绕编程入门。', NULL);

INSERT INTO questions (question_id, species_id, business_key, question_text, options_json, correct_option_id)
VALUES ('hello_world_001', 'siege_lion', 'hello_world_001',
        '执行 print("hello world") 之后，控制台会输出什么？',
        '[{"optionId":"A","text":"hello world"},'
        || '{"optionId":"B","text":"\"hello world\"（连引号一起输出）"},'
        || '{"optionId":"C","text":"什么都不输出，只是定义了一个字符串"}]',
        'A');
