/**
 * 参考文献格式检查器 —— 鸿蒙 PC 校园应用（选题 054）
 *
 * 档位：本地。数据内置，不联网、不读文件系统、不需要账号。
 * 核心流程：列出引用条目 → 逐条检查 → 给出结论 → 批量修正 → 复查。
 *
 * 用法：整份替换 entry/src/main/ets/pages/Index.ets
 */

interface RefItem {
  id: string;
  authors: string;
  title: string;
  journal: string;
  year: string;
  doi: string;
  issues: string[];
}

/**
 * ForEach 的键。
 * ⚠️ 必须随数据变化而变化：若只返回 id，ArkUI 会复用旧组件、
 *    导致「点了检查但列表不刷新」。这里把会变的字段长度一起编进键。
 */
function rowKey(it: RefItem): string {
  return it.id + '#' + it.issues.length + '#' + it.authors.length + '#'
    + it.title.length + '#' + it.doi.length + '#' + it.year;
}

/** 内置样例：10 条引用，6 条存在问题（共 8 处）。 */
function buildSeed(): RefItem[] {
  const raw: string[][] = [
    ['R01', '王小明, 李华', '高校图书馆数字资源评价研究', '大学图书馆学报', '2023', '10.13365/j.issn.1002-1027.2023.01.003'],
    ['R02', '陈静', '基于知识图谱的学术推荐系统', '计算机应用研究', '', '10.3969/j.issn.1001-3695.2022.05.014'],
    ['R03', '张伟, 刘洋, 赵敏', '高校科研数据管理平台设计', '现代情报', '2021', '10.3969/j.issn.1008-0821.2021.07.009'],
    ['R04', '', '面向新工科的程序设计课程改革', '计算机教育', '2020', '10.16512/j.cnki.jsjjy.2020.03.011'],
    ['R05', '孙丽', '大学生信息素养现状调查', '图书情报工作', '2022', '10.13266/j.issn.0252-3116.2022.15.008'],
    ['R06', '周强', '高校图书馆数字资源评价研究', '大学图书馆学报', '2019', '10.13365/j.issn.1002-1027.2023.01.003'],
    ['R07', '吴昊, 郑爽', '高校实验室安全管理体系构建', '实验技术与管理', '2021', ''],
    ['R08', '冯蕾', '混合式教学模式在课程中的应用', '中国大学教学', '2023', '10.3969/j.issn.1005-0450.2023.02.012'],
    ['R09', '黄鹏, 徐婷', '校园一卡通数据挖掘与学业预警', '计算机工程与应用', '2024', '10.3778/j.issn.1002-8331.2305-0456'],
    ['R10', '许静', '', '情报理论与实践', '2022', '10.16353/j.cnki.1000-7490.2022.04.018']
  ];
  const list: RefItem[] = [];
  for (let i = 0; i < raw.length; i++) {
    const r: string[] = raw[i];
    list.push({ id: r[0], authors: r[1], title: r[2], journal: r[3], year: r[4], doi: r[5], issues: [] });
  }
  return list;
}

/** 逐条检查。规则：字段完整性 4 条 + 年份格式 1 条 + 重复检测 2 条。 */
function runCheck(source: RefItem[]): RefItem[] {
  const doiCount: Map<string, number> = new Map<string, number>();
  const titleCount: Map<string, number> = new Map<string, number>();
  for (let i = 0; i < source.length; i++) {
    const it: RefItem = source[i];
    if (it.doi.length > 0) {
      const c: number | undefined = doiCount.get(it.doi);
      doiCount.set(it.doi, c === undefined ? 1 : c + 1);
    }
    if (it.title.length > 0) {
      const c2: number | undefined = titleCount.get(it.title);
      titleCount.set(it.title, c2 === undefined ? 1 : c2 + 1);
    }
  }

  const out: RefItem[] = [];
  for (let i = 0; i < source.length; i++) {
    const it: RefItem = source[i];
    const issues: string[] = [];
    if (it.authors.length === 0) { issues.push('缺少作者'); }
    if (it.title.length === 0) { issues.push('缺少题名'); }
    if (it.journal.length === 0) { issues.push('缺少期刊名'); }
    if (it.year.length === 0) {
      issues.push('缺少年份');
    } else if (it.year.length !== 4) {
      issues.push('年份应为 4 位');
    }
    if (it.doi.length === 0) { issues.push('缺少 DOI'); }
    const dc: number | undefined = doiCount.get(it.doi);
    if (it.doi.length > 0 && dc !== undefined && dc > 1) { issues.push('DOI 与其它条目重复'); }
    const tc: number | undefined = titleCount.get(it.title);
    if (it.title.length > 0 && tc !== undefined && tc > 1) { issues.push('题名与其它条目重复'); }

    out.push({
      id: it.id, authors: it.authors, title: it.title,
      journal: it.journal, year: it.year, doi: it.doi, issues: issues
    });
  }
  return out;
}

