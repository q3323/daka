import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  ClassMember,
  KIND_ADD,
  formatDateTime
} from '../model/DakaModel';

@Component
export struct TeacherTaskDetailView {
  @Link members: ClassMember[];
  @Link records: CheckInRecord[];
  @Prop classId: string = '';
  @Prop className: string = '';
  @Prop classCode: string = '';
  @Prop taskId: string = '';
  @Prop taskContent: string = '';
  @Prop requiresPhoto: boolean = true;
  @Prop memberCount: number = 0;
  @State loadedPhotoIds: string[] = [];
  onBack: () => void = () => {
  };

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
      if (record.kind === KIND_ADD && record.taskId === this.taskId && record.memberId === memberId) {
        list.push(record);
      }
    }
    list.sort((a: CheckInRecord, b: CheckInRecord) => b.time - a.time);
    return list;
  }

  private hasCompleted(memberId: string): boolean {
    return this.memberRecords(memberId).length > 0;
  }

  private totalMemberCount(): number {
    return Math.max(this.memberCount, this.classMembers().length);
  }

  private latestRecord(memberId: string): CheckInRecord | undefined {
    const list: CheckInRecord[] = this.memberRecords(memberId);
    return list.length > 0 ? list[0] : undefined;
  }

  private uncompletedMembers(): ClassMember[] {
    const list: ClassMember[] = [];
    const members: ClassMember[] = this.classMembers();
    for (let i = 0; i < members.length; i++) {
      if (!this.hasCompleted(members[i].id)) {
        list.push(members[i]);
      }
    }
    return list;
  }

  private completedMembers(): ClassMember[] {
    const list: ClassMember[] = [];
    const members: ClassMember[] = this.classMembers();
    for (let i = 0; i < members.length; i++) {
      if (this.hasCompleted(members[i].id)) {
        list.push(members[i]);
      }
    }
    return list;
  }

  private isPhotoLoaded(recordId: string): boolean {
    return this.loadedPhotoIds.indexOf(recordId) >= 0;
  }

  private loadPhoto(recordId: string): void {
    if (this.isPhotoLoaded(recordId)) {
      return;
    }
    const next: string[] = this.loadedPhotoIds.slice();
    next.push(recordId);
    this.loadedPhotoIds = next;
  }

  @Builder
  memberAvatar(name: string, color: string) {
    Column() {
      Text(name.length > 0 ? name.substring(0, 1) : '学')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
    .width(36)
    .height(36)
    .borderRadius(18)
    .backgroundColor(color)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  uncompletedCard(member: ClassMember) {
    Row() {
      this.memberAvatar(member.name, AppColor.amber)
      Column() {
        Text(member.name)
          .fontSize(14)
          .fontColor(AppColor.textMain)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('还没有完成这次打卡')
          .fontSize(10)
          .fontColor(AppColor.textSub)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text('未打卡')
        .fontSize(10)
        .fontColor(AppColor.amber)
        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
        .backgroundColor(AppColor.amberSoft)
        .borderRadius(4)
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
  }

  @Builder
  completedCard(member: ClassMember) {
    Row() {
      this.memberAvatar(member.name, AppColor.primary)
      Column() {
        Row() {
          Text(member.name)
            .fontSize(14)
            .fontColor(AppColor.textMain)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('已打卡')
            .fontSize(10)
            .fontColor(AppColor.primary)
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(AppColor.primarySoft)
            .borderRadius(4)
        }
        .width('100%')

        if (this.latestRecord(member.id) !== undefined) {
          Text(formatDateTime((this.latestRecord(member.id) as CheckInRecord).time))
            .fontSize(10)
            .fontColor(AppColor.textSub)
            .margin({ top: 4 })
          Text((this.latestRecord(member.id) as CheckInRecord).content.length > 0
            ? (this.latestRecord(member.id) as CheckInRecord).content
            : '未填写打卡内容')
            .fontSize(11)
            .fontColor(AppColor.textWeak)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 3 })
          if ((this.latestRecord(member.id) as CheckInRecord).photoUri.length > 0) {
            if (this.isPhotoLoaded((this.latestRecord(member.id) as CheckInRecord).id)) {
              Image((this.latestRecord(member.id) as CheckInRecord).photoUri)
                .width(160)
                .height(120)
                .borderRadius(AppSize.radiusInner)
                .objectFit(ImageFit.Cover)
                .margin({ top: 8 })
            } else {
              Text('查看照片')
                .fontSize(10)
                .fontColor(AppColor.primary)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(AppColor.primarySoft)
                .borderRadius(4)
                .margin({ top: 7 })
                .onClick(() => {
                  this.loadPhoto((this.latestRecord(member.id) as CheckInRecord).id);
                })
            }
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
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
            Text('任务详情')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textMain)
            Text(`${this.className} · 班级号 ${this.classCode}`)
              .fontSize(11)
              .fontColor(AppColor.textSub)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 10 })
        }
        .width('100%')

        Column() {
          Text(this.taskContent)
            .fontSize(15)
            .fontColor(AppColor.textMain)
            .width('100%')

          Row() {
            Text(this.requiresPhoto ? '需要上传照片' : '不需要照片')
              .fontSize(10)
              .fontColor(this.requiresPhoto ? AppColor.primary : AppColor.info)
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .backgroundColor(this.requiresPhoto ? AppColor.primarySoft : AppColor.infoSoft)
              .borderRadius(4)
            Blank()
            Text(`已完成 ${this.completedMembers().length} / ${this.totalMemberCount()} 人`)
              .fontSize(11)
              .fontColor(AppColor.textSub)
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap })

        Row() {
          Text('未打卡')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
          Text(`${this.uncompletedMembers().length} 人`)
            .fontSize(11)
            .fontColor(AppColor.amber)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 20, bottom: 10 })

        Column() {
          if (this.uncompletedMembers().length === 0) {
            Text('全部学生都已完成')
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .width('100%')
              .padding({ top: 18, bottom: 18 })
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.uncompletedMembers(), (member: ClassMember) => {
              this.uncompletedCard(member)
            }, (member: ClassMember) => member.id)
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)

        Row() {
          Text('已打卡')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
          Text(`${this.completedMembers().length} 人`)
            .fontSize(11)
            .fontColor(AppColor.primary)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 20, bottom: 10 })

        Column() {
          if (this.completedMembers().length === 0) {
            Text('还没有学生完成')
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .width('100%')
              .padding({ top: 18, bottom: 18 })
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.completedMembers(), (member: ClassMember) => {
              this.completedCard(member)
            }, (member: ClassMember) => member.id)
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ bottom: 8 })
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
