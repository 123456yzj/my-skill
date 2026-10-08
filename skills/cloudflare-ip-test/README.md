# cloudflare-ip-test 使用教程

本 skill 用于寻找适合当前机器网络线路的 Cloudflare 边缘 IP，并验证目标域名的节点及访问耗时。发现候选使用 CloudflareSpeedTest，最终比较使用附带的复测脚本。

测试范围仅限 IPv4，扫描使用 `ip.txt`，复测脚本会拒绝 IPv6 地址，并强制 curl 使用 IPv4。

它适用于支持 Skills 的 AI 助手，也可以完全手工执行。当前附带脚本面向 Windows，不包含 macOS 或 Linux 的自动化实现。

## 一、前置条件

| 条件 | 是否必需 | 说明 |
| --- | --- | --- |
| Windows | 必需 | 当前命令使用 `curl.exe` 和 Windows DNS 工具 |
| PowerShell 7 或更高版本 | 必需 | 脚本包含 `#requires -Version 7.0`；系统自带 Windows PowerShell 5.1 不满足要求 |
| `curl.exe` | 必需 | 负责指定连接 IP、验证证书、请求 trace 和记录耗时 |
| 可用的目标域名 | 必需 | 目标的 `https://域名/cdn-cgi/trace` 须能 GET 返回 HTTP 200 和 `colo=` |
| 直连网络 | 必需 | 当前复测脚本绕过显式代理，需能连接候选 IP 的 443 端口；VPN/TUN 仍可能影响实际出口 |
| 可写的结果目录 | 必需 | 目录须先创建，默认使用系统临时目录 |
| 候选 IP | 复测时必需 | 可由之前测试提供，或通过 CloudflareSpeedTest 扫描获得 |
| CloudflareSpeedTest | 扫描时必需 | 只复测已知 IP 时无需安装 |
| Git | 可选 | 可用 Git 克隆仓库，也可在 GitHub 下载 ZIP |
| 支持 Skills 和本机命令执行的 AI 助手 | 自动执行时需要 | 手工执行脚本无需 AI 助手 |
| 管理员权限 | 修改 hosts 时需要 | 普通测速可在普通终端完成；工具安装权限由所选安装方式决定 |

仅测速无需 Cloudflare 登录、API Key 或修改公共 DNS。结果只代表测试所在机器和实际网络出口。

## 二、准备 PowerShell 和 curl

在终端执行：

```powershell
$PSVersionTable.PSVersion
Get-Command curl.exe
curl.exe --version
```

PowerShell 的 `Major` 应为 7 或更高。若显示 5，可按 [微软官方教程](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows) 安装。支持 WinGet 的 Windows 可运行：

```powershell
winget install --id Microsoft.PowerShell --source winget
```

安装后重新打开终端，选择 PowerShell 7，或执行 `pwsh`，再次检查版本。没有 WinGet 时按官方教程选择安装包。

