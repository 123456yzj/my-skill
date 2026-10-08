# 规则转换 skill 使用说明

入口为 [SKILL.md](SKILL.md)，正式名称为 `agent-rule-conversion`。只整理目标项目已有的 `.agents/corrections/rules.md`，提出具体规范文本、落点与加载方案，用户同意后落实并生成独立整合记录。

调用示例：

> 使用 agent-rule-conversion，整理已有纠错规则，按本项目现有规范提出整合方案，先在对话中让我确认。

配套 skill 为 `agent-correction`。将两个完整 skill 目录放入所用 AI 助手支持的技能目录，保留各自目录名和 `SKILL.md`。按助手要求刷新技能列表或重启，再按名称调用；也可直接让助手读取入口文件并执行。

输入相对于当前目标项目根目录，无输入时不创建文件。整合完成后记录保存在 `.agents/corrections/records/YYYYMMDD-HHmmss.md`，仅保留整合内容和整合位置。用户决定前不创建文件、计划或临时产物。

完整运行约定在本目录的 [SKILL.md](SKILL.md) 中，无外部文档依赖。
