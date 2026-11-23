# First public launch

This is a preparation note, not a published announcement. It records what to post, what
to ask for, and what to measure without adding an analytics service or inventing adoption.

## Position

**DOTORI Vault is a Windows/PowerShell tool for people who want one Markdown source for
Claude Code and Codex skills and agent definitions across machines, but do not want a Git
remote to be the path between those machines.**

It is not a general replacement for [skillshare](https://github.com/runkids/skillshare).
Use skillshare for broad cross-platform runtime support, Git/team distribution, MCP/plugins,
and its audit/UI features. Use DOTORI only when its narrower combination matters:

- an approved synced folder already exists on both Windows machines;
- the shared source should stay plain Markdown;
- the local Git mirror must stay outside that folder;
- a real memory conflict must stop rather than merge automatically.

Never frame an employer's cloud folder as a policy bypass. The organization must permit both
the chosen sync folder and every file placed in it.

## Before the first post

1. Merge the README and issue-template change, then verify the links on GitHub.
2. Apply the repository metadata below. These settings are not represented by a branch or
   pull request, so change them only after the PR is merged.
3. Create the first release/tag from the merged commit. A source-only `v0.1.0` release is
   enough; do not imply that it contains an installer or a Windows test result it does not.
4. Run the disposable quickstart once on a Windows machine, or leave that fact explicitly
   open. Never state that an external person has installed it until one actually reports it.
5. Open **Insights → Traffic** just before posting and record the baseline below.

### Repository metadata to apply after merge

**Description**

> Windows/PowerShell vault for sharing Claude Code and Codex skills and agents through an approved synced Markdown folder — no Git remote required.

**Topics**

`ai-agents` · `agent-skills` · `claude-code` · `codex` · `cross-machine-sync` ·
`markdown` · `powershell` · `windows`

Keep `sync` if it is useful in GitHub's picker. Remove generic topics only if the eight
above fill the available slots; do not add terms for runtimes or features DOTORI does not
actually support.

## First channel and sequence

### 1. Reddit r/Codex weekly project showcase

Use the most recent moderator-run “Show us what you've been building with Codex” thread if
it is still pinned and accepts entries. It is a better first test than a standalone launch:
the thread explicitly asks for projects, its readers already use Codex, and the post can
ask for a narrow Windows/PowerShell trial rather than broad praise.

Post only after the merged repository exposes the quickstart and the `Try DOTORI` issue
template. Link directly to the repository; do not use tracking parameters.

Observe for 48 hours:

- Is the link a useful fit for Codex users, or do people immediately point to a missing
  use case?
- Does anyone try the quickstart or open a `Try DOTORI` issue?
- Which sentence causes the first confusion: Git-versus-folder transport, memory scope,
  runtime coverage, or installation?

### 2. Hacker News Show HN — only after the first real try

Use this only when the author can personally write the submission, is available to answer
questions, and at least one person has attempted the documented quickstart or install.
Show HN requires something readers can try, a personal explanation of why it was made, and
an author present for discussion. Its guidelines also say not to submit generated text.

Do **not** copy an AI-generated draft to Hacker News. Write the HN post in the author's own
words from the facts above, make the Windows-only boundary and safe demo obvious, and avoid
asking for votes or comments.

`r/ClaudeCode` can be a later alternative, not a simultaneous second blast. Before posting,
check the current subreddit rules and self-promotion guidance in the posting interface; the
public rules endpoint did not expose the rule text during preparation.

## English draft — r/Codex weekly showcase

**DOTORI Vault — a Windows Markdown workspace for Claude Code + Codex without a Git remote**

I switch between Claude Code and Codex, and I was tired of rebuilding the same skills and
agent setup on each runtime and each machine.

I made DOTORI Vault for a narrow case: Windows machines that already share an approved
folder, but where I do not want a personal Git remote to be the transport between them.
The shared source is just Markdown. DOTORI publishes shared skills to Claude Code, Codex,
and Antigravity's documented skill path; it converts Claude-style agent Markdown to Codex
TOML; and it keeps the local Git metadata outside the synced folder.

The memory part is deliberately conservative. It reconciles the selected Claude memory
store with a three-way comparison and stops on a real conflict. It does not sync chat
transcripts, invent an Antigravity agent path, or claim that Codex native memory becomes
cross-runtime context.

It is Windows/PowerShell 5.1 only, has no daemon or cloud API, and it is not a replacement
for skillshare if you need broad cross-platform tool coverage, Git/team distribution, or
MCP/plugin management.

The repo includes a disposable 10-minute quickstart that redirects every path, so it does
not touch a real vault or runtime settings:
https://github.com/J-Roc-H/dotori-vault

The feedback I would value most:

1. Does the README let you decide quickly whether this is for your setup?
2. If you use Windows, can you complete the scratch quickstart?
3. Where is the first confusing or unsafe-looking step?

Please do not paste vault contents, credentials, employer data, or unredacted logs.

## Korean draft — reusable community introduction

**DOTORI Vault: Git 원격 없이 Claude Code·Codex 작업환경을 기기 사이에 유지하는 Windows용 Markdown Vault**

Claude Code와 Codex를 번갈아 쓰거나, 회사 PC와 집 PC를 오가면 스킬·에이전트 정의를 다시 맞추게 되는 일이 반복됐다. 그래서 이미 허용된 동기화 폴더를 매개로, 하나의 Markdown 원본을 각 런타임에 배포하는 DOTORI Vault를 공개했다.

현재 범위는 분명하다.

- Claude Code·Codex 스킬 공유
- Claude 형식 에이전트 정의를 Codex TOML로 변환
- Antigravity의 확인된 스킬 경로 및 명시적 규칙 파일 지원
- 선택된 Claude 메모리의 3-way 동기화와 충돌 중지
- 동기화 폴더 안에는 `.git`을 두지 않고, 로컬 Git 이력은 별도 위치에 보관

반대로 대화 내용이나 미완료 세션을 넘기지 않으며, Codex의 네이티브 메모리를 다른 런타임이 자동으로 읽는다고 주장하지도 않는다. 실제 충돌은 자동 병합하지 않고 멈춘다.

Windows PowerShell 5.1용이며, Git 기반 팀 공유·다양한 런타임·MCP/플러그인 관리가 필요하면 skillshare가 더 적합하다. 회사 PC에서 사용할 경우에도 동기화 폴더와 그 안의 파일이 조직 정책에 허용되는지는 별도로 확인해야 한다.

실제 Vault나 설정 파일을 건드리지 않는 10분짜리 임시 경로 데모를 넣어 두었다.
https://github.com/J-Roc-H/dotori-vault

특히 Windows 사용자에게 다음을 확인받고 싶다.

1. README만 보고 대상 사용자 여부를 판단할 수 있는지
2. 임시 경로 데모가 실제로 끝까지 실행되는지
3. 설치 전에 가장 불안하거나 이해되지 않는 부분이 어디인지

Vault 내용, 자격 증명, 회사 정보, 원본 로그는 올리지 말고 필요한 오류 줄만 가린 뒤 공유해 달라고 안내한다.

## Short reusable descriptions

| Language | Copy |
|---|---|
| English | Windows/PowerShell vault that shares Claude Code and Codex skills and agents through an approved synced Markdown folder — no Git remote required. |
| Korean | 허용된 동기화 폴더를 통해 Claude Code·Codex 스킬과 에이전트 정의를 공유하는 Windows/PowerShell Markdown Vault. Git 원격은 필요 없다. |

## Measurement log

GitHub Traffic is sufficient for this first release. It reports the last 14 days only; views
and clone counts are not proof of successful use. Referrers omit GitHub and search engines,
and traffic time is UTC. Record a snapshot before posting, then at T+1, T+7, and T+14 days.

| Snapshot | Repo views / unique visitors | Clones / unique cloners | Top referrers | Stars / forks / watchers | Issues: try / bug / other | Community replies | Confirmed install attempts |
|---|---:|---:|---|---:|---:|---:|---:|
| Baseline before first post |  |  |  | 0 / 0 / 0 | 0 / 0 / 0 | 0 | 0 |
| T+1 day |  |  |  |  |  |  |  |
| T+7 days |  |  |  |  |  |  |  |
| T+14 days |  |  |  |  |  |  |  |

Count an installation attempt only when someone explicitly says they ran the quickstart or
installation, or opens a relevant issue. Count substantive interest only when a person asks
a product-specific question, reports a trial, identifies a concrete limitation, or proposes
a relevant use case. Do not infer either from stars, views, or clones.

Open the graph at **repository → Insights → Traffic**. Anyone with push access can view
the last 14 days of full clones, visitors, referring sites, and popular content. The
connector used for this preparation could read repository metadata but not the protected
traffic endpoint, so the baseline table remains intentionally blank.

## Sources checked for this plan

- [GitHub Traffic documentation](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/viewing-traffic-to-a-repository)
- [Hacker News Show HN guidelines](https://news.ycombinator.com/showhn.html)
- [Hacker News guidelines](https://news.ycombinator.com/newsguidelines.html)
- [skillshare](https://github.com/runkids/skillshare)
- [claude-mem](https://github.com/thedotmack/claude-mem)
- [MemBridge](https://github.com/MembridgeAi/membridge)
- [Graphori](https://github.com/dotoridot/graphori)
