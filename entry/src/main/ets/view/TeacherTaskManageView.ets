import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  ClassMember,
  ClassRoom,
  ClassTask,
  KIND_ADD,
  formatDateTime
} from '../model/DakaModel';

@Component
export struct TeacherTaskManageView {
  @Link classRooms: ClassRoom[];
  @Link tasks: ClassTask[];
  @Link members: ClassMember[];
  @Link records: CheckInRecord[];
  onBack: () => void = () => {
  };
  onOpenPublish: () => void = () => {
  };
  onDeleteTask: (taskId: string) => Promise<boolean> = async () => false;
  onOpenTask: (task: ClassTask) => void = () => {
  };

  private tasksOfClass(classId: string): ClassTask[] {
    const list: ClassTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].classId === classId) {
        list.push(this.tasks[i]);
      }
    }
    list.sort((a: ClassTask, b: ClassTask) => b.createdAt - a.createdAt);
    return list;
  }

  private memberCount(classId: string): number {
    let count: number = 0;
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].classId === classId) {
        count++;
      }
    }
    return count;
  }

  private completedCount(task: ClassTask): number {
    const memberIds: string[] = [];
    for (let i = 0; i < this.records.length; i++) {
      const record: CheckInRecord = this.records[i];
      if (record.kind === KIND_ADD && record.taskId === task.id) {
        let exists: boolean = false;
        for (let j = 0; j < memberIds.length; j++) {
          if (memberIds[j] === record.memberId) {
            exists = true;
            break;
          }
        }
        if (!exists) {
          memberIds.push(record.memberId);
        }
      }
    }
    return Math.max(memberIds.length, task.completedCount);
  }

  private totalMemberCount(task: ClassTask): number {
    return Math.max(task.memberCount, this.memberCount(task.classId));
  }

  private confirmDelete(task: ClassTask): void {
    this.getUIContext().showAlertDialog({
      title: '删除任务？',
      message: `「${task.content}」删除后将不再展示给学生。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppColor.danger,
        action: async () => {
          await this.onDeleteTask(task.id);
        }
      }
    });
  }

  @Builder
  taskCard(task: ClassTask) {
    Column() {
      Row() {
        Text(task.content)
          .fontSize(13)
          .fontColor(AppColor.textMain)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Button({ type: ButtonType.Circle }) {
          AppIcon({ commands: IconPath.trash, iconSize: 15, color: AppColor.danger, strokeW: 1.7 })
        }
        .width(30)
        .height(30)
        .backgroundColor(AppColor.dangerSoft)
        .margin({ left: 8 })
        .onClick(() => {
          this.confirmDelete(task);
        })
      }
      .width('100%')

      Row() {
        Text(task.requiresPhoto ? '需要上传照片' : '不需要照片')
          .fontSize(10)
          .fontColor(task.requiresPhoto ? AppColor.primary : AppColor.info)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(task.requiresPhoto ? AppColor.primarySoft : AppColor.infoSoft)
          .borderRadius(4)
        Text(`已完成 ${this.completedCount(task)} / ${this.totalMemberCount(task)} 人`)
          .fontSize(10)
          .fontColor(AppColor.textSub)
          .margin({ left: 8 })
        Blank()
        Text(formatDateTime(task.createdAt))
          .fontSize(10)
          .fontColor(AppColor.textWeak)
      }
      .width('100%')
      .margin({ top: 8 })

      Row() {
        AppIcon({ commands: IconPath.users, iconSize: 14, color: AppColor.primary, strokeW: 1.8 })
        Text('查看完成情况')
          .fontSize(11)
          .fontColor(AppColor.primary)
          .margin({ left: 5 })
        Blank()
        AppIcon({ commands: IconPath.chevronRight, iconSize: 13, color: AppColor.textWeak, strokeW: 1.7 })
      }
      .width('100%')
      .padding({ top: 8 })
      .onClick(() => {
        this.onOpenTask(task);
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
            Text('任务管理')
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
          .margin({ left: 10 })

          Button({ type: ButtonType.Capsule }) {
            Row() {
              AppIcon({ commands: IconPath.plus, iconSize: 14, color: Color.White, strokeW: 2 })
              Text('发布')
                .fontSize(12)
                .fontColor(Color.White)
                .margin({ left: 4 })
            }
          }
          .height(34)
          .padding({ left: 12, right: 12 })
          .backgroundColor(AppColor.primary)
          .onClick(() => {
            this.onOpenPublish();
          })
        }
        .width('100%')

        if (this.classRooms.length === 0) {
          Column() {
            AppIcon({ commands: IconPath.plan, iconSize: 28, color: AppColor.textWeak, strokeW: 1.6 })
            Text('还没有班级')
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .margin({ top: 10 })
          }
          .width('100%')
          .padding({ top: 30, bottom: 30 })
          .backgroundColor(AppColor.card)
          .borderRadius(AppSize.radiusCard)
          .margin({ top: AppSize.gap })
          .justifyContent(FlexAlign.Center)
        } else {
          ForEach(this.classRooms, (room: ClassRoom) => {
            Column() {
              Row() {
                Column() {
                  Text(room.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColor.textMain)
                  Text(`班级号 ${room.code}`)
                    .fontSize(11)
                    .fontColor(AppColor.textSub)
                    .margin({ top: 3 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Text(`${this.tasksOfClass(room.id).length} 个任务`)
                  .fontSize(11)
                  .fontColor(AppColor.textSub)
              }
              .width('100%')

              if (this.tasksOfClass(room.id).length === 0) {
                Text('暂无任务')
                  .fontSize(12)
                  .fontColor(AppColor.textWeak)
                  .width('100%')
                  .padding({ top: 16, bottom: 12 })
              } else {
                ForEach(this.tasksOfClass(room.id), (task: ClassTask) => {
                  this.taskCard(task)
                }, (task: ClassTask) => task.id)
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppColor.card)
            .borderRadius(AppSize.radiusCard)
            .alignItems(HorizontalAlign.Start)
            .margin({ top: AppSize.gap })
          }, (room: ClassRoom) => room.id)
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
