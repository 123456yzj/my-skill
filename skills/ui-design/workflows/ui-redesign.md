# 现有界面重组需求设计

适用于整体调整现有界面的信息组织、布局或操作路径。先区分体验问题与技术性能问题，技术迁移本身不自动要求改变界面。

## 输入

现有页面、源码、截图或操作反馈，以及用户目标、相关数据与业务契约。记录当前可用操作、实体身份、权限、校验与提交行为。

## 步骤

1. **现状诊断**：读取 [ui-analysis](../methods/ui-analysis.md)，指出可定位的查找、比较、操作或恢复问题。只从源码得到的结论标明为推断。
2. **信息重组**：读取 [information-architecture](../methods/information-architecture.md) 与 [UX 原则](../design-system/UX_PRINCIPLES.md)，明确保留、调整的信息及操作。保留独立实体与提交边界。
3. **路径选择**：按需读取 [ux-architecture](../methods/ux-architecture.md)。解释方案如何改善当前任务及其代价，不预设布局或优胜方案。
4. **视觉与状态要求**：按需读取 [visual-system-designer](../methods/visual-system-designer.md)、[clean-ui-taste](../methods/clean-ui-taste.md) 和 [design-system-builder](../methods/design-system-builder.md)。用项目设计系统表达层级和边界，状态语义保持一致。
5. **变更说明**：使用 [requirement-handoff](../methods/requirement-handoff.md)，按功能给出“当前行为 → 期望行为”，明确入口、联动、状态和返回上下文；未改业务行为作为相关回归依据。
6. **交付与验收**：按 [需求说明模板](../templates/requirements.template.md) 汇总，准备新行为、保留能力、错误恢复及受影响适配场景。
7. **说明复核**：按 [design-quality-gate](../methods/design-quality-gate.md) 检查业务一致性、范围和验收覆盖。实际代码与测试任务由接收方执行。

## 交付检查

- 对象身份、操作后果、权限、校验及提交边界有无无意改变。
- 默认可见信息与跨项比较是否合理，必要操作是否仍可发现。
- 布局取舍是否有任务依据，是否扩大到无关部分。
- 原有链接、筛选、定位和未保存状态的保留或变化是否明确。
- 前端能否按条目实施，验收能否检查新行为和必要回归。

有关键业务歧义时标记受影响条目待确认；已有明确依据的独立部分继续整理。复核实现时依据实际证据指出差异，不以外观相似或虚构评分判定完成。
