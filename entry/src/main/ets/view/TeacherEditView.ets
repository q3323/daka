import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import { CheckInRecord, ClassMember, ClassRoom, ClassTask } from '../model/DakaModel';
import { TeacherClassDetailView } from './TeacherClassDetailView';
import { TeacherPublishTaskView } from './TeacherPublishTaskView';
import { TeacherStudentDetailView } from './TeacherStudentDetailView';
import { TeacherTaskDetailView } from './TeacherTaskDetailView';
import { TeacherTaskManageView } from './TeacherTaskManageView';

const DOMAIN: number = 0x0000;
const TAG: string = 'TeacherEditView';
const PAGE_CLASSES: number = 0;
const PAGE_CLASS_DETAIL: number = 1;
const PAGE_STUDENT_DETAIL: number = 2;
const PAGE_TASKS: number = 3;
const PAGE_PUBLISH: number = 4;
const PAGE_TASK_DETAIL: number = 5;

@Component
export struct TeacherEditView {
  @Link classRooms: ClassRoom[];
  @Link members: ClassMember[];
  @Link records: CheckInRecord[];
  @Link tasks: ClassTask[];
  onAddClass: (name: string) => Promise<string> = async () => '';
  onRemoveMember: (memberId: string) => Promise<boolean> = async () => false;
  onRemoveClass: (classId: string) => Promise<boolean> = async () => false;
  onAddTask: (classId: string, content: string, requiresPhoto: boolean) => Promise<string> =
    async () => '';
  onRemoveTask: (taskId: string) => Promise<boolean> = async () => false;
  onRefresh: () => Promise<void> = async () => {
  };

  @State draftName: string = '';
  @State pageMode: number = PAGE_CLASSES;
  @State selectedClassId: string = '';
  @State selectedMemberId: string = '';
  @State selectedTaskId: string = '';
  @State publishReturnMode: number = PAGE_CLASSES;
  private refreshTimer: number = -1;
  private refreshInFlight: boolean = false;

  aboutToAppear(): void {
    if (this.refreshTimer < 0) {
      this.refreshTimer = setInterval(() => {
        this.autoRefresh();
      }, 5000);
    }
  }

  aboutToDisappear(): void {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  private async autoRefresh(): Promise<void> {
    if (this.refreshInFlight) {
      return;
    }
    this.refreshInFlight = true;
    try {
      await this.onRefresh();
    } finally {
      this.refreshInFlight = false;
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

  private selectedRoom(): ClassRoom | undefined {
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].id === this.selectedClassId) {
        return this.classRooms[i];
      }
    }
    return undefined;
  }

