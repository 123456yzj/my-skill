# my-skill

用于保存、维护和分享 AI 编程助手 skills 的仓库。

## Skills

| Skill | 用途 | 环境 |
| --- | --- | --- |
| [cloudflare-ip-test](skills/cloudflare-ip-test/SKILL.md) | 筛选 Cloudflare 边缘 IP、验证节点，并对每个候选进行至少 20 次 HTTPS 复测 | Windows、PowerShell 7、curl.exe；发现候选需要 CloudflareSpeedTest |
| [agent-correction](skills/agent-correction/SKILL.md) | 理解纠错场景、检查规范，在对话提案获准后保存纠正规则 | 支持 skill 的 AI 助手及文件读写工具 |
| [agent-rule-conversion](skills/agent-rule-conversion/SKILL.md) | 仅整理已有纠错文件，提炼并整合到项目规范，获准后生成简洁记录 | 支持 skill 的 AI 助手及文件读写工具 |

首次使用请阅读 [cloudflare-ip-test 前置条件与教程](skills/cloudflare-ip-test/README.md)。

纠错与规则转换共用目标项目根目录下的 `.agents/corrections/rules.md`，无需用户提供纠错文件位置。安装和调用见各技能目录的 README，审批流程与文件格式见各自的 `SKILL.md`。下面的网络工具前置条件和复测命令适用于 `cloudflare-ip-test`。

## 前置条件

- 当前复测脚本需要 Windows 和 PowerShell 7，Windows PowerShell 5.1 无法运行。
- 本 skill 的扫描和复测范围仅限 IPv4。
- 本机须能执行 `curl.exe`，并能直连候选 IP 的 HTTPS 443 端口。
- 目标域名须支持 Cloudflare `/cdn-cgi/trace`，GET 请求返回 HTTP 200 和 `colo=`。
- 已有候选 IP 时可直接复测；需要发现候选时另行准备 CloudflareSpeedTest。
- AI 助手需能读取 skill 文件并执行本机命令；手工执行脚本无需 AI 助手。
- 普通测速不需要管理员权限、Cloudflare 登录或 API Key；安装工具及修改 hosts 时按系统要求使用相应权限。

## 目录结构

```text
skills/
├── agent-correction/
│   ├── SKILL.md
│   └── README.md
├── agent-rule-conversion/
│   ├── SKILL.md
│   └── README.md
└── cloudflare-ip-test/
    ├── SKILL.md
    ├── README.md
    ├── .gitignore
    └── scripts/
        └── Measure-CloudflareIp.ps1
```

每个 skill 放在独立目录中，入口文件为 `SKILL.md`，辅助脚本放在对应的 `scripts/` 目录。

## 在支持 Skills 的 AI 助手中使用

将 `skills/cloudflare-ip-test` 整个目录复制到所用 AI 助手支持的技能目录，保留 `SKILL.md` 和 `scripts/` 的相对位置。具体目录及加载方式以该助手的说明为准。

对于支持 `~/.agents/skills/` 的助手，可从仓库根目录执行以下 PowerShell 命令。如果目标目录中已有同名 skill，先检查是否有需要保留的修改。

```powershell
$skillRoot = Join-Path $env:USERPROFILE '.agents\skills'
New-Item -ItemType Directory -Path $skillRoot -Force | Out-Null
Copy-Item -LiteralPath '.\skills\cloudflare-ip-test' -Destination $skillRoot -Recurse -Force
```

按所用助手的要求刷新技能列表或重新启动，使新增或更新的 skill 生效。也可以让助手读取 `SKILL.md` 并按其中的流程执行。

调用示例：

> 使用 cloudflare-ip-test，测试我的 Cloudflare 域名，每个候选 IP 至少测试 20 次，优先筛选 HKG 节点。

请提供实际目标域名。文档中的 `www.example.com` 为占位示例，不保证支持 Cloudflare trace。

## 直接运行复测脚本

先创建结果目录，再执行脚本。替换示例域名和 IP 为实际目标及候选地址。

```powershell
$resultDirectory = Join-Path $env:TEMP 'cloudflare-ip-results'
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null
& '.\skills\cloudflare-ip-test\scripts\Measure-CloudflareIp.ps1' `
  -Domain www.example.com `
  -IPs @('162.159.38.138', '162.159.44.49') `
  -Samples 20 `
  -OutputDirectory $resultDirectory
```

脚本仅用于直连复测指定 IPv4，输出原始 CSV 和汇总 CSV。IPv4 去除首尾空白、按十进制去掉前导零后去重，拒绝短写和 IPv6。curl 超时或失败仍记录并继续，不受宿主原生命令错误偏好影响。汇总和推荐依次比较失败数、节点不符数、P95、中位数、均值；零成功不可推荐。候选发现、输入确认和报告模板见 `SKILL.md`，代理类型与解析方式的确认及可执行指引见技能 README 的“代理测试分支”。

## 发布内容

提交技能文档、脚本和项目说明。示例使用占位域名和环境变量路径，测速产物默认写入本机临时目录。

CSV、日志、工具二进制、压缩包和本地凭据文件已设置 Git 忽略规则。公开分享测速结果前，另外检查实际域名、时间和网络信息；忽略规则不会移除已跟踪文件或历史提交。
