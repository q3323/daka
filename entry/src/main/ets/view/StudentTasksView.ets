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
  ClassRoom,
  ClassTask,
  KIND_ADD,
  formatDateTime
} from '../model/DakaModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'StudentTasksView';

class StudentPhotoResult {
  canceled: boolean = false;
  failed: boolean = false;
  uri: string = '';
}

@Component
export struct StudentTasksView {
  @Link classRooms: ClassRoom[];
  @Link tasks: ClassTask[];
  @Link records: CheckInRecord[];
  onRefresh: () => Promise<void> = async () => {
  };
  onSubmit: (taskId: string, content: string, photoUri: string) => Promise<boolean> =
    async () => false;

  @State selectedTaskId: string = '';
  @State content: string = '';
  @State photoUri: string = '';
  @State submitting: boolean = false;
  @State refreshing: boolean = false;
  private refreshTimer: number = -1;

  aboutToAppear(): void {
    if (this.refreshTimer < 0) {
      this.refreshTimer = setInterval(() => {
        if (!this.refreshing) {
          this.refresh();
        }
      }, 5000);
    }
  }

  aboutToDisappear(): void {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', error.message);
    }
  }

  private sortedTasks(): ClassTask[] {
    const list: ClassTask[] = this.tasks.slice();
    list.sort((a: ClassTask, b: ClassTask) => b.createdAt - a.createdAt);
    return list;
  }

  private selectedTask(): ClassTask | undefined {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === this.selectedTaskId) {
        return this.tasks[i];
      }
    }
    return undefined;
  }

  private classNameOf(task: ClassTask): string {
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].id === task.classId) {
        return this.classRooms[i].name;
      }
    }
    return '班级任务';
  }

  private recordOfTask(taskId: string): CheckInRecord | undefined {
    for (let i = 0; i < this.records.length; i++) {
      const record: CheckInRecord = this.records[i];
      if (record.kind === KIND_ADD && record.taskId === taskId) {
        return record;
      }
    }
    return undefined;
  }

  private openTask(task: ClassTask): void {
    this.selectedTaskId = task.id;
    this.content = '';
    this.photoUri = '';
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

  private async captureByCamera(): Promise<StudentPhotoResult> {
    const result: StudentPhotoResult = new StudentPhotoResult();
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

  private async captureByGallery(): Promise<StudentPhotoResult> {
    const result: StudentPhotoResult = new StudentPhotoResult();
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

  private async pickPhoto(useCamera: boolean): Promise<void> {
    const result: StudentPhotoResult = useCamera
      ? await this.captureByCamera()
      : await this.captureByGallery();
    if (result.canceled) {
      return;
    }
    if (result.failed || result.uri.length === 0) {
      this.toast('没有获取到照片');
      return;
    }
    this.photoUri = result.uri;
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    const task: ClassTask | undefined = this.selectedTask();
    if (task === undefined) {
      return;
    }
    const text: string = this.content.trim();
    if (task.requiresPhoto && this.photoUri.length === 0) {
      this.toast('这个任务需要上传照片');
      return;
    }
    this.submitting = true;
    try {
      if (await this.onSubmit(task.id, text, this.photoUri)) {
        this.selectedTaskId = '';
        this.content = '';
        this.photoUri = '';
      }
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  taskCard(task: ClassTask) {
    Row() {
      Column() {
        AppIcon({
          commands: this.recordOfTask(task.id) !== undefined ? IconPath.check : IconPath.plan,
          iconSize: 19,
          color: this.recordOfTask(task.id) !== undefined ? AppColor.primary : AppColor.info,
          strokeW: 1.9
        })
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(this.recordOfTask(task.id) !== undefined
        ? AppColor.primarySoft
        : AppColor.infoSoft)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(task.content)
          .fontSize(14)
          .fontColor(AppColor.textMain)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row() {
          Text(this.classNameOf(task))
            .fontSize(10)
            .fontColor(AppColor.textSub)
          Text(task.requiresPhoto ? '需照片' : '无需照片')
            .fontSize(9)
            .fontColor(task.requiresPhoto ? AppColor.amber : AppColor.info)
            .padding({ left: 5, right: 5, top: 1, bottom: 1 })
            .backgroundColor(task.requiresPhoto ? AppColor.amberSoft : AppColor.infoSoft)
            .borderRadius(3)
            .margin({ left: 6 })
        }
        .margin({ top: 5 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text(this.recordOfTask(task.id) !== undefined ? '已完成' : '去打卡')
        .fontSize(11)
        .fontColor(this.recordOfTask(task.id) !== undefined ? AppColor.primary : AppColor.primary)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(AppColor.primarySoft)
        .borderRadius(8)
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .border({ width: { bottom: 1 }, color: AppColor.line })
    .onClick(() => {
      this.openTask(task);
    })
  }

  @Builder
  completedPanel(record: CheckInRecord) {
    Column() {
      Text('已提交')
        .fontSize(13)
        .fontColor(AppColor.primary)
      Text(formatDateTime(record.time))
        .fontSize(11)
        .fontColor(AppColor.textSub)
        .margin({ top: 5 })
      Text(record.content.length > 0 ? record.content : '未填写打卡内容')
        .fontSize(13)
        .fontColor(AppColor.textMain)
        .width('100%')
        .margin({ top: 12 })
      if (record.photoUri.length > 0) {
        Image(record.photoUri)
          .width('100%')
          .height(180)
          .borderRadius(AppSize.radiusInner)
          .objectFit(ImageFit.Cover)
          .margin({ top: 12 })
      } else {
        Text('本次提交没有照片')
          .fontSize(11)
          .fontColor(AppColor.textWeak)
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(AppColor.card)
    .borderRadius(AppSize.radiusCard)
    .margin({ top: AppSize.gap })
  }

  @Builder
  submitPanel(task: ClassTask) {
    Column() {
      Text('打卡内容')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textMain)
      TextArea({ placeholder: '写下这次任务的完成情况', text: this.content })
        .width('100%')
        .height(120)
        .fontSize(13)
        .backgroundColor('#F5F7F9')
        .borderRadius(AppSize.radiusInner)
        .placeholderColor(AppColor.textWeak)
        .maxLength(500)
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.content = value;
        })

      Text(task.requiresPhoto ? '任务照片（必传）' : '任务照片（可选）')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textMain)
        .margin({ top: 16 })

      if (this.photoUri.length > 0) {
        Image(this.photoUri)
          .width('100%')
          .height(180)
          .borderRadius(AppSize.radiusInner)
          .objectFit(ImageFit.Cover)
          .margin({ top: 8 })
      }

      Row() {
        Button({ type: ButtonType.Capsule }) {
          Row() {
            AppIcon({ commands: IconPath.camera, iconSize: 16, color: Color.White, strokeW: 1.9 })
            Text('拍照')
              .fontSize(13)
              .fontColor(Color.White)
              .margin({ left: 5 })
          }
        }
        .height(38)
        .layoutWeight(1)
        .backgroundColor(AppColor.primary)
        .onClick(() => {
          this.pickPhoto(true);
        })

        Button({ type: ButtonType.Capsule }) {
          Row() {
            AppIcon({ commands: IconPath.gallery, iconSize: 16, color: AppColor.primary, strokeW: 1.9 })
            Text('相册')
              .fontSize(13)
              .fontColor(AppColor.primary)
              .margin({ left: 5 })
          }
        }
        .height(38)
        .layoutWeight(1)
        .backgroundColor(AppColor.primarySoft)
        .margin({ left: 8 })
        .onClick(() => {
          this.pickPhoto(false);
        })
      }
      .width('100%')
      .margin({ top: 8 })

      Button(this.submitting ? '提交中...' : '提交打卡')
        .fontSize(14)
        .fontColor(Color.White)
        .height(44)
        .width('100%')
        .backgroundColor(AppColor.primary)
        .margin({ top: 18 })
        .enabled(!this.submitting)
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
  }

  @Builder
  detailPage(task: ClassTask) {
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
            this.selectedTaskId = '';
          })
          Column() {
            Text('任务详情')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textMain)
            Text(this.classNameOf(task))
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
          Text(task.content)
            .fontSize(15)
            .fontColor(AppColor.textMain)
            .width('100%')
          Row() {
            Text(task.requiresPhoto ? '需要上传照片' : '不需要照片')
              .fontSize(10)
              .fontColor(task.requiresPhoto ? AppColor.amber : AppColor.info)
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .backgroundColor(task.requiresPhoto ? AppColor.amberSoft : AppColor.infoSoft)
              .borderRadius(4)
            Blank()
            Text(formatDateTime(task.createdAt))
              .fontSize(10)
              .fontColor(AppColor.textWeak)
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap })

        if (this.recordOfTask(task.id) !== undefined) {
          this.completedPanel(this.recordOfTask(task.id) as CheckInRecord)
        } else {
          this.submitPanel(task)
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

  build() {
    if (this.selectedTask() !== undefined) {
      this.detailPage(this.selectedTask() as ClassTask)
    } else {
      Scroll() {
        Column() {
          Row() {
            Column() {
              Text('班级任务')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColor.textMain)
              Text(`共 ${this.tasks.length} 个任务`)
                .fontSize(11)
                .fontColor(AppColor.textSub)
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button({ type: ButtonType.Capsule }) {
              Row() {
                AppIcon({ commands: IconPath.undo, iconSize: 14, color: AppColor.primary, strokeW: 1.8 })
                Text(this.refreshing ? '刷新中' : '刷新')
                  .fontSize(11)
                  .fontColor(AppColor.primary)
                  .margin({ left: 4 })
              }
            }
            .height(34)
            .padding({ left: 12, right: 12 })
            .backgroundColor(AppColor.primarySoft)
            .enabled(!this.refreshing)
            .onClick(() => {
              this.refresh();
            })
          }
          .width('100%')

          Column() {
            if (this.tasks.length === 0) {
              Column() {
                AppIcon({ commands: IconPath.plan, iconSize: 28, color: AppColor.textWeak, strokeW: 1.6 })
                Text('老师还没有发布任务')
                  .fontSize(12)
                  .fontColor(AppColor.textSub)
                  .margin({ top: 10 })
              }
              .width('100%')
              .padding({ top: 32, bottom: 32 })
              .justifyContent(FlexAlign.Center)
            } else {
              ForEach(this.sortedTasks(), (task: ClassTask) => {
                this.taskCard(task)
              }, (task: ClassTask) => task.id)
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
}