  private selectedMember(): ClassMember | undefined {
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].id === this.selectedMemberId) {
        return this.members[i];
      }
    }
    return undefined;
  }

  private selectedTask(): ClassTask | undefined {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === this.selectedTaskId) {
        return this.tasks[i];
      }
    }
    return undefined;
  }

  private selectedTaskRoom(): ClassRoom | undefined {
    const task: ClassTask | undefined = this.selectedTask();
    if (task === undefined) {
      return undefined;
    }
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].id === task.classId) {
        return this.classRooms[i];
      }
    }
    return undefined;
  }

  private memberCount(classId: string): number {
    let count: number = 0;
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].classId === classId) {
        count++;
      }
    }
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].id === classId && this.classRooms[i].memberCount > count) {
        count = this.classRooms[i].memberCount;
      }
    }
    return count;
  }

  private async createClass(): Promise<void> {
    const name: string = this.draftName.trim();
    if (name.length === 0) {
      this.toast('请输入班级名称');
      return;
    }
    const id: string = await this.onAddClass(name);
    if (id.length > 0) {
      this.draftName = '';
      this.selectedClassId = id;
      this.pageMode = PAGE_CLASSES;
    }
  }

  private openClass(room: ClassRoom): void {
    this.selectedClassId = room.id;
    this.selectedMemberId = '';
    this.pageMode = PAGE_CLASS_DETAIL;
    this.onRefresh();
  }

  private openStudent(member: ClassMember): void {
    this.selectedMemberId = member.id;
    this.pageMode = PAGE_STUDENT_DETAIL;
  }

  private openPublish(returnMode: number): void {
    this.publishReturnMode = returnMode;
    this.pageMode = PAGE_PUBLISH;
  }

  private openTaskDetail(task: ClassTask): void {
    this.selectedTaskId = task.id;
    this.pageMode = PAGE_TASK_DETAIL;
  }

  private confirmRemoveClass(room: ClassRoom): void {
    this.getUIContext().showAlertDialog({
      title: '删除班级？',
      message: `「${room.name}」及其成员关系会被删除，学生之后的签到记录不会出现在这个班级中。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppColor.danger,
        action: async () => {
          if (await this.onRemoveClass(room.id)) {
            this.toast('班级已删除');
          }
        }
      }
    });
  }

  @Builder
  classCard(room: ClassRoom) {
    Column() {
      Row() {
        Column() {
          Text(room.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            Text('班级号')
              .fontSize(11)
              .fontColor(AppColor.textSub)
            Text(room.code)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColor.primary)
              .margin({ left: 6 })
          }
          .margin({ top: 5 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          Text(`${this.memberCount(room.id)} 人`)
            .fontSize(12)
            .fontColor(AppColor.textSub)

          Button({ type: ButtonType.Circle }) {
            AppIcon({ commands: IconPath.trash, iconSize: 15, color: AppColor.danger, strokeW: 1.7 })
          }
          .width(30)
          .height(30)
          .backgroundColor(AppColor.dangerSoft)
          .margin({ left: 8 })
          .onClick(() => {
            this.confirmRemoveClass(room);
          })
        }
      }
      .width('100%')

      Divider()
        .color(AppColor.line)
        .margin({ top: 12, bottom: 8 })

      Row() {
        AppIcon({ commands: IconPath.users, iconSize: 16, color: AppColor.primary, strokeW: 1.8 })
        Text('查看学生状态')
          .fontSize(13)
          .fontColor(AppColor.primary)
          .margin({ left: 7 })
        Blank()
        AppIcon({ commands: IconPath.chevronRight, iconSize: 15, color: AppColor.textWeak, strokeW: 1.7 })
      }
      .width('100%')
      .onClick(() => {
        this.openClass(room);
      })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.selectedClassId === room.id ? AppColor.primarySoft : AppColor.card)
    .borderRadius(AppSize.radiusCard)
  }

  @Builder
  classListPage() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Scroll() {
        Column() {
        Column() {
          Text('新建班级群')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)

          Text('班级名称')
            .fontSize(12)
            .fontColor(AppColor.textSub)
            .margin({ top: 14, bottom: 6 })

          Row() {
            TextInput({ placeholder: '例如：高一（3）班', text: this.draftName })
              .height(42)
              .fontSize(14)
              .layoutWeight(1)
              .backgroundColor('#F5F7F9')
              .borderRadius(AppSize.radiusInner)
              .placeholderColor(AppColor.textWeak)
              .maxLength(30)
              .onChange((value: string) => {
                this.draftName = value;
              })

            Button('创建')
              .fontSize(14)
              .fontColor(Color.White)
              .height(42)
              .width(78)
              .backgroundColor(AppColor.primary)
              .margin({ left: 8 })
              .onClick(() => {
                this.createClass();
              })
          }
          .width('100%')

          Text('创建后会生成一个唯一班级号，学生填写班级号即可加入。')
            .fontSize(11)
            .fontColor(AppColor.textWeak)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .alignItems(HorizontalAlign.Start)
        .margin({ top: AppSize.gap })

        Row() {
          Text('我的班级')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
          Text(`共 ${this.classRooms.length} 个`)
            .fontSize(11)
            .fontColor(AppColor.textSub)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 20, bottom: 10 })

        if (this.classRooms.length === 0) {
          Column() {
            AppIcon({ commands: IconPath.users, iconSize: 28, color: AppColor.textWeak, strokeW: 1.6 })
            Text('还没有创建班级群')
              .fontSize(12)
              .fontColor(AppColor.textSub)
              .margin({ top: 10 })
          }
          .width('100%')
          .padding({ top: 28, bottom: 28 })
          .backgroundColor(AppColor.card)
          .borderRadius(AppSize.radiusCard)
          .justifyContent(FlexAlign.Center)
        } else {
          ForEach(this.classRooms, (room: ClassRoom) => {
            Column() {
              this.classCard(room)
            }
            .margin({ bottom: AppSize.gap })
          }, (room: ClassRoom) => room.id)
        }
        }
        .width('100%')
        .padding({ left: AppSize.pagePadding, right: AppSize.pagePadding, top: AppSize.pagePadding, bottom: 104 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      Column() {
        Button({ type: ButtonType.Capsule }) {
          Row() {
            AppIcon({ commands: IconPath.plan, iconSize: 15, color: AppColor.textMain, strokeW: 1.8 })
            Text('任务管理')
              .fontSize(12)
              .fontColor(AppColor.textMain)
              .margin({ left: 5 })
          }
        }
        .height(40)
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppColor.card)
        .border({ width: 1, color: AppColor.line })
        .onClick(() => {
          this.pageMode = PAGE_TASKS;
        })

        Button({ type: ButtonType.Capsule }) {
          Row() {
            AppIcon({ commands: IconPath.plus, iconSize: 15, color: Color.White, strokeW: 2 })
            Text('发布任务')
              .fontSize(12)
              .fontColor(Color.White)
              .margin({ left: 5 })
          }
        }
        .height(40)
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppColor.primary)
        .margin({ top: 8 })
        .onClick(() => {
          this.openPublish(PAGE_CLASSES);
        })
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 16, bottom: 18 })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    if (this.pageMode === PAGE_CLASS_DETAIL && this.selectedRoom() !== undefined) {
      TeacherClassDetailView({
        members: $members,
        records: $records,
        classId: (this.selectedRoom() as ClassRoom).id,
        className: (this.selectedRoom() as ClassRoom).name,
        classCode: (this.selectedRoom() as ClassRoom).code,
        onBack: () => {
          this.pageMode = PAGE_CLASSES;
        },
        onOpenStudent: (member: ClassMember) => {
          this.openStudent(member);
        },
        onRemoveMember: (memberId: string) => {
          return this.onRemoveMember(memberId);
        },
        onRefresh: () => {
          return this.onRefresh();
        }
      })
    } else if (this.pageMode === PAGE_STUDENT_DETAIL
      && this.selectedRoom() !== undefined
      && this.selectedMember() !== undefined) {
      TeacherStudentDetailView({
        records: $records,
        memberId: (this.selectedMember() as ClassMember).id,
        memberName: (this.selectedMember() as ClassMember).name,
        className: (this.selectedRoom() as ClassRoom).name,
        onBack: () => {
          this.pageMode = PAGE_CLASS_DETAIL;
        }
      })
    } else if (this.pageMode === PAGE_TASKS) {
      TeacherTaskManageView({
        classRooms: $classRooms,
        tasks: $tasks,
        members: $members,
        records: $records,
        onBack: () => {
          this.pageMode = PAGE_CLASSES;
        },
        onOpenPublish: () => {
          this.openPublish(PAGE_TASKS);
        },
        onDeleteTask: (taskId: string) => {
          return this.onRemoveTask(taskId);
        },
        onOpenTask: (task: ClassTask) => {
          this.openTaskDetail(task);
        }
      })
    } else if (this.pageMode === PAGE_PUBLISH) {
      TeacherPublishTaskView({
        classRooms: $classRooms,
        onBack: () => {
          this.pageMode = this.publishReturnMode;
        },
        onPublish: async (classId: string, content: string, requiresPhoto: boolean) => {
          const taskId: string = await this.onAddTask(classId, content, requiresPhoto);
          if (taskId.length > 0) {
            this.pageMode = PAGE_TASKS;
          }
        }
      })
    } else if (this.pageMode === PAGE_TASK_DETAIL
      && this.selectedTask() !== undefined
      && this.selectedTaskRoom() !== undefined) {
      TeacherTaskDetailView({
        members: $members,
        records: $records,
        classId: (this.selectedTaskRoom() as ClassRoom).id,
        className: (this.selectedTaskRoom() as ClassRoom).name,
        classCode: (this.selectedTaskRoom() as ClassRoom).code,
        taskId: (this.selectedTask() as ClassTask).id,
        taskContent: (this.selectedTask() as ClassTask).content,
        requiresPhoto: (this.selectedTask() as ClassTask).requiresPhoto,
        memberCount: (this.selectedTask() as ClassTask).memberCount,
        onBack: () => {
          this.pageMode = PAGE_TASKS;
        }
      })
    } else {
      this.classListPage()
    }
  }
}
