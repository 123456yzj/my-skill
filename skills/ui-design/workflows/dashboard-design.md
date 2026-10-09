# 看板功能与体验设计

适用于指标、趋势、监控、告警及下钻任务。需求说明应让前端明确各区域的展示和联动，让测试能核对数据含义及操作结果。

## 输入

目标用户、监控或比较任务、指标来源与口径、时间范围、已确认异常阈值、刷新方式和权限。缺少依据的阈值与下钻能力列为待确认。

## 步骤

1. **任务与指标契约**：用 [data-ui-designer](../methods/data-ui-designer.md) 明确每项指标回答的问题，核对单位、聚合、更新时间与异常含义。
2. **区域与信息组织**：用 [information-architecture](../methods/information-architecture.md) 组织总览、主要视图、异常和明细。按任务决定并列比较、重点关注及小屏排列。
3. **交互与联动**：按需用 [ux-architecture](../methods/ux-architecture.md)，定义筛选影响范围、图表选择、下钻条件、刷新时保留行为及返回上下文。
4. **视觉与状态**：用 [visual-system-designer](../methods/visual-system-designer.md) 说明图例、异常与选中语义，区分加载、无数据、失败、无权限和过期。图表按数据关系选用，避免仅为装饰填充。
5. **交付**：用 [requirement-handoff](../methods/requirement-handoff.md) 和 [需求说明模板](../templates/requirements.template.md) 汇总功能、数据映射与验收场景。可将 [看板模板](../templates/dashboard-design.template.md) 纳入相关章节。
6. **复核**：用 [design-quality-gate](../methods/design-quality-gate.md) 检查口径、区域、联动和边界是否足够明确。

## 验收任务重点

- 指标数值、单位、时间范围、来源和更新时间可辨，并能对照契约核对。
- 刷新、筛选和下钻的影响范围明确，返回后上下文按约定恢复。
- 异常依据真实阈值，选中态不冒充异常，颜色有文字或形状补充。
- 过期、无数据、请求失败与无权限的提示不同，恢复入口明确。
- 图表、长标签、完整数值和必要操作在相关视口及键盘/触屏下可访问。
- 仅检查项目支持的主题与设备，未执行的任务保持为待验证。