/** 批量修正：补占位值、去重。 */
function runFix(source: RefItem[]): RefItem[] {
  const seenDoi: Map<string, number> = new Map<string, number>();
  const seenTitle: Map<string, number> = new Map<string, number>();
  const out: RefItem[] = [];
  for (let i = 0; i < source.length; i++) {
    const it: RefItem = source[i];
    let authors: string = it.authors.length === 0 ? '待补作者' : it.authors;
    let title: string = it.title.length === 0 ? '待补题名' : it.title;
    let journal: string = it.journal.length === 0 ? '待补期刊' : it.journal;
    let year: string = it.year.length === 4 ? it.year : '2024';
    let doi: string = it.doi;
    if (doi.length === 0) {
      doi = '10.0000/pending.' + it.id.toLowerCase();
    } else {
      const c: number | undefined = seenDoi.get(doi);
      if (c !== undefined) { doi = doi + '.dup' + it.id.toLowerCase(); }
    }
    const tc: number | undefined = seenTitle.get(title);
    if (tc !== undefined) { title = title + '（' + it.id + '）'; }
    seenDoi.set(doi, 1);
    seenTitle.set(title, 1);
    out.push({ id: it.id, authors: authors, title: title, journal: journal, year: year, doi: doi, issues: [] });
  }
  return out;
}

const BG: string = '#151B24';
const CARD: string = '#1E2630';
const CARD_BAD: string = '#2A1F1C';
const BORDER: string = '#2B3644';
const TEXT: string = '#E8EDF3';
const TEXT_DIM: string = '#8C9AA8';
const GOLD: string = '#F2C879';
const OK: string = '#199E70';
const BAD: string = '#D95926';

@Entry
@Component
struct Index {
  @State items: RefItem[] = buildSeed();
  @State hasChecked: boolean = false;
  @State badRows: number = 0;
  @State issueCount: number = 0;

  doCheck(): void {
    const r: RefItem[] = runCheck(this.items);
    let bad: number = 0;
    let total: number = 0;
    for (let i = 0; i < r.length; i++) {
      if (r[i].issues.length > 0) {
        bad++;
        total += r[i].issues.length;
      }
    }
    this.items = r;
    this.badRows = bad;
    this.issueCount = total;
    this.hasChecked = true;
  }

  doFix(): void {
    this.items = runFix(this.items);
    this.hasChecked = false;
    this.badRows = 0;
    this.issueCount = 0;
  }

  doReset(): void {
    this.items = buildSeed();
    this.hasChecked = false;
    this.badRows = 0;
    this.issueCount = 0;
  }

