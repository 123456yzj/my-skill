# 纠错 skill 使用说明

入口为 [SKILL.md](SKILL.md)，正式名称为 `agent-correction`。用于理解纠错场景、检查已有规范，并向用户提交可保存的规则。用户同意具体规则后才写入目标项目的 `.agents/corrections/rules.md`。

调用示例：

> 使用 agent-correction，把刚才的纠正整理成场景规则，先检查已有规范，在对话中让我确认。

配套 skill 为 `agent-rule-conversion`。将两个完整 skill 目录放入所用 AI 助手支持的技能目录，保留各自目录名和 `SKILL.md`。按助手要求刷新技能列表或重启，再按名称调用；也可直接让助手读取入口文件并执行。

所有运行数据相对于当前目标项目根目录。每条规则依次使用 `SCN`、`RSN`、`CNT`、`TIME`，时间格式为 `YYYY-MM-DD HH:mm:ss`。用户决定前不创建文件、计划或临时产物。

完整运行约定在本目录的 [SKILL.md](SKILL.md) 中，无外部文档依赖。
