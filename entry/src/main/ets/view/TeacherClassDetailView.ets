import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  ClassMember,
  KIND_ADD,
  formatDateTime,
  todayKey
} from '../model/DakaModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'TeacherClassDetailView';

@Component
export struct TeacherClassDetailView {
  @Link members: ClassMember[];
  @Link records: CheckInRecord[];
  @Prop classId: string = '';
  @Prop className: string = '';
  @Prop classCode: string = '';
  onBack: () => void = () => {
  };
  onOpenStudent: (member: ClassMember) => void = () => {
  };
  onRemoveMember: (memberId: string) => Promise<boolean> = async () => false;
  onRefresh: () => Promise<void> = async () => {
  };
  @State refreshing: boolean = false;

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', error.message);
    }
  }

  private classMembers(): ClassMember[] {
    const list: ClassMember[] = [];
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].classId === this.classId) {
        list.push(this.members[i]);
      }
    }
    return list;
  }

  private memberRecords(memberId: string): CheckInRecord[] {
    const list: CheckInRecord[] = [];
    for (let i = 0; i < this.records.length; i++) {
      const record: CheckInRecord = this.records[i];
      if (record.kind === KIND_ADD && record.memberId === memberId) {
        list.push(record);
      }
    }
    return list;
  }

  private memberById(memberId: string): ClassMember | undefined {
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].id === memberId) {
        return this.members[i];
      }
    }
    return undefined;
  }

  private todayCount(memberId: string): number {
    const member: ClassMember | undefined = this.memberById(memberId);
    if (member !== undefined && member.userId.length > 0) {
      return member.todayCount;
    }
    const list: CheckInRecord[] = this.memberRecords(memberId);
    const key: string = todayKey();
    let count: number = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].dayKey === key) {
        count++;
      }
    }
    return count;
  }

  private totalCount(memberId: string): number {
    const member: ClassMember | undefined = this.memberById(memberId);
    if (member !== undefined && member.userId.length > 0) {
      return member.totalCount;
    }
    return this.memberRecords(memberId).length;
  }

  private lastCheckInText(memberId: string): string {
    const member: ClassMember | undefined = this.memberById(memberId);
    if (member !== undefined && member.userId.length > 0) {
      return member.lastCheckInAt > 0 ? `最近签到 ${formatDateTime(member.lastCheckInAt)}` : '暂无签到记录';
    }
    const list: CheckInRecord[] = this.memberRecords(memberId);
    if (list.length === 0) {
      return '暂无签到记录';
    }
    let latest: CheckInRecord = list[0];
    for (let i = 1; i < list.length; i++) {
      if (list[i].time > latest.time) {
        latest = list[i];
      }
    }
    return `最近签到 ${formatDateTime(latest.time)}`;
  }

  private statusText(memberId: string): string {
    return this.todayCount(memberId) > 0 ? '今日已打卡' : '今日未打卡';
  }

  private confirmRemove(member: ClassMember): void {
    this.getUIContext().showAlertDialog({
      title: '移除学生？',
      message: `「${member.name}」将从班级中移除，后续不能再查看该学生的签到状态。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '移除',
        fontColor: AppColor.danger,
        action: async () => {
          if (await this.onRemoveMember(member.id)) {
            this.toast('学生已移除');
          }
        }
      }
    });
  }

  private async refresh(): Promise<void> {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    try {
      await this.onRefresh();
    } finally {
      this.refreshing = false;
    }
  }

  @Builder
  memberCard(member: ClassMember) {
    Column() {
      Row() {
        Column() {
          Text(member.name.substring(0, 1))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(38)
        .height(38)
        .borderRadius(19)
        .backgroundColor(AppColor.primary)
        .justifyContent(FlexAlign.Center)

        Column() {
          Row() {
            Text(member.name)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textMain)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text(this.statusText(member.id))
              .fontSize(10)
              .fontColor(this.todayCount(member.id) > 0 ? AppColor.primary : AppColor.amber)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.todayCount(member.id) > 0 ? AppColor.primarySoft : AppColor.amberSoft)
              .borderRadius(4)
          }
          .width('100%')

          Text(`今日 ${this.todayCount(member.id)} 次 · 累计 ${this.totalCount(member.id)} 次`)
            .fontSize(11)
            .fontColor(AppColor.textSub)
            .margin({ top: 4 })
          Text(this.lastCheckInText(member.id))
            .fontSize(10)
            .fontColor(AppColor.textWeak)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 10 })

        Button('移除')
          .fontSize(11)
          .fontColor(AppColor.danger)
          .height(30)
          .padding({ left: 10, right: 10 })
          .backgroundColor(AppColor.dangerSoft)
          .onClick(() => {
            this.confirmRemove(member);
          })
      }
      .width('100%')

      Row() {
        AppIcon({ commands: IconPath.gallery, iconSize: 15, color: AppColor.primary, strokeW: 1.8 })
        Text('查看打卡详情')
          .fontSize(12)
          .fontColor(AppColor.primary)
          .margin({ left: 6 })
        Blank()
        AppIcon({ commands: IconPath.chevronRight, iconSize: 14, color: AppColor.textWeak, strokeW: 1.7 })
      }
      .width('100%')
      .padding({ top: 8 })
      .onClick(() => {
        this.onOpenStudent(member);
      })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: AppColor.line })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) {
            AppIcon({ commands: IconPath.chevronLeft, iconSize: 17, color: AppColor.textMain, strokeW: 1.9 })
          }
          .width(36)
          .height(36)
          .backgroundColor('#F1F3F6')
          .onClick(() => {
            this.onBack();
          })

          Column() {
            Text(`${this.className} · 学生`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textMain)
            Text(`班级号 ${this.classCode}`)
              .fontSize(11)
              .fontColor(AppColor.textSub)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 10 })

          Column() {
            Text(`${this.classMembers().length} 人`)
              .fontSize(11)
              .fontColor(AppColor.textSub)
            Text(this.refreshing ? '刷新中' : '刷新')
              .fontSize(10)
              .fontColor(AppColor.primary)
              .margin({ top: 4 })
              .onClick(() => {
                this.refresh();
              })
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')

        Column() {
          if (this.classMembers().length === 0) {
            Column() {
              AppIcon({ commands: IconPath.users, iconSize: 28, color: AppColor.textWeak, strokeW: 1.6 })
              Text('还没有学生加入')
                .fontSize(12)
                .fontColor(AppColor.textSub)
                .margin({ top: 10 })
            }
            .width('100%')
            .padding({ top: 30, bottom: 30 })
            .justifyContent(FlexAlign.Center)
          } else {
            ForEach(this.classMembers(), (member: ClassMember) => {
              this.memberCard(member)
            }, (member: ClassMember) => member.id)
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap })
      }
      .width('100%')
      .padding(AppSize.pagePadding)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