如果找不到 `curl.exe`，从 [curl 官方 Windows 下载页](https://curl.se/windows/) 获取适用版本，将包含 `curl.exe` 的目录加入 PATH，然后重新打开终端并验证。

## 三、取得项目并选择使用方式

从 GitHub 下载本仓库 ZIP 并解压，或使用 Git 克隆仓库。在包含 `skills/` 的仓库根目录打开 PowerShell 7。下文复测命令以此目录为工作目录。

**让 AI 助手执行：** 将 `skills/cloudflare-ip-test` 完整复制到该助手支持的 skill 目录，按其要求刷新或重新加载。对支持 `~/.agents/skills/` 的助手，仓库根目录的 [README](../../README.md) 提供了安装示例。

然后输入类似指令，并替换实际域名：

> 使用 cloudflare-ip-test，为我的目标域名筛选 Cloudflare IP，优先 HKG，每个候选至少测试 20 次，保存原始数据并报告失败率和 P95。

如果助手不支持自动加载 skill，可以让它读取 `SKILL.md`。助手必须有读取文件及执行本机命令的能力，才能完成实测。

**手工执行：** 直接按下文操作，无需安装到 AI 助手目录。

## 四、确认目标域名可测试

执行前确认实际主机名、直连或代理、期望节点、候选及当前 IP、每 IP 次数、超时和结果目录。默认直连、每 IP 20 次、5 秒超时、不限制节点，结果写入现有临时目录。代理路径须先确认下面列出的参数。

读取实际域名；只输入主机名，不包含 `https://` 或路径：

```powershell
$targetDomain = Read-Host '请输入实际目标域名，例如 www.example.com'
Resolve-DnsName $targetDomain -Type A
curl.exe -4 --noproxy '*' -sS --max-time 8 `
  -w "`n连接IP=%{remote_ip} 状态=%{http_code} 总耗时=%{time_total}s`n" `
  "https://$targetDomain/cdn-cgi/trace"
```

应看到 HTTP 200 和响应中的 `colo=HKG`、`colo=NRT` 等字段。`www.example.com` 是占位示例，不能假定它提供 Cloudflare trace。

如果普通域名访问超时，但指定的候选 IP 可访问，也可以继续复测候选。如果 trace 返回 403、404、登录页或不含 `colo=`，先确认目标配置；附带脚本将这类请求统计为失败。不要关闭 TLS 证书校验来绕过证书错误。

### 代理测试分支

附带 `Measure-CloudflareIp.ps1` 使用 `--noproxy '*'`，仅支持直连测试。代理测试先确认：代理 URL/端口及类型（HTTP、HTTPS、SOCKS5）、是否需认证、域名由本机还是代理解析、是否允许连接指定 IP。VPN/TUN 的透明转发也需标明。代理关键参数未知时先补齐再测。

以下示例在已设置 `$targetDomain` 的终端执行，替换代理地址和候选 IP。`--noproxy ''` 清除环境中的绕过规则，确保使用指定代理。HTTP/HTTPS 代理通过 CONNECT 连接指定 IP；`--connect-to` 保留原域名的 Host、SNI 和证书校验。SOCKS5 本地解析使用 `socks5://` 与 `--resolve`；代理解析使用 `socks5h://`，域名访问时不能依靠本机 hosts 或 `--resolve` 固定候选。

```powershell
$PSNativeCommandUseErrorActionPreference = $false
$proxyUrl = Read-Host '请输入确认过的代理 URL，例如 http://127.0.0.1:7890'
$candidateIP = '162.159.38.138' # 使用规范化后的四段十进制 IPv4
# HTTP/HTTPS CONNECT 或 SOCKS5：显式交给代理一个数字 IP，无需解析目标域名。
curl.exe -4 --proxy $proxyUrl --noproxy '' `
  --connect-to "${targetDomain}:443:${candidateIP}:443" `
  -sS --max-time 5 -w "`ncode=%{http_code} peer=%{remote_ip} total=%{time_total}`n" `
  "https://$targetDomain/cdn-cgi/trace"
$candidateExitCode = $LASTEXITCODE
# 单独测试代理解析域名的实际使用路径（例：SOCKS5 远端解析）。
$remoteDnsProxy = Read-Host '请输入 SOCKS5 远端解析代理 URL，例如 socks5h://127.0.0.1:7890'
curl.exe -4 --proxy $remoteDnsProxy --noproxy '' -sS --max-time 5 `
  -w "`ncode=%{http_code} peer=%{remote_ip} total=%{time_total}`n" `
  "https://$targetDomain/cdn-cgi/trace"
$domainExitCode = $LASTEXITCODE
```

按确认过的类型选择相应命令。代理可能拒绝 CONNECT 数字 IP，此时报告无法固定候选，只能测试代理域名路径。通过代理时 `remote_ip` 通常是代理连接地址，不能用它证明边缘 IP；通过代理日志/CONNECT 目标确认指定 IP，使用 trace 的 `colo` 确认节点。`-4` 也不能保证代理远端解析选用 IPv4；需要代理配置或日志验证。先验证一次，若需候选排名，再对每个 IP 串行轮换执行至少 20 次、逐次保存退出码/HTTP/colo/耗时，使用与直连相同的成功条件和排序规则，独立保存代理结果。不要把上述单次检查当作完成复测，也不要直接复用直连脚本或假定 CloudflareSpeedTest 会沿用代理路径。

## 五、已有 IP：直接每个复测 20 次

以下候选为公共边缘 IP 示例，不保证在任何线路上都低延迟。填入自己需要比较的地址：

```powershell
$candidateIPs = @('162.159.38.138', '162.159.44.49')
$resultDirectory = Join-Path $env:TEMP 'cloudflare-ip-results'
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null

& '.\skills\cloudflare-ip-test\scripts\Measure-CloudflareIp.ps1' `
  -Domain $targetDomain `
  -IPs $candidateIPs `
  -Samples 20 `
  -TimeoutSeconds 5 `
  -ExpectedColos @('HKG', 'NRT') `
  -OutputDirectory $resultDirectory
```

参数说明：

| 参数 | 默认值 | 作用 |
| --- | --- | --- |
| `Domain` | 必填 | 目标主机名，脚本自动请求其 `/cdn-cgi/trace` |
| `IPs` | 必填 | 四段十进制 IPv4，每段 0～255；去除首尾空白、按十进制去掉前导零后去重；拒绝 IPv6、短写、十六进制和空值 |
| `Samples` | 20 | 每个 IP 的次数，允许 20～10000 |
| `TimeoutSeconds` | 5 | 每次完整请求的超时上限，允许 1～60 秒 |
| `ExpectedColos` | 不限制 | 记录成功请求是否落到预期节点；不会取消对其他节点的统计 |
| `OutputDirectory` | `$env:TEMP` | 保存 CSV 的现有目录 |

两条 IP、每条 20 次，共 40 次请求。脚本串行执行，每轮轮换 IP 顺序，每次新建 HTTPS 连接。耗时取决于网络；大量超时会延长运行时间。原始 CSV 逐次写入，中途停止仍可查看已完成数据，但汇总 CSV 只在全部完成后生成。

脚本在自己的作用域内将 `$PSNativeCommandUseErrorActionPreference` 设为 `$false`，以 `$LASTEXITCODE` 统计原生命令失败；宿主设为 `$true` 且 `$ErrorActionPreference = 'Stop'` 时，curl 超时或非零退出仍记录样本并继续，调用方设置不变。写 CSV 失败等本地错误仍会停止执行。

## 六、没有 IP：先用 CloudflareSpeedTest 找候选

### 下载工具

1. 打开 [官方发布页](https://github.com/XIU2/CloudflareSpeedTest/releases/latest)。
2. 选择匹配系统架构的 Windows 压缩包：常见 x64 为 `cfst_windows_amd64.zip`，ARM64 为 `cfst_windows_arm64.zip`。查看 Windows“设置 → 系统 → 关于 → 系统类型”确认架构。
3. 下载并解压到单独的工具目录，例如系统临时目录下的 `cloudflare-ip-test/cfst`。保留随包提供的 `ip.txt` 等文件。
4. 使用 `Get-FileHash -Algorithm SHA256 -LiteralPath '实际压缩包路径'` 获取摘要；官方发布接口提供资产 `digest` 时与其比较。没有官方摘要时不能声称已验证文件完整性。
5. 在解压目录打开 PowerShell，执行 `./cfst.exe -h`，确认当前版本帮助及参数。

### 先校准 HEAD 请求

以下命令在**工具解压目录**执行。若开了新终端，重新设置 `$targetDomain`。选取 2～3 个已知可连 IP：

```powershell
$targetDomain = Read-Host '请输入实际目标域名，例如 www.example.com'
.\cfst.exe -httping -url "https://$targetDomain/cdn-cgi/trace" `
  -ip '162.159.38.138,162.159.44.49' `
  -n 1 -t 2 -dd -p 0 -debug -o control.csv
```

CloudflareSpeedTest v2.3.5 的 HTTPing 使用 HEAD。GET 返回 200 时，HEAD 仍可能返回 404 或 403。将调试确认的实际状态码存入 `$headStatus`，带该值重复对照测试，确认能提取节点后再扫描。最终复测脚本仍要求 GET 返回 200。不要跨域名、跨版本沿用旧状态码。

### 筛选香港或东京

将 `$headStatus` 设为对照测试确认过的状态码，不要照抄固定 404：

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

只找香港可改为 `-cfcolo HKG`。`-dd` 关闭下载测速，`-p 0` 避免结束后等待回车。运行时间可能较长；需要时用 `-ip` 指定较小网段分批扫描。默认按每个 /24 抽样，不是遍历全部 IP；对选定的小网段加 `-allip` 才测试每个 IPv4。

打开 `candidates.csv`，选择若干候选，并加入当前使用地址作对照。返回仓库根目录的终端，填写 `$candidateIPs`，按第五节每个至少复测 20 次。

没有输出候选时，先检查状态码、超时和并发。某轮 HKG 为零，只表示该轮范围内没有筛选到香港节点。

## 七、阅读结果和应用

查看脚本输出的原始 CSV 和汇总 CSV：

- `Successes`、`Failures`、`Timeouts`：成功、失败和超时次数。
- `Colos`、`ColoMismatches`：实际节点及预期节点不符次数。
- `MeanMs`、`MedianMs`：成功请求的平均耗时和中位数。
- `P95Ms`：采用 nearest-rank，95% 成功请求不超过的耗时。
- `MaxMs`：最慢成功请求的耗时。

这些统计单位均为毫秒。完整耗时包含 TCP、TLS 和响应；TLS 字段为从请求开始到握手完成的累计时间。失败请求不进入延迟均值，但会计入失败数。在相同路径、相同每 IP 次数下，汇总和推荐均依次按失败数、节点不符数、P95、中位数、均值升序比较；缺失延迟排在有值之后，最大值和超时数作为补充。节点不符只统计成功 GET，未设置期望节点时为 0。零成功不可推荐，节点均不符合或没有明显优势时保留当前地址；几毫秒差异不视为稳定优势。不同路径或样本数不直接合并排名。

失败降级：工具缺失但已有候选时直接复测；无候选则报告安装阻碍。扫描为空时降低并发、不限节点复核，仍为空则说明抽样范围，可复测已有候选。请求失败保留样本并继续，不无限重试；本地写入失败或执行中断时报告已完成次数，未完成每 IP 至少 20 次不给最终排名。所有 GET 不可用时排查网络/trace，HEAD 成功不能替代 GET 验证。

报告模板（与 SKILL 一致）：

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

用户确定应用后，可在管理员权限下编辑 Windows hosts：

```text
C:\Windows\System32\drivers\etc\hosts
```

将目标域名的现有映射替换为唯一选定地址，保留其他无关条目；执行 `ipconfig /flushdns`。随后用 `curl.exe -4` 直接访问域名，**不加 `--resolve`**，确认实际连接 IP、colo 和 HTTP 状态。如应用仍使用旧连接，重新启动该应用。代理自行解析域名时，本机 hosts 可能不起作用。

## 八、常见问题

| 问题 | 处理 |
| --- | --- |
| 提示需要 PowerShell 7 | 打开 `pwsh` 或 PowerShell 7，不使用 Windows PowerShell 5.1 |
| 找不到脚本 | 确认当前目录为仓库根目录，或使用脚本实际完整路径 |
| 脚本执行被阻止 | 先查看 `Get-ExecutionPolicy -List`；已审核的下载脚本可用 `Unblock-File` 解除下载标记。按本机策略要求执行，组织策略限制时联系管理员 |
| 结果目录不存在 | 使用 `New-Item -ItemType Directory -Force` 创建后再运行 |
| 没有香港节点 | 校准 HEAD 状态码、降低并发并分批复测；不要依据 IP 归属地断言实际节点 |
| 多个 IP 都超时 | 检查本机网络、443 端口可达性和实际出口；脚本默认绕过显式代理 |
| `ExpectedColos` 设置 HKG 仍看到 NRT | 此参数用于标记节点不符，不会过滤成功请求；根据 `ColoMismatches` 选择候选 |

## 九、数据与隐私

公开仓库只需包含教程、skill 和脚本。CSV 文件名包含实际目标域名，记录中包含时间和边缘节点信息；公开分享前单独审查。脚本不会保存完整 trace 响应或其中的客户端公网 IP，但手工保存的响应和工具调试日志可能包含这些信息。

`.gitignore` 忽略 CSV、日志和下载工具；它不能移除已跟踪文件或历史提交。不要把本机 hosts、凭据、个人绝对路径或历史测速日志一起上传。
