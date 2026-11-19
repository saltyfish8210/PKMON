-- V4 自习任务演示用占位精灵：study_spirit / study_spirit_001
-- 归属：课堂演示占位内容，不是正式美术资源（立绘为 assets/sprites/spirit_placeholder.png）。
-- 目的：让"在地图上开自习任务 → 驻留达标 → 遇见自习精灵 → 答题 → 收录"这条链路
--       演示到的物种与地图上的占位精灵一致，避免地图显示自习精灵、答题页却写攻城狮。

INSERT INTO species (species_id, business_key, catalog_number, name, description, image_key)
VALUES ('study_spirit', 'study_spirit', 2, '自习精灵',
        '自习精灵：站在图书馆门口陪你上自习的占位精灵，题目围绕自习与专注。', 'spirit_placeholder');

INSERT INTO questions (question_id, species_id, business_key, question_text, options_json, correct_option_id)
VALUES ('study_spirit_001', 'study_spirit', 'study_spirit_001',
        '连续学习 25 分钟后休息 5 分钟，这种时间管理方法通常叫什么？',
        '[{"optionId":"A","text":"番茄工作法"},'
        || '{"optionId":"B","text":"康奈尔笔记法"},'
        || '{"optionId":"C","text":"费曼学习法"}]',
        'A');
