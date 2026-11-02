import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  PlanItem,
  generateId,
  planDoneCount,
  planRequiredCount,
  pointPerCheckIn
} from '../model/DakaModel';

const MAX_TIMES_PER_DAY: number = 20;
const MAX_TOTAL_DAYS: number = 365;
const DOMAIN: number = 0x0000;
const TAG: string = 'PlanView';

@Component
export struct PlanView {
  @Link plans: PlanItem[];
  @Link records: CheckInRecord[];
  onAddPlan: (plan: PlanItem) => void = () => {
  };
  onRemovePlan: (planId: string) => void = () => {
  };

  @State draftName: string = '';
  @State draftTimes: number = 1;
  @State draftDays: number = 7;
  @State draftRemark: string = '';

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', error.message);
    }
  }

  private stepValue(target: string, delta: number): void {
    if (target === 'times') {
      const next: number = this.draftTimes + delta;
      if (next >= 1 && next <= MAX_TIMES_PER_DAY) {
        this.draftTimes = next;
      }
      return;
    }
    const nextDays: number = this.draftDays + delta;
    if (nextDays >= 1 && nextDays <= MAX_TOTAL_DAYS) {
      this.draftDays = nextDays;
    }
  }

  private submit(): void {
    const name: string = this.draftName.trim();
    if (name.length === 0) {
      this.toast('请先填写目标名称');
      return;
    }
    const plan: PlanItem = new PlanItem();
    plan.id = generateId('plan');
    plan.name = name;
    plan.timesPerDay = this.draftTimes;
    plan.totalDays = this.draftDays;
    plan.remark = this.draftRemark.trim();
    plan.createdAt = Date.now();
    this.onAddPlan(plan);

    this.draftName = '';
    this.draftTimes = 1;
    this.draftDays = 7;
    this.draftRemark = '';
    this.toast(`已添加「${name}」`);
  }

  private confirmRemove(plan: PlanItem): void {
    this.getUIContext().showAlertDialog({
      title: '删除这个计划？',
      message: `「${plan.name}」以及它的打卡记录都会被删除。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppColor.danger,
        action: () => {
          this.onRemovePlan(plan.id);
          this.toast('计划已删除');
        }
      }
    });
  }

  @Builder
  stepperRow(label: string, hint: string, value: number, target: string, min: number, max: number) {
    Row() {
      Column() {
        Text(label)
          .fontSize(14)
          .fontColor(AppColor.textMain)
        Text(hint)
          .fontSize(11)
          .fontColor(AppColor.textSub)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row() {
        Button({ type: ButtonType.Circle }) {
          AppIcon({ commands: IconPath.minus, iconSize: 14, color: AppColor.textMain, strokeW: 1.8 })
        }
        .width(30)
        .height(30)
        .backgroundColor('#F1F3F6')
        .enabled(value > min)
        .onClick(() => {
          this.stepValue(target, -1);
        })

        Text(`${value}`)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textMain)
          .width(52)
          .textAlign(TextAlign.Center)

        Button({ type: ButtonType.Circle }) {
          AppIcon({ commands: IconPath.plus, iconSize: 14, color: AppColor.primary, strokeW: 1.8 })
        }
        .width(30)
        .height(30)
        .backgroundColor(AppColor.primarySoft)
        .enabled(value < max)
        .onClick(() => {
          this.stepValue(target, 1);
        })
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  planCard(plan: PlanItem) {
    Column() {
      Row() {
        Column() {
          Text(plan.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`每天 ${plan.timesPerDay} 次 · 共 ${plan.totalDays} 天 · 合计 ${planRequiredCount(plan)} 次`)
            .fontSize(11)
            .fontColor(AppColor.textSub)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button({ type: ButtonType.Circle }) {
          AppIcon({ commands: IconPath.trash, iconSize: 16, color: AppColor.danger, strokeW: 1.7 })
        }
        .width(30)
        .height(30)
        .backgroundColor(AppColor.dangerSoft)
        .onClick(() => {
          this.confirmRemove(plan);
        })
      }
      .width('100%')

      Row() {
        Text(`已完成 ${planDoneCount(this.records, plan.id)} / ${planRequiredCount(plan)} 次`)
          .fontSize(12)
          .fontColor(AppColor.textSub)
        Text(planDoneCount(this.records, plan.id) >= planRequiredCount(plan) ? '已达成' : '进行中')
          .fontSize(11)
          .fontColor(planDoneCount(this.records, plan.id) >= planRequiredCount(plan)
            ? AppColor.primary
            : AppColor.info)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(planDoneCount(this.records, plan.id) >= planRequiredCount(plan)
            ? AppColor.primarySoft
            : AppColor.infoSoft)
          .borderRadius(4)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })

      Progress({
        value: planDoneCount(this.records, plan.id),
        total: planRequiredCount(plan) > 0 ? planRequiredCount(plan) : 1,
        type: ProgressType.Linear
      })
        .height(6)
        .width('100%')
        .color(AppColor.primary)
        .backgroundColor('#EEF1F4')
        .margin({ top: 8 })

      if (plan.remark.length > 0) {
        Text(plan.remark)
          .fontSize(12)
          .fontColor(AppColor.textSub)
          .width('100%')
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColor.card)
    .borderRadius(AppSize.radiusCard)
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Text('新建打卡计划')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)

          Text('目标名称')
            .fontSize(12)
            .fontColor(AppColor.textSub)
            .margin({ top: 14, bottom: 6 })
          TextInput({ placeholder: '例如：晨跑 / 背单词 / 早睡', text: this.draftName })
            .height(42)
            .fontSize(14)
            .backgroundColor('#F5F7F9')
            .borderRadius(AppSize.radiusInner)
            .placeholderColor(AppColor.textWeak)
            .onChange((value: string) => {
              this.draftName = value;
            })

          this.stepperRow('每天打卡次数', `1 ~ ${MAX_TIMES_PER_DAY} 次`, this.draftTimes, 'times', 1,
            MAX_TIMES_PER_DAY)
          Divider().color(AppColor.line)
          this.stepperRow('打卡总天数', `1 ~ ${MAX_TOTAL_DAYS} 天`, this.draftDays, 'days', 1, MAX_TOTAL_DAYS)

          Text('备注（可选）')
            .fontSize(12)
            .fontColor(AppColor.textSub)
            .margin({ top: 10, bottom: 6 })
          TextInput({ placeholder: '给自己一句提醒', text: this.draftRemark })
            .height(42)
            .fontSize(14)
            .backgroundColor('#F5F7F9')
            .borderRadius(AppSize.radiusInner)
            .placeholderColor(AppColor.textWeak)
            .onChange((value: string) => {
              this.draftRemark = value;
            })

          Row() {
            AppIcon({ commands: IconPath.reward, iconSize: 14, color: AppColor.amber, strokeW: 1.7 })
            Text(`合计需打卡 ${this.draftTimes * this.draftDays} 次，每完成一次 +${pointPerCheckIn(this.previewPlans())} 分`)
              .fontSize(11)
              .fontColor(AppColor.textSub)
              .margin({ left: 6 })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 8, bottom: 8 })
          .backgroundColor(AppColor.amberSoft)
          .borderRadius(AppSize.radiusInner)
          .margin({ top: 14 })

          Button({ type: ButtonType.Capsule }) {
            Row() {
              AppIcon({ commands: IconPath.plus, iconSize: 16, color: Color.White, strokeW: 2 })
              Text('添加计划')
                .fontSize(14)
                .fontColor(Color.White)
                .margin({ left: 6 })
            }
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(44)
          .backgroundColor(AppColor.primary)
          .margin({ top: 14 })
          .onClick(() => {
            this.submit();
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .alignItems(HorizontalAlign.Start)
        .margin({ top: AppSize.gap })

        Row() {
          Text('我的计划')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
          Text(`共 ${this.plans.length} 个`)
            .fontSize(11)
            .fontColor(AppColor.textSub)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 20, bottom: 10 })

        if (this.plans.length === 0) {
          Column() {
            Text('还没有计划，先在上面添加一个吧')
              .fontSize(12)
              .fontColor(AppColor.textSub)
          }
          .width('100%')
          .padding({ top: 24, bottom: 24 })
          .backgroundColor(AppColor.card)
          .borderRadius(AppSize.radiusCard)
        } else {
          ForEach(this.plans, (plan: PlanItem) => {
            Column() {
              this.planCard(plan)
            }
            .margin({ bottom: AppSize.gap })
          }, (plan: PlanItem) => plan.id)
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

  /** 仅用于输入过程中预览「每次打卡加多少分」。 */
  private previewPlans(): PlanItem[] {
    const list: PlanItem[] = [];
    for (let i = 0; i < this.plans.length; i++) {
      list.push(this.plans[i]);
    }
    const draft: PlanItem = new PlanItem();
    draft.timesPerDay = this.draftTimes;
    draft.totalDays = this.draftDays;
    list.push(draft);
    return list;
  }
}
