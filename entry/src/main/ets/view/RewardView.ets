import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  KIND_ADD,
  formatDateTime,
  formatPoint,
  scoreLevel,
  sumAddedPoints,
  sumCutPoints,
  totalDoneCount
} from '../model/DakaModel';

@Component
export struct RewardView {
  @Link records: CheckInRecord[];
  @Prop score: number = 0;
  @Prop perPoint: number = 0;
  @Prop totalRequired: number = 0;
  @Prop totalDone: number = 0;

  private ledger(): CheckInRecord[] {
    return this.records.slice().sort((a: CheckInRecord, b: CheckInRecord) => b.time - a.time);
  }

  @Builder
  statCell(label: string, value: string, color: ResourceColor) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(AppColor.textSub)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ledgerItem(record: CheckInRecord) {
    Row() {
      Column() {
        AppIcon({
          commands: record.point >= 0 ? IconPath.plus : IconPath.minus,
          iconSize: 15,
          color: record.point >= 0 ? AppColor.amber : AppColor.danger,
          strokeW: 2
        })
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor(record.point >= 0 ? AppColor.amberSoft : AppColor.dangerSoft)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(record.kind === KIND_ADD ? `${record.planName} · 打卡` : `${record.planName} · 撤销打卡`)
          .fontSize(14)
          .fontColor(AppColor.textMain)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Text(formatDateTime(record.time))
            .fontSize(11)
            .fontColor(AppColor.textSub)
          if (record.photoUri.length > 0) {
            Text('已上传照片')
              .fontSize(10)
              .fontColor(AppColor.primary)
              .padding({ left: 6, right: 6, top: 1, bottom: 1 })
              .backgroundColor(AppColor.primarySoft)
              .borderRadius(3)
              .margin({ left: 6 })
          }
        }
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text(formatPoint(record.point))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(record.point >= 0 ? AppColor.amber : AppColor.danger)
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Row() {
            Text('当前积分')
              .fontSize(13)
              .fontColor('#E7FBF1')
              .layoutWeight(1)
            Text(scoreLevel(this.score))
              .fontSize(11)
              .fontColor(Color.White)
              .padding({ left: 10, right: 10, top: 3, bottom: 3 })
              .backgroundColor('#FFFFFF33')
              .borderRadius(10)
          }
          .width('100%')

          Row() {
            Text(`${this.score}`)
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text(' / 100')
              .fontSize(14)
              .fontColor('#D6F5E6')
              .margin({ left: 2, bottom: 8 })
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
          .margin({ top: 4 })

          Progress({ value: this.score, total: 100, type: ProgressType.Linear })
            .height(8)
            .width('100%')
            .color(Color.White)
            .backgroundColor('#FFFFFF33')
            .margin({ top: 6 })

          Text(`已完成 ${this.totalDone} / ${this.totalRequired} 次打卡`)
            .fontSize(11)
            .fontColor('#E7FBF1')
            .margin({ top: 10 })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(AppColor.primary)
        .borderRadius(AppSize.radiusCard)
        .alignItems(HorizontalAlign.Start)
        .margin({ top: AppSize.gap })

        Row() {
          this.statCell('累计奖励', `+${sumAddedPoints(this.records)}`, AppColor.amber)
          Divider().vertical(true).height(28).color(AppColor.line)
          this.statCell('累计惩罚', `-${sumCutPoints(this.records)}`, AppColor.danger)
          Divider().vertical(true).height(28).color(AppColor.line)
          this.statCell('有效打卡', `${totalDoneCount(this.records)} 次`, AppColor.primary)
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap })

        Column() {
          Text('奖惩规则')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)

          Row() {
            Column().width(6).height(6).borderRadius(3).backgroundColor(AppColor.primary)
            Text('基础分为 0 分，满分 100 分。')
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .margin({ left: 8 })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 12 })

          Row() {
            Column().width(6).height(6).borderRadius(3).backgroundColor(AppColor.amber)
            Text(`每完成一次打卡：奖励 100 ÷ 总需打卡次数，当前为 +${this.perPoint} 分。`)
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .margin({ left: 8 })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 10 })

          Row() {
            Column().width(6).height(6).borderRadius(3).backgroundColor(AppColor.danger)
            Text(`每撤销一次打卡：扣掉 ${this.perPoint} 分，积分不会低于 0 分。`)
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .margin({ left: 8 })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .alignItems(HorizontalAlign.Start)
        .margin({ top: AppSize.gap })

        Row() {
          Text('积分明细')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
          Text(`共 ${this.records.length} 条`)
            .fontSize(11)
            .fontColor(AppColor.textSub)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 20, bottom: 10 })

        if (this.records.length === 0) {
          Column() {
            AppIcon({ commands: IconPath.reward, iconSize: 26, color: AppColor.textWeak, strokeW: 1.6 })
            Text('还没有积分记录')
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .margin({ top: 10 })
            Text('去首页拍张照片完成第一次打卡吧')
              .fontSize(11)
              .fontColor(AppColor.textWeak)
              .margin({ top: 4 })
          }
          .width('100%')
          .padding({ top: 26, bottom: 26 })
          .backgroundColor(AppColor.card)
          .borderRadius(AppSize.radiusCard)
        } else {
          Column() {
            ForEach(this.ledger(), (record: CheckInRecord) => {
              this.ledgerItem(record)
            }, (record: CheckInRecord) => record.id)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(AppColor.card)
          .borderRadius(AppSize.radiusCard)
        }
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