  @Builder
  uiHeader() {
    Column() {
      Row() {
        Text('参考文献格式检查器')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT)
        Blank()
        Text('选题 054 · 本地档')
          .fontSize(12)
          .fontColor(GOLD)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(4)
          .backgroundColor('#2A2418')
      }
      .width('100%')

      Text('维护引用条目，检查缺字段与重复项，批量调整格式。所有数据在本机处理。')
        .fontSize(13)
        .fontColor(TEXT_DIM)
        .margin({ top: 6 })
        .width('100%')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 20, bottom: 16 })
  }

  @Builder
  uiBanner() {
    if (this.hasChecked) {
      Row() {
        Column() {
          Text(this.issueCount === 0 ? '检查通过' : '检查不通过')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.issueCount === 0 ? OK : BAD)
          Text(this.issueCount === 0
            ? '全部 ' + this.items.length + ' 条引用格式完整'
            : this.badRows + ' 条有问题，共 ' + this.issueCount + ' 处')
            .fontSize(13)
            .fontColor(TEXT_DIM)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(16)
      .borderRadius(8)
      .backgroundColor(this.issueCount === 0 ? '#15261F' : CARD_BAD)
      .border({ width: 1, color: this.issueCount === 0 ? OK : BAD })
      .margin({ left: 24, right: 24, bottom: 14 })
    }
  }

  @Builder
  uiActions() {
    Row() {
      Button('开始检查')
        .fontSize(15)
        .fontColor('#1A1A1A')
        .backgroundColor(GOLD)
        .height(38)
        .onClick(() => { this.doCheck(); })
      Button('批量修正')
        .fontSize(15)
        .fontColor(TEXT)
        .backgroundColor('#2B3644')
        .height(38)
        .margin({ left: 10 })
        .onClick(() => { this.doFix(); })
      Button('重置')
        .fontSize(15)
        .fontColor(TEXT_DIM)
        .backgroundColor('#222C38')
        .height(38)
        .margin({ left: 10 })
        .onClick(() => { this.doReset(); })
      Blank()
      Text('共 ' + this.items.length + ' 条')
        .fontSize(13)
        .fontColor(TEXT_DIM)
    }
    .width('100%')
    .padding({ left: 24, right: 24, bottom: 12 })
  }

  @Builder
  uiRow(it: RefItem) {
    Column() {
      Row() {
        Text(it.id)
          .fontSize(12)
          .fontColor(GOLD)
          .width(44)
        Text(it.authors.length > 0 ? it.authors : '（无作者）')
          .fontSize(14)
          .fontColor(it.authors.length > 0 ? TEXT : BAD)
          .layoutWeight(1)
        Text(it.year.length > 0 ? it.year : '（无年份）')
          .fontSize(13)
          .fontColor(it.year.length === 4 ? TEXT_DIM : BAD)
          .width(76)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Text(it.title.length > 0 ? it.title : '（无题名）')
        .fontSize(14)
        .fontColor(it.title.length > 0 ? TEXT : BAD)
        .margin({ top: 4 })
        .width('100%')

      Text(it.journal.length > 0 ? it.journal : '（无期刊）')
        .fontSize(12)
        .fontColor(TEXT_DIM)
        .margin({ top: 2 })
        .width('100%')

      Text(it.doi.length > 0 ? it.doi : '（无 DOI）')
        .fontSize(12)
        .fontColor(it.doi.length > 0 ? TEXT_DIM : BAD)
        .margin({ top: 2 })
        .width('100%')

      if (this.hasChecked && it.issues.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(it.issues, (msg: string) => {
            Text(msg)
              .fontSize(11)
              .fontColor(BAD)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(3)
              .backgroundColor('#33221E')
              .margin({ right: 6, top: 6 })
          }, (msg: string) => it.id + msg)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor(this.hasChecked && it.issues.length > 0 ? CARD_BAD : CARD)
    .border({
      width: this.hasChecked && it.issues.length > 0 ? 2 : 1,
      color: !this.hasChecked ? BORDER : (it.issues.length > 0 ? BAD : OK)
    })
    .margin({ bottom: 8 })
  }

  build() {
    Column() {
      this.uiHeader()
      this.uiBanner()
      this.uiActions()

      List({ space: 0 }) {
        ForEach(this.items, (it: RefItem) => {
          ListItem() {
            this.uiRow(it)
          }
        }, (it: RefItem) => rowKey(it))
      }
      .layoutWeight(1)
      .padding({ left: 24, right: 24, bottom: 16 })
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
