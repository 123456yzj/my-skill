---
name: cloudflare-ip-test
description: Cloudflare IPv4 优选 IP、CloudflareSpeedTest、HKG/NRT 节点筛选与本机访问延迟测试。Use when the user asks to find or compare Cloudflare IPv4 edge IPs for a domain, verify colo, or benchmark candidate IPs at least 20 times.
compatibility: Windows with PowerShell 7 and curl.exe; CloudflareSpeedTest for candidate discovery.
---

# Cloudflare 优选 IP 测试

从用户实际使用的机器和网络出口筛选 Cloudflare IP，针对用户域名验证 HTTPS、节点与延迟。默认每个候选至少复测 20 次，保留原始数据，按实测结果推荐。

首次使用的环境准备、工具下载、命令示例和故障排查见同目录的 [README.md](README.md)。先确认 Windows、PowerShell 7、`curl.exe`、目标域名 trace 可用，以及本机可直连候选 IP 的 HTTPS 端口。已有候选只需复测脚本；发现候选另需 CloudflareSpeedTest。

## 默认行为

- 用户仅要求测试时，完成筛选和报告；修改 hosts、DNS、代理配置需已有明确授权。不要因技能流程重复询问已有授权。
- 默认使用当前机器直连路径，curl 添加 `--noproxy "*"`。附带脚本仅用于直连；VPN/TUN 仍可能影响出口。代理分支先确认代理类型、地址、域名解析方和是否允许固定目标 IP，再按 README 的“代理测试分支”执行并独立报告。
- 默认每个 IP 20 次；用户指定更多次数时按指定次数执行。
- 仅测试 IPv4：DNS 查询使用 A 记录，CloudflareSpeedTest 使用 IPv4 列表 `ip.txt`，curl 添加 `-4`。输入须为四段十进制 IPv4，每段 0～255；脚本去除首尾空白、按十进制去掉前导零再去重，拒绝 IPv6、短写、十六进制和空值。
- 用实际域名保留 Host、SNI、TLS 证书校验，禁止用 `-k` 掩盖失败。固定连接 IP 用 `--resolve`。
- 每次复测单独启动 curl，新建 HTTPS 连接。至少报告平均值、中位数、P95、最大值、成功数、超时数及节点。
- 地区筛选基于实际返回的 `colo` 或 `CF-RAY`，不能凭 IP 所属地区推断。香港为 HKG，东京为 NRT，新加坡为 SIN，洛杉矶为 LAX。
- 不把旧测试地址的历史表现当作当前结论；Anycast IP 的路由和节点可能变化。

## 输入确认与失败降级

执行前简短确认：实际主机名、直连或代理、期望节点（不限制也需说明）、候选及当前 IP、每 IP 次数（至少 20）、超时和结果目录。已提供的信息直接采用；缺少主机名或代理关键参数时先补齐。未指定时采用直连、20 次、5 秒、现有临时目录，明确告知默认值。

- 工具缺失：已有候选时跳过扫描直接复测；无候选则报告阻碍及安装步骤，不虚构扫描结果。
- 基线失败：有可连候选则继续候选 GET；所有候选 GET 不可用时记录失败并排查网络/trace，不用 HEAD 成功替代 GET 验证。
- 扫描无候选：低并发、不限节点复核校准；仍为空则报告抽样范围和限制，可复测已有候选，不断言目标地区不可达。
- 超时/连接失败：保留每次失败并继续采样，不无限重试。写 CSV 失败等本地错误应停止并报告；中断时仅报告已完成原始样本，完成每 IP 至少 20 次前不给最终排名。
- 零成功、节点均不符合或结果无明显优势：不推荐替换当前地址；说明原因，必要时在其他时段复测。

## 1. 检查基线

先告知用户正在检查当前解析及访问路径。使用系统解析和实际访问一起确认；系统 DNS 查询和 curl 的连接 IP 可能不同。

```powershell
Resolve-DnsName www.example.com -Type A
[System.Net.Dns]::GetHostAddresses('www.example.com') |
  Where-Object AddressFamily -EQ ([System.Net.Sockets.AddressFamily]::InterNetwork)
curl.exe -4 --noproxy "*" -sS --max-time 8 `
  -w "`nremote_ip=%{remote_ip} code=%{http_code} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total}`n" `
  https://www.example.com/cdn-cgi/trace
```

