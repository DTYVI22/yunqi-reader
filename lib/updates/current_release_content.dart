import 'release_notices.dart';

class ReleaseSection {
  const ReleaseSection(this.title, this.items);
  final String title;
  final List<String> items;
}

const releaseFreeNotice = '**本项目完全免费，没有任何付费版、激活码或解锁服务。**';

const projectOriginNotice =
    '本应用基于 [Wenku8_Flutter](https://github.com/mikufoxxx/Wenku8_Flutter)（GPL-2.0）二次开发，'
    '保留了它的本地导入、阅读器、听书、备份同步等能力，并新增开源阅读（legado）书源支持。';

const releaseProjectNotice =
    '「云栖书架」是本地阅读器：书源由用户自行导入并在设置里管理，应用不运营任何在线书库，'
    '也不附带小说文件。所有在线内容来自你所选的书源站点，其可用性与合规性以来源为准。';

const releaseRightsNotice =
    '小说、封面和插图归各自权利人所有。请仅使用有权访问的内容，遵守来源网站规则，'
    '不得绕过访问限制、破解 DRM，或未经许可传播、出售内容。';

const releaseReadingNotice = '**在线内容以各书源站点的开放状态为准。**';

const releaseMaintenanceNotice = '当前为个人二次开发版本，按实际需要更新，不承诺发版节奏。';

const _changeSource =
    '接入开源阅读（legado）书源：搜索、详情、目录、正文全链路打通，支持 POST 书源与分页目录。';
const _changeManage = '新增「书源」管理页：查看内置书源，从链接或 JSON 导入自己的书源，逐条启用或禁用。';
const _changeDiscover = '发现页接上书源首页推荐，搜索结果与详情页显示真实封面。';
const _changeBuild = '补齐上游公开快照缺失的文件，使项目能独立编译运行。';

const _changes = [_changeSource, _changeManage, _changeDiscover, _changeBuild];

const _androidInstall = '**Android**：直接覆盖安装即可，不要先卸载（卸载会清空书架与书源）。';
const _backup = '升级或整理存储前，请先备份重要书籍、阅读进度与书源配置。';

const publicReleaseNotes =
    '''
### 关于这个版本

$projectOriginNotice

$releaseFreeNotice

$releaseProjectNotice

$releaseRightsNotice

$releaseReadingNotice

**$currentReleaseSourcePolicy**

### 这个版本做了什么

- $_changeSource
- $_changeManage
- $_changeDiscover
- $_changeBuild

### 后续维护

$releaseMaintenanceNotice

### 安装说明

- $_androidInstall

$_backup
''';

const currentReleaseNotes = publicReleaseNotes;

const currentReleaseSummary = [
  releaseFreeNotice,
  projectOriginNotice,
  releaseProjectNotice,
  releaseReadingNotice,
  currentReleaseSourcePolicy,
  ..._changes,
  releaseMaintenanceNotice,
];

const currentReleaseSections = [
  ReleaseSection('重要说明 · 请务必阅读', [
    releaseFreeNotice,
    projectOriginNotice,
    releaseProjectNotice,
    releaseRightsNotice,
    releaseReadingNotice,
    currentReleaseSourcePolicy,
  ]),
  ReleaseSection('这个版本做了什么', [
    ..._changes,
    releaseMaintenanceNotice,
    _androidInstall,
    _backup,
  ]),
];
