import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import {
  CheckInRecord,
  ClassMember,
  ClassRoom,
  PlanItem,
  ROLE_STUDENT,
  ROLE_TEACHER,
  finishRate,
  scoreLevel,
  totalDoneCount,
  totalRequiredCount
} from '../model/DakaModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'MineView';

@Component
export struct MineView {
  @Link plans: PlanItem[];
  @Link records: CheckInRecord[];
  @Link classRooms: ClassRoom[];
  @Link members: ClassMember[];
  @Prop userName: string = '';
  @Prop score: number = 0;
  @Prop role: string = ROLE_TEACHER;
  @Prop loginId: string = '';
  @Prop serverMode: boolean = false;
  @Prop roleEditable: boolean = true;
  onSaveName: (name: string) => void = () => {
  };
  onClearRecords: () => void = () => {
  };
  onClearAll: () => void = () => {
  };
  onChangeRole: (role: string) => void = () => {
  };
  onJoinClass: (code: string) => Promise<boolean> = async () => false;
  onLogout: () => void = () => {
  };

  @State draftName: string = '';
  @State draftClassCode: string = '';
  @State joining: boolean = false;

  aboutToAppear(): void {
    this.draftName = this.userName;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', error.message);
    }
  }

  private avatarText(): string {
    if (this.userName.length === 0) {
      return '喵';
    }
    return this.userName.substring(0, 1);
  }

  private rateText(): string {
    return `${Math.round(finishRate(this.plans, this.records) * 100)}%`;
  }

  private saveName(): void {
    const name: string = this.draftName.trim();
    if (name.length === 0) {
      this.toast('请输入姓名');
      return;
    }
    this.onSaveName(name);
    this.toast(`已保存：${name}`);
  }

  private joinedClasses(): ClassRoom[] {
    const list: ClassRoom[] = [];
    if (this.serverMode) {
      return this.classRooms.slice();
    }
    if (this.userName.length === 0) {
      return list;
    }
    for (let i = 0; i < this.classRooms.length; i++) {
      const room: ClassRoom = this.classRooms[i];
      let joined: boolean = false;
      for (let j = 0; j < this.members.length; j++) {
        const member: ClassMember = this.members[j];
        if (member.classId === room.id && member.name === this.userName) {
          joined = true;
          break;
        }
      }
      if (joined) {
        list.push(room);
      }
    }
    return list;
  }

  private async joinClass(): Promise<void> {
    if (this.joining) {
      return;
    }
    const code: string = this.draftClassCode.trim();
    if (code.length === 0) {
      this.toast('请输入班级号');
      return;
    }
    this.joining = true;
    try {
      if (await this.onJoinClass(code)) {
        this.draftClassCode = '';
      }
    } finally {
      this.joining = false;
    }
  }

  private handleAction(kind: string): void {
    if (kind === 'logout') {
      this.onLogout();
      return;
    }
    if (kind === 'records') {
      this.confirmClearRecords();
      return;
    }
    this.confirmClearAll();
  }

  private confirmClearRecords(): void {
    this.getUIContext().showAlertDialog({
      title: '清空打卡记录？',
      message: '积分会回到 0 分，计划会保留。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清空',
        fontColor: AppColor.danger,
        action: () => {
          this.onClearRecords();
          this.toast('打卡记录已清空');
        }
      }
    });
  }

  private confirmClearAll(): void {
    this.getUIContext().showAlertDialog({
      title: '清空全部数据？',
      message: '本地账号、Token、姓名、计划、班级和打卡记录都会删除，并返回登录页。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '全部清空',
        fontColor: AppColor.danger,
        action: () => {
          this.onClearAll();
          this.draftName = '';
          this.toast('全部数据已清空');
        }
      }
    });
  }

  @Builder
  statCell(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.textMain)
      Text(label)
        .fontSize(11)
        .fontColor(AppColor.textSub)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  roleButton(label: string, value: string) {
    Button(label)
      .fontSize(13)
      .fontColor(this.role === value ? Color.White : AppColor.textSub)
      .height(36)
      .layoutWeight(1)
      .backgroundColor(this.role === value ? AppColor.primary : '#F1F3F6')
      .enabled(this.roleEditable)
      .opacity(this.roleEditable ? 1 : 0.55)
      .onClick(() => {
        this.onChangeRole(value);
      })
  }

  @Builder
  joinedClassRow(room: ClassRoom) {
    Row() {
      Column() {
        AppIcon({ commands: IconPath.users, iconSize: 17, color: AppColor.primary, strokeW: 1.8 })
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor(AppColor.primarySoft)
      .justifyContent(FlexAlign.Center)

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
      .margin({ left: 10 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  @Builder
  actionRow(commands: string, title: string, desc: string, color: ResourceColor, kind: string) {
    Row() {
      Column() {
        AppIcon({ commands: commands, iconSize: 17, color: color, strokeW: 1.8 })
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor('#F4F6F8')
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(title)
          .fontSize(14)
          .fontColor(AppColor.textMain)
        Text(desc)
          .fontSize(11)
          .fontColor(AppColor.textSub)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })

      Text('>')
        .fontSize(15)
        .fontColor(color)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(() => {
      this.handleAction(kind);
    })
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Row() {
            Column() {
              Text(this.avatarText())
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor(AppColor.primary)
            .justifyContent(FlexAlign.Center)

            Column() {
              Text(this.userName.length > 0 ? this.userName : '请登录喵')
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.textMain)
              Row() {
                Text(scoreLevel(this.score))
                  .fontSize(11)
                  .fontColor(AppColor.amber)
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .backgroundColor(AppColor.amberSoft)
                  .borderRadius(4)
                Text(`当前积分 ${this.score}`)
                  .fontSize(11)
                  .fontColor(AppColor.textSub)
                  .margin({ left: 8 })
              }
              .margin({ top: 6 })
              Text(`登录 ID ${this.loginId} · ${this.serverMode ? '服务器模式' : '本地模式'}`)
                .fontSize(10)
                .fontColor(AppColor.textWeak)
                .margin({ top: 5 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ left: 14 })
          }
          .width('100%')

          Text('姓名')
            .fontSize(12)
            .fontColor(AppColor.textSub)
            .margin({ top: 16, bottom: 6 })

          Row() {
            TextInput({ placeholder: '请输入姓名喵', text: this.draftName })
              .height(42)
              .fontSize(14)
              .layoutWeight(1)
              .backgroundColor('#F5F7F9')
              .borderRadius(AppSize.radiusInner)
              .placeholderColor(AppColor.textWeak)
              .onChange((value: string) => {
                this.draftName = value;
              })

            Button('保存')
              .fontSize(14)
              .fontColor(Color.White)
              .height(42)
              .width(78)
              .backgroundColor(AppColor.primary)
              .margin({ left: 8 })
              .onClick(() => {
                this.saveName();
              })
          }
          .width('100%')

          Text('身份')
            .fontSize(12)
            .fontColor(AppColor.textSub)
            .margin({ top: 16, bottom: 6 })

          Row() {
            this.roleButton('学生', ROLE_STUDENT)
            this.roleButton('老师', ROLE_TEACHER)
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .alignItems(HorizontalAlign.Start)
        .margin({ top: AppSize.gap })

        if (this.role === ROLE_STUDENT) {
          Column() {
            Row() {
              Text('我的班级')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColor.textMain)
              Text(`${this.joinedClasses().length} 个`)
                .fontSize(11)
                .fontColor(AppColor.textSub)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            if (this.joinedClasses().length === 0) {
              Text('还没有加入班级')
                .fontSize(12)
                .fontColor(AppColor.textSub)
                .width('100%')
                .margin({ top: 14, bottom: 8 })
            } else {
              Column() {
                ForEach(this.joinedClasses(), (room: ClassRoom) => {
                  this.joinedClassRow(room)
                }, (room: ClassRoom) => room.id)
              }
              .width('100%')
              .margin({ top: 4 })
            }

            Row() {
              TextInput({ placeholder: '输入班级号', text: this.draftClassCode })
                .height(42)
                .fontSize(14)
                .layoutWeight(1)
                .backgroundColor('#F5F7F9')
                .borderRadius(AppSize.radiusInner)
                .placeholderColor(AppColor.textWeak)
                .maxLength(6)
                .type(InputType.Number)
                .onChange((value: string) => {
                  this.draftClassCode = value;
                })

              Button(this.joining ? '加入中...' : '加入')
                .fontSize(14)
                .fontColor(Color.White)
                .height(42)
                .width(70)
                .backgroundColor(AppColor.primary)
                .margin({ left: 8 })
                .enabled(!this.joining)
                .onClick(() => {
                  this.joinClass();
                })
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(AppColor.card)
          .borderRadius(AppSize.radiusCard)
          .alignItems(HorizontalAlign.Start)
          .margin({ top: AppSize.gap })
        }

        Row() {
          this.statCell('打卡计划', `${this.plans.length}`)
          Divider().vertical(true).height(28).color(AppColor.line)
          this.statCell('打卡次数', `${totalDoneCount(this.records)}`)
          Divider().vertical(true).height(28).color(AppColor.line)
          this.statCell('总需打卡', `${totalRequiredCount(this.plans)}`)
          Divider().vertical(true).height(28).color(AppColor.line)
          this.statCell('完成率', this.rateText())
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: AppSize.gap })

        Text('数据管理')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textMain)
          .margin({ top: 20, bottom: 10 })

        Column() {
          this.actionRow(IconPath.undo, '清空打卡记录', '保留计划与姓名，积分归零', AppColor.info, 'records')
          Divider().color(AppColor.line)
          this.actionRow(IconPath.user, '退出登录', '返回 ID 登录页，本机数据保留', AppColor.info, 'logout')
          Divider().color(AppColor.line)
          this.actionRow(IconPath.trash, '清空全部数据', '账号、Token、计划、班级和记录全部删除',
            AppColor.danger, 'all')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 2, bottom: 2 })
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)

        Column() {
          Row() {
            AppIcon({ commands: IconPath.check, iconSize: 15, color: AppColor.primary, strokeW: 2 })
            Text('打卡小助手')
              .fontSize(13)
              .fontColor(AppColor.textMain)
              .margin({ left: 6 })
            Text('v1.0.0')
              .fontSize(11)
              .fontColor(AppColor.textSub)
              .margin({ left: 6 })
          }
          .width('100%')

          Text('首页拍照打卡 · 计划与班级管理 · 学生状态查看 · 奖惩自动加减分')
            .fontSize(11)
            .fontColor(AppColor.textSub)
            .width('100%')
            .margin({ top: 8 })
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