`www.example.com` 是占位示例，执行前须替换为用户实际使用 Cloudflare 的目标域名；示例域名本身不保证支持 trace。记录 CNAME 链、全部 A 地址、实际 remote_ip、HTTP 状态、colo 和时间。存在 hosts 时只读取相关映射，不在报告中展示无关条目。多个 A 记录可能让客户端选到不同节点。

## 2. 准备 CloudflareSpeedTest

先查找现有工具，可使用 `$env:TEMP\cloudflare-ip-test\cfst` 作为缓存目录，通过所用助手的文件搜索工具确认。不存在时：

1. 查询 `https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest`。
2. 根据实际系统架构选择官方发布文件，保存到临时目录；创建输出前验证父目录。
3. GitHub 下载页失败时使用发布接口中资产的 `url`，加 `Accept: application/octet-stream`。下载可用 `curl.exe -fL -C -` 续传；单次限制约 55 秒，避免失去进度反馈。
4. 下载完成后用 `Get-FileHash -Algorithm SHA256` 和资产 `digest` 对照；存在摘要时不匹配则不要执行。没有发布摘要时如实说明来源与校验范围。
5. 解压后先运行 `cfst.exe -h`，以当前版本帮助确认参数。无需添加 PATH 或全局安装。

## 3. 先校准，再扫描

**先用 2～3 个已知可连地址做不限制地区的对照测试，并开启 `-debug`。** 确认工具能识别实际节点后再批量筛选。

CloudflareSpeedTest v2.3.5 的 HTTPing 使用 HEAD 请求，单次超时约 2 秒。`/cdn-cgi/trace` 的 GET 成功，不代表 HEAD 也返回 200。HEAD 可能返回 404 或 403，但仍包含可识别的 Cloudflare 节点；必须按当前目标实际校准。

```powershell
$targetDomain = Read-Host '请输入实际目标域名，例如 www.example.com'
.\cfst.exe -httping -url "https://$targetDomain/cdn-cgi/trace" `
  -ip '162.159.38.138,162.159.44.49' `
  -n 1 -t 2 -dd -p 0 -debug -o control.csv
```

若调试明确显示 HEAD 状态码不符合默认值，可设置本轮实际验证过的 `-httping-code`（例如 404）。这只用于边缘节点筛选；候选必须再用 GET 验证 HTTP 200 和证书。不要跨域名、跨版本盲目固定 404。也可以改用已校准可用的测速 URL，最后再验证目标域名。

从调试结果输入本轮实际 HEAD 状态码，带该值重复对照测试，确认能识别节点后再扫描。以下命令与 README 一致，在工具解压目录执行；新终端须重新确认变量。

```powershell
[int]$headStatus = Read-Host '请输入本轮调试确认的 HEAD 状态码'
if ($headStatus -lt 100 -or $headStatus -gt 599) { throw '无效 HTTP 状态码' }
.\cfst.exe -httping -url "https://$targetDomain/cdn-cgi/trace" `
  -ip '162.159.38.138,162.159.44.49' -httping-code $headStatus `
  -n 1 -t 2 -dd -p 0 -debug -o control.csv
# 对照测试确认节点识别成功后执行；只找香港可改为 -cfcolo HKG。
.\cfst.exe -httping -url "https://$targetDomain/cdn-cgi/trace" `
  -httping-code $headStatus -cfcolo HKG,NRT `
  -n 20 -t 2 -dd -p 0 -o candidates.csv
```

- 默认 IP 列表对每个 /24 随机抽一个地址；必须报告实际测试数量与范围，不能称为所有 Cloudflare IP。
- 优先使用温和并发 20～60。扫描耗时超出工具执行时限时拆分 `-ip` 网段；不要为了赶进度无限提高并发。高并发可能造成超时、漏筛和延迟失真。
- 使用 `-p 0` 避免测速结束后等待回车。后台执行必须确认进程仍在运行，并检查最终 CSV 或完整结束日志；不能把进程启动当作完成。
- 每约 60 秒给出真实进度，不要仅声称“仍在运行”。进程被终止时说明该轮未完成。
- HKG 为 0 时，检查校准、超时和并发。做低并发、不限制节点的对照测试，再报告“本轮抽样未找到 HKG”。不能断言香港不可达。
- 需要更多候选时可细扫当前表现好的 /24，使用 `-allip`，并说明这是候选网段扫描。`162.159.38.0/24`、`162.159.39.0/24`、`162.159.44.0/24`、`162.159.45.0/24` 可作为公共 Cloudflare 候选网段示例，实际节点须在用户线路上重新验证。

## 4. 每个候选至少 20 次复测

