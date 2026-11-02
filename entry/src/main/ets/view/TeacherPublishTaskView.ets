import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import { ClassRoom } from '../model/DakaModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'TeacherPublishTaskView';

@Component
export struct TeacherPublishTaskView {
  @Link classRooms: ClassRoom[];
  onBack: () => void = () => {
  };
  onPublish: (classId: string, content: string, requiresPhoto: boolean) => Promise<void> =
    async () => {
  };

  @State selectedClassId: string = '';
  @State content: string = '';
  @State requiresPhoto: boolean = true;
  @State publishing: boolean = false;

  aboutToAppear(): void {
    if (this.classRooms.length > 0 && this.selectedClassId.length === 0) {
      this.selectedClassId = this.classRooms[0].id;
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

  private async publish(): Promise<void> {
    if (this.publishing) {
      return;
    }
    if (this.selectedClassId.length === 0) {
      this.toast('请选择班级');
      return;
    }
    const text: string = this.content.trim();
    if (text.length === 0) {
      this.toast('请输入任务内容');
      return;
    }
    this.publishing = true;
    try {
      await this.onPublish(this.selectedClassId, text, this.requiresPhoto);
    } finally {
      this.publishing = false;
    }
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
            Text('发布任务')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColor.textMain)
            Text('选择班级并填写任务要求')
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
          Text('选择班级')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)

          if (this.classRooms.length === 0) {
            Text('还没有班级，请先在编辑页创建班级')
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .width('100%')
              .padding({ top: 16, bottom: 16 })
          } else {
            Column() {
              ForEach(this.classRooms, (room: ClassRoom) => {
                Row() {
                  Column() {
                    Text(room.name)
                      .fontSize(14)
                      .fontColor(AppColor.textMain)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(`班级号 ${room.code}`)
                      .fontSize(11)
                      .fontColor(AppColor.textSub)
                      .margin({ top: 3 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  if (this.selectedClassId === room.id) {
                    AppIcon({ commands: IconPath.check, iconSize: 18, color: AppColor.primary, strokeW: 2 })
                  }
                }
                .width('100%')
                .padding(12)
                .backgroundColor(this.selectedClassId === room.id ? AppColor.primarySoft : '#F5F7F9')
                .borderRadius(AppSize.radiusInner)
                .margin({ top: 8 })
                .onClick(() => {
                  this.selectedClassId = room.id;
                })
              }, (room: ClassRoom) => room.id)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .alignItems(HorizontalAlign.Start)
        .margin({ top: AppSize.gap })

        Column() {
          Text('任务内容')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)

          TextArea({ placeholder: '例如：完成晨读并上传一张晨读照片', text: this.content })
            .width('100%')
            .height(150)
            .fontSize(14)
            .backgroundColor('#F5F7F9')
            .borderRadius(AppSize.radiusInner)
            .placeholderColor(AppColor.textWeak)
            .maxLength(1000)
            .margin({ top: 10 })
            .onChange((value: string) => {
              this.content = value;
            })

          Row() {
            Column() {
              Text('需要上传照片')
                .fontSize(14)
                .fontColor(AppColor.textMain)
              Text('学生提交任务时必须附上照片')
                .fontSize(11)
                .fontColor(AppColor.textSub)
                .margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Toggle({ type: ToggleType.Switch, isOn: this.requiresPhoto })
              .selectedColor(AppColor.primary)
              .onChange((isOn: boolean) => {
                this.requiresPhoto = isOn;
              })
          }
          .width('100%')
          .margin({ top: 16 })

          Button({ type: ButtonType.Capsule }) {
            Row() {
              AppIcon({ commands: IconPath.plus, iconSize: 16, color: Color.White, strokeW: 2 })
              Text(this.publishing ? '发布中...' : '发布任务')
                .fontSize(14)
                .fontColor(Color.White)
                .margin({ left: 6 })
            }
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(44)
          .backgroundColor(AppColor.primary)
          .margin({ top: 18 })
          .enabled(this.classRooms.length > 0 && !this.publishing)
          .onClick(() => {
            this.publish();
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .alignItems(HorizontalAlign.Start)
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
