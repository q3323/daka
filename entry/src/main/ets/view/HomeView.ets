import { camera, cameraPicker } from '@kit.CameraKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  KIND_ADD,
  PlanItem,
  formatDateTitle,
  formatPoint,
  formatTime,
  planTodayCount,
  todayDoneCount,
  todayKey,
  todayRequiredCount
} from '../model/DakaModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'HomeView';

/** 取图结果：取消、失败、成功分别处理。 */
class PhotoResult {
  canceled: boolean = false;
  failed: boolean = false;
  uri: string = '';
}

@Component
export struct HomeView {
  @Link plans: PlanItem[];
  @Link records: CheckInRecord[];
  @Prop userName: string = '';
  @Prop score: number = 0;
  @Prop perPoint: number = 0;
  onCheckIn: (planId: string, photoUri: string) => void = () => {
  };
  onUndo: (recordId: string) => void = () => {
  };
  onGoPlan: () => void = () => {
  };

  private todayDone(): number {
    return todayDoneCount(this.records, todayKey());
  }

  private todayRequired(): number {
    return todayRequiredCount(this.plans);
  }

  private greeting(): string {
    return this.userName.length > 0 ? `你好，${this.userName}` : '还没有设置昵称';
  }

  private photosOf(planId: string): CheckInRecord[] {
    const key: string = todayKey();
    const list: CheckInRecord[] = [];
    for (let i = 0; i < this.records.length; i++) {
      const record: CheckInRecord = this.records[i];
      if (record.kind === KIND_ADD && record.planId === planId && record.dayKey === key) {
        list.push(record);
      }
    }
    return list;
  }

  /** 最近 6 次有效打卡，倒序展示。 */
  private recentRecords(): CheckInRecord[] {
    const list: CheckInRecord[] = [];
    for (let i = this.records.length - 1; i >= 0; i--) {
      const record: CheckInRecord = this.records[i];
      if (record.kind === KIND_ADD) {
        list.push(record);
      }
      if (list.length >= 6) {
        break;
      }
    }
    return list;
  }