使用本技能附带的 `scripts/Measure-CloudflareIp.ps1`。默认串行轮询各候选，每轮轮换测试顺序，减少不同测试时段和并发竞争带来的偏差。提供全部候选及当前使用的 IP。

以下示例从本 skill 的根目录执行；AI 助手应根据实际 skill 路径定位脚本。

```powershell
& '.\scripts\Measure-CloudflareIp.ps1' `
  -Domain www.example.com `
  -IPs @('162.159.38.138','162.159.44.49','162.159.44.238') `
  -Samples 20 -ExpectedColos @('NRT','HKG') `
  -OutputDirectory $env:TEMP
```

输出目录须已存在。脚本逐次保存原始 CSV，最后生成汇总 CSV 并显示表格。保留失败样本；平均值和分位数只统计成功请求，同时报告失败、超时及地区不符数量。P95 使用 nearest-rank，即升序排列后的第 `ceil(0.95 × 成功数)` 项。

时间单位为毫秒：TCP 从开始到连接完成，TLS 从开始到握手完成（包含 TCP），Total 为完整请求耗时。不能把 TLS 数值当作单独握手耗时，也不能把 SpeedTest 在已有连接上的 HTTPing 延迟和 Total 混为一谈。

若测试可能超过工具时限，分批候选执行，每批每个 IP 仍至少 20 次，并明确批次的时间差。不要在被中断或只测几次时报告已经完成 20 次。

trace 只反映边缘连接。最终候选若用于 API，应在用户授权范围内再用实际无副作用的 API 验证；不要发送付费生成、写入或其他有副作用请求来测速。

## 5. 报告和应用

在相同路径、相同每 IP 次数下，汇总和推荐均依次按失败数、节点不符数、P95、中位数、均值升序比较；缺失延迟排在有值之后，最大值和超时数作为补充信息。节点不符只统计成功 GET，未设置期望节点时为 0。零成功的候选不可推荐；几毫秒差异不视为稳定优势，没有明显优势时保留当前地址。不同路径或样本数不直接合并排名。

使用以下简短报告模板：

```text
目标/时间：<主机名、测试时间范围>
路径：<直连或代理类型、解析方、VPN/TUN、已确认的实际出口；未知项注明>
范围：<扫描范围/实际数量、HEAD 校准状态码、期望节点>
采样：<计划和实际每 IP 次数、超时上限、是否完整>
IP | 节点 | 成功/总数 | 失败 | 超时 | 节点不符 | P95 | 中位 | 均值 | 最大（ms）
结论：<按统一顺序比较，推荐及依据；无可推荐候选或优势时说明>
限制：<失败降级、跨批次时间差、仅 trace 验证等>
数据：<原始 CSV、汇总 CSV 路径；未完成则注明无最终汇总>
```

用户授权修改 hosts 后：读取原文件，将该域名现有有效映射替换成唯一选定 IP，保留同一行其他域名及无关条目；没有映射则追加。使用专用编辑工具，执行 `ipconfig /flushdns`，然后用普通域名访问（不加 `--resolve`）验证 remote_ip、colo、HTTP 状态和耗时。权限不足时如实报告，不要声称已经修改。

```text
162.159.38.138 www.example.com
```

公共 DNS 记录变更会影响其他主机；用户希望保留其他主机线路时优先使用本机覆盖。代理自行解析时 hosts 可能不生效，需在实际连接方验证。清空 Windows DNS 缓存不会自动断开应用已有连接，必要时提示重启相关客户端。

## 发布与测试数据隐私

公开技能时提交 `SKILL.md`、脚本和 `.gitignore` 即可。文档使用占位域名和环境变量路径，不加入用户真实域名、Windows 用户名、出口公网 IP、私有网络地址、完整 hosts 内容或历史测速数据。示例中的 Cloudflare 公共边缘 IP 和官方项目 URL 可保留。

Cloudflare trace 响应包含 `ip=`（客户端出口公网 IP）等网络信息。只提取测速所需的节点和时间，不将完整响应写入产物；复测脚本的失败信息仅保留退出码、HTTP 状态和节点是否存在。

原始和汇总 CSV 仍包含实际目标域名（文件名）、测试时间、边缘 IP、节点和性能数据。默认保存在本机临时目录，公开分享前单独审查。CloudflareSpeedTest 的调试日志和手工保存的 trace 响应也需要审查。

附带 `.gitignore` 忽略 CSV、日志、工具二进制和压缩包。Git 忽略规则不能清除已经跟踪的文件或历史提交；若要审查整个仓库，应另外检查已跟踪文件及提交历史。
