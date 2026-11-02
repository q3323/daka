import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  KIND_ADD,
  formatDateTime,
  todayKey
} from '../model/DakaModel';

@Component
export struct TeacherStudentDetailView {
  @Link records: CheckInRecord[];
  @Prop memberId: string = '';
  @Prop memberName: string = '';
  @Prop className: string = '';
  @State loadedPhotoIds: string[] = [];
  onBack: () => void = () => {
  };

  private memberRecordsSorted(): CheckInRecord[] {
    const list: CheckInRecord[] = [];
    for (let i = 0; i < this.records.length; i++) {
      const record: CheckInRecord = this.records[i];
      if (record.kind === KIND_ADD && record.memberId === this.memberId) {
        list.push(record);
      }
    }
    list.sort((a: CheckInRecord, b: CheckInRecord) => b.time - a.time);
    return list;
  }

  private todayCount(): number {
    const list: CheckInRecord[] = this.memberRecordsSorted();
    const key: string = todayKey();
    let count: number = 0;
    for (let i = 0; i < list.length; i++) {
      if (list[i].dayKey === key) {
        count++;
      }
    }
    return count;
  }

  private totalCount(): number {
    return this.memberRecordsSorted().length;
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
  recordCard(record: CheckInRecord) {
    Column() {
      Row() {
        Text(formatDateTime(record.time))
          .fontSize(12)
          .fontColor(AppColor.textSub)
        Blank()
        Text(record.planName)
          .fontSize(10)
          .fontColor(AppColor.primary)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(AppColor.primarySoft)
          .borderRadius(4)
      }
      .width('100%')

      Row() {
        if (record.photoUri.length > 0 && this.isPhotoLoaded(record.id)) {
          Image(record.photoUri)
            .width(76)
            .height(76)
            .borderRadius(AppSize.radiusInner)
            .objectFit(ImageFit.Cover)
        } else if (record.photoUri.length > 0) {
          Column() {
            AppIcon({ commands: IconPath.gallery, iconSize: 20, color: AppColor.primary, strokeW: 1.7 })
            Text('查看照片')
              .fontSize(9)
              .fontColor(AppColor.primary)
              .margin({ top: 3 })
          }
          .width(76)
          .height(76)
          .borderRadius(AppSize.radiusInner)
          .backgroundColor(AppColor.primarySoft)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.loadPhoto(record.id);
          })
        } else {
          Column() {
            AppIcon({ commands: IconPath.gallery, iconSize: 21, color: AppColor.textWeak, strokeW: 1.6 })
            Text('暂无照片')
              .fontSize(9)
              .fontColor(AppColor.textWeak)
              .margin({ top: 3 })
          }
          .width(76)
          .height(76)
          .borderRadius(AppSize.radiusInner)
          .backgroundColor('#EDF1F4')
          .justifyContent(FlexAlign.Center)
        }

        Column() {
          Text(record.content.length > 0 ? record.content : '未填写打卡内容')
            .fontSize(13)
            .fontColor(AppColor.textMain)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('已打卡')
            .fontSize(10)
            .fontColor(AppColor.primary)
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 10 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
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
            Text(`${this.memberName} · 打卡详情`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textMain)
            Text(this.className)
              .fontSize(11)
              .fontColor(AppColor.textSub)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 10 })
        }
        .width('100%')

        Row() {
          Column() {
            Text(`${this.todayCount()}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.primary)
            Text('今日打卡')
              .fontSize(10)
              .fontColor(AppColor.textSub)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          Divider().vertical(true).height(28).color(AppColor.line)
          Column() {
            Text(`${this.totalCount()}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textMain)
            Text('累计打卡')
              .fontSize(10)
              .fontColor(AppColor.textSub)
              .margin({ top: 3 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap })

        Column() {
          if (this.memberRecordsSorted().length === 0) {
            Column() {
              AppIcon({ commands: IconPath.gallery, iconSize: 28, color: AppColor.textWeak, strokeW: 1.6 })
              Text('暂无打卡详情')
                .fontSize(12)
                .fontColor(AppColor.textSub)
                .margin({ top: 10 })
            }
            .width('100%')
            .padding({ top: 30, bottom: 30 })
            .justifyContent(FlexAlign.Center)
          } else {
            ForEach(this.memberRecordsSorted(), (record: CheckInRecord) => {
              this.recordCard(record)
            }, (record: CheckInRecord) => record.id)
          }
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap, bottom: 8 })
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