  private async captureByCamera(): Promise<PhotoResult> {
    const result: PhotoResult = new PhotoResult();
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      result.failed = true;
      return result;
    }
    try {
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };
      const mediaTypes: cameraPicker.PickerMediaType[] = [cameraPicker.PickerMediaType.PHOTO];
      const picked: cameraPicker.PickerResult = await cameraPicker.pick(context, mediaTypes, profile);
      if (picked.resultCode === 0 && picked.resultUri.length > 0) {
        result.uri = picked.resultUri;
      } else {
        result.canceled = true;
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'camera failed: %{public}s', error.message);
      result.failed = true;
    }
    return result;
  }

  private async captureByGallery(): Promise<PhotoResult> {
    const result: PhotoResult = new PhotoResult();
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const selected: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (selected.photoUris.length > 0) {
        result.uri = selected.photoUris[0];
      } else {
        result.canceled = true;
      }
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'gallery failed: %{public}s', error.message);
      result.failed = true;
    }
    return result;
  }

  private async startCheckIn(planId: string, useCamera: boolean): Promise<void> {
    const result: PhotoResult = useCamera ? await this.captureByCamera() : await this.captureByGallery();
    if (result.canceled) {
      return;
    }
    if (result.uri.length > 0) {
      this.onCheckIn(planId, result.uri);
      return;
    }
    this.confirmWithoutPhoto(planId);
  }

  private confirmWithoutPhoto(planId: string): void {
    this.getUIContext().showAlertDialog({
      title: '没有获取到照片',
      message: '当前环境（预览器 / 模拟器）可能无法调用相机。可以继续打卡，这条记录会标记为「无照片」。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '仍然打卡',
        fontColor: AppColor.primary,
        action: () => {
          this.onCheckIn(planId, '');
        }
      }
    });
  }

  private confirmUndo(record: CheckInRecord): void {
    this.getUIContext().showAlertDialog({
      title: '撤销这次打卡？',
      message: `「${record.planName}」的这次打卡会被撤销，同时扣掉 ${this.perPoint} 分。`,
      primaryButton: {
        value: '再想想',
        action: () => {
        }
      },
      secondaryButton: {
        value: '确认撤销',
        fontColor: AppColor.danger,
        action: () => {
          this.onUndo(record.id);
        }
      }
    });
  }

  @Builder
  photoThumb(record: CheckInRecord) {
    Stack() {
      Column()
        .width(54)
        .height(54)
        .borderRadius(AppSize.radiusInner)
        .backgroundColor('#EDF1F4')

      if (record.photoUri.length > 0) {
        Image(record.photoUri)
          .width(54)
          .height(54)
          .borderRadius(AppSize.radiusInner)
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          AppIcon({ commands: IconPath.gallery, iconSize: 20, color: AppColor.textWeak, strokeW: 1.6 })
          Text('无照片')
            .fontSize(9)
            .fontColor(AppColor.textWeak)
            .margin({ top: 2 })
        }
        .justifyContent(FlexAlign.Center)
        .width(54)
        .height(54)
      }
    }
    .width(54)
    .height(54)
    .margin({ right: 8 })
  }

  @Builder
  emptyState() {
    Column() {
      Column() {
        AppIcon({ commands: IconPath.plan, iconSize: 30, color: AppColor.primary, strokeW: 1.6 })
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(AppColor.primarySoft)
      .justifyContent(FlexAlign.Center)

      Text('还没有打卡计划')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textMain)
        .margin({ top: 12 })

      Text('先去「计划」页添加一个目标，再回来拍照打卡')
        .fontSize(12)
        .fontColor(AppColor.textSub)
        .margin({ top: 6 })
        .textAlign(TextAlign.Center)

      Button('去添加计划')
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor(AppColor.primary)
        .height(38)
        .width(140)
        .margin({ top: 16 })
        .onClick(() => {
          this.onGoPlan();
        })
    }
    .width('100%')
    .padding({ top: 28, bottom: 28 })
    .backgroundColor(AppColor.card)
    .borderRadius(AppSize.radiusCard)
  }

  @Builder
  taskCard(plan: PlanItem) {
    Column() {
      Row() {
        Column() {
          Text(plan.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`每天 ${plan.timesPerDay} 次 · 共 ${plan.totalDays} 天`)
            .fontSize(11)
            .fontColor(AppColor.textSub)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(`${planTodayCount(this.records, plan.id, todayKey())}/${plan.timesPerDay}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(planTodayCount(this.records, plan.id, todayKey()) >= plan.timesPerDay
            ? AppColor.primary
            : AppColor.textSub)
      }
      .width('100%')

      if (this.photosOf(plan.id).length > 0) {
        Row() {
          ForEach(this.photosOf(plan.id), (record: CheckInRecord) => {
            this.photoThumb(record)
          }, (record: CheckInRecord) => record.id)
        }
        .width('100%')
        .margin({ top: 12 })
      }

      Row() {
        if (planTodayCount(this.records, plan.id, todayKey()) >= plan.timesPerDay) {
          Row() {
            AppIcon({ commands: IconPath.check, iconSize: 16, color: AppColor.primary, strokeW: 2 })
            Text('今日已完成')
              .fontSize(14)
              .fontColor(AppColor.primary)
              .margin({ left: 6 })
          }
          .layoutWeight(1)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(AppColor.primarySoft)
          .borderRadius(20)
        } else {
          Button({ type: ButtonType.Capsule }) {
            Row() {
              AppIcon({ commands: IconPath.camera, iconSize: 16, color: Color.White, strokeW: 1.9 })
              Text('拍照打卡')
                .fontSize(14)
                .fontColor(Color.White)
                .margin({ left: 6 })
            }
            .justifyContent(FlexAlign.Center)
          }
          .layoutWeight(1)
          .height(40)
          .backgroundColor(AppColor.primary)
          .onClick(() => {
            this.startCheckIn(plan.id, true);
          })

          Button({ type: ButtonType.Capsule }) {
            AppIcon({ commands: IconPath.gallery, iconSize: 18, color: AppColor.primary, strokeW: 1.8 })
          }
          .width(44)
          .height(40)
          .backgroundColor(AppColor.primarySoft)
          .margin({ left: 8 })
          .onClick(() => {
            this.startCheckIn(plan.id, false);
          })
        }
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColor.card)
    .borderRadius(AppSize.radiusCard)
  }

  @Builder
  recentItem(record: CheckInRecord) {
    Row() {
      Column() {
        if (record.photoUri.length > 0) {
          Image(record.photoUri)
            .width(40)
            .height(40)
            .borderRadius(AppSize.radiusInner)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            AppIcon({ commands: IconPath.gallery, iconSize: 16, color: AppColor.textWeak, strokeW: 1.6 })
          }
          .width(40)
          .height(40)
          .borderRadius(AppSize.radiusInner)
          .backgroundColor('#EDF1F4')
          .justifyContent(FlexAlign.Center)
        }
      }

      Column() {
        Text(record.planName)
          .fontSize(14)
          .fontColor(AppColor.textMain)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(formatTime(record.time))
          .fontSize(11)
          .fontColor(AppColor.textSub)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text(formatPoint(record.point))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.amber)

      Button({ type: ButtonType.Circle }) {
        AppIcon({ commands: IconPath.undo, iconSize: 15, color: AppColor.textSub, strokeW: 1.7 })
      }
      .width(30)
      .height(30)
      .backgroundColor(Color.Transparent)
      .margin({ left: 4 })
      .onClick(() => {
        this.confirmUndo(record);
      })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text('今日打卡')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textMain)
            Text(`${this.greeting()} · ${formatDateTitle(Date.now())}`)
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .margin({ top: 5 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column() {
            Text(`${this.score}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.amber)
            Text('积分')
              .fontSize(10)
              .fontColor(AppColor.textSub)
              .margin({ top: 1 })
          }
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .backgroundColor(AppColor.card)
          .borderRadius(AppSize.radiusInner)
        }
        .width('100%')

        Column() {
          Row() {
            Text('今日进度')
              .fontSize(13)
              .fontColor(AppColor.textSub)
              .layoutWeight(1)
            Text(`${this.todayDone()} / ${this.todayRequired()} 次`)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.primary)
          }
          .width('100%')

          Progress({
            value: this.todayDone(),
            total: this.todayRequired() > 0 ? this.todayRequired() : 1,
            type: ProgressType.Linear
          })
            .height(8)
            .width('100%')
            .color(AppColor.primary)
            .backgroundColor(AppColor.primarySoft)
            .margin({ top: 12 })

          Text(`每完成一次打卡 +${this.perPoint} 分，满分 100 分`)
            .fontSize(11)
            .fontColor(AppColor.textWeak)
            .margin({ top: 10 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap })

        Row() {
          Text('今日任务')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
          Text(`${this.plans.length} 个目标`)
            .fontSize(11)
            .fontColor(AppColor.textSub)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 20, bottom: 10 })

        if (this.plans.length === 0) {
          this.emptyState()
        } else {
          ForEach(this.plans, (plan: PlanItem) => {
            Column() {
              this.taskCard(plan)
            }
            .margin({ bottom: AppSize.gap })
          }, (plan: PlanItem) => plan.id)
        }

        if (this.recentRecords().length > 0) {
          Row() {
            Text('最近打卡')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.textMain)
          }
          .width('100%')
          .margin({ top: 8, bottom: 4 })

          Column() {
            ForEach(this.recentRecords(), (record: CheckInRecord) => {
              this.recentItem(record)
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
