import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import { LocalAccount, ROLE_STUDENT, ROLE_TEACHER } from '../model/DakaModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'LoginView';
const MODE_LOGIN: string = 'login';
const MODE_REGISTER: string = 'register';

@Component
export struct LoginView {
  @Prop serverMode: boolean = false;
  onLogin: (id: string) => Promise<boolean> = async () => false;
  onRegister: (nickname: string, role: string) => Promise<LocalAccount> = async () => new LocalAccount();
  onEnter: (id: string) => Promise<boolean> = async () => false;
  onMessage: (message: string) => void = () => {
  };
  onClearLocalData: () => void = () => {
  };

  @State mode: string = MODE_LOGIN;
  @State loginId: string = '';
  @State nickname: string = '';
  @State role: string = ROLE_STUDENT;
  @State registered: boolean = false;
  @State pendingAccount: LocalAccount = new LocalAccount();
  @State busy: boolean = false;

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', error.message);
    }
  }

  private async login(): Promise<void> {
    if (this.busy) {
      return;
    }
    const id: string = this.loginId.trim().toUpperCase();
    if (id.length === 0) {
      this.toast('请输入登录 ID');
      return;
    }
    this.busy = true;
    try {
      if (!await this.onLogin(id)) {
        this.onMessage('登录失败，请检查 ID 或网络连接');
      }
    } finally {
      this.busy = false;
    }
  }

  private async register(): Promise<void> {
    if (this.busy) {
      return;
    }
    const name: string = this.nickname.trim();
    if (name.length === 0) {
      this.toast('请输入昵称');
      return;
    }
    this.busy = true;
    try {
      const account: LocalAccount = await this.onRegister(name, this.role);
      if (account.id.length === 0) {
        this.onMessage('注册失败，请稍后重试');
        return;
      }
      this.pendingAccount = account;
      this.registered = true;
    } finally {
      this.busy = false;
    }
  }

  private async enter(): Promise<void> {
    if (this.busy) {
      return;
    }
    if (this.pendingAccount.id.length > 0) {
      this.busy = true;
      try {
        if (!await this.onEnter(this.pendingAccount.id)) {
          this.onMessage('进入应用失败，请稍后重试');
        }
      } finally {
        this.busy = false;
      }
    }
  }

  private confirmClearLocalData(): void {
    this.getUIContext().showAlertDialog({
      title: '清除本地数据？',
      message: '本地账号、登录 Token、计划、班级和演示数据都会删除，服务器数据不受影响。',
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清除',
        fontColor: AppColor.danger,
        action: () => {
          this.onClearLocalData();
        }
      }
    });
  }

  @Builder
  modeTab(label: string, value: string) {
    Button(label)
      .fontSize(14)
      .fontColor(this.mode === value ? Color.White : AppColor.textSub)
      .height(38)
      .layoutWeight(1)
      .backgroundColor(this.mode === value ? AppColor.primary : Color.Transparent)
      .onClick(() => {
        this.mode = value;
        this.registered = false;
      })
  }

  @Builder
  roleButton(label: string, value: string) {
    Button(label)
      .fontSize(13)
      .fontColor(this.role === value ? AppColor.primary : AppColor.textSub)
      .height(36)
      .layoutWeight(1)
      .backgroundColor(this.role === value ? AppColor.primarySoft : '#F1F3F6')
      .onClick(() => {
        this.role = value;
      })
  }

  @Builder
  loginForm() {
    Column() {
      Text('登录 ID')
        .fontSize(12)
        .fontColor(AppColor.textSub)
        .margin({ bottom: 7 })

      TextInput({ placeholder: '例如：DK-8F3K2Q', text: this.loginId })
        .height(44)
        .fontSize(15)
        .backgroundColor('#F5F7F9')
        .borderRadius(AppSize.radiusInner)
        .placeholderColor(AppColor.textWeak)
        .maxLength(12)
        .onChange((value: string) => {
          this.loginId = value.toUpperCase();
        })

      Button(this.busy ? '登录中...' : '登录')
        .fontSize(14)
        .fontColor(Color.White)
        .height(44)
        .width('100%')
        .backgroundColor(AppColor.primary)
        .margin({ top: 16 })
        .enabled(!this.busy)
        .onClick(() => {
          this.login();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  registerForm() {
    Column() {
      Text('昵称')
        .fontSize(12)
        .fontColor(AppColor.textSub)
        .margin({ bottom: 7 })

      TextInput({ placeholder: '请输入你的昵称', text: this.nickname })
        .height(44)
        .fontSize(15)
        .backgroundColor('#F5F7F9')
        .borderRadius(AppSize.radiusInner)
        .placeholderColor(AppColor.textWeak)
        .maxLength(30)
        .onChange((value: string) => {
          this.nickname = value;
        })

      Text('身份')
        .fontSize(12)
        .fontColor(AppColor.textSub)
        .margin({ top: 14, bottom: 7 })

      Row() {
        this.roleButton('学生', ROLE_STUDENT)
        this.roleButton('老师', ROLE_TEACHER)
      }
      .width('100%')

      Button({ type: ButtonType.Capsule }) {
        Row() {
          AppIcon({ commands: IconPath.plus, iconSize: 16, color: Color.White, strokeW: 2 })
          Text(this.busy ? '注册中...' : '注册并生成 ID')
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
      .enabled(!this.busy)
      .onClick(() => {
        this.register();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  registerSuccess() {
    Column() {
      Column() {
        AppIcon({ commands: IconPath.check, iconSize: 24, color: AppColor.primary, strokeW: 2.2 })
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor(AppColor.primarySoft)
      .justifyContent(FlexAlign.Center)

      Text('注册成功')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.textMain)
        .margin({ top: 12 })

      Text('请记住你的登录 ID')
        .fontSize(12)
        .fontColor(AppColor.textSub)
        .margin({ top: 6 })

      Text(this.pendingAccount.id)
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColor.primary)
        .margin({ top: 18 })

      Text('以后需要用这个 ID 登录，丢失后暂时无法找回。')
        .fontSize(11)
        .fontColor(AppColor.textWeak)
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })

      Button(this.busy ? '正在进入...' : '进入应用')
        .fontSize(14)
        .fontColor(Color.White)
        .height(44)
        .width('100%')
        .backgroundColor(AppColor.primary)
        .margin({ top: 20 })
        .enabled(!this.busy)
        .onClick(() => {
          this.enter();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Scroll() {
      Column() {
        Blank()

        Column() {
          Column() {
            AppIcon({ commands: IconPath.check, iconSize: 28, color: AppColor.primary, strokeW: 2.2 })
          }
          .width(64)
          .height(64)
          .borderRadius(32)
          .backgroundColor(AppColor.primarySoft)
          .justifyContent(FlexAlign.Center)

          Text('打卡小助手')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textMain)
            .margin({ top: 16 })

          Text('用 ID 登录，开始打卡')
            .fontSize(12)
            .fontColor(AppColor.textSub)
            .margin({ top: 6 })

          Text(this.serverMode ? '服务器模式' : '本地模式')
            .fontSize(10)
            .fontColor(this.serverMode ? AppColor.primary : AppColor.textWeak)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.serverMode ? AppColor.primarySoft : '#F1F3F6')
            .borderRadius(4)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Column() {
          Row() {
            this.modeTab('登录', MODE_LOGIN)
            this.modeTab('注册', MODE_REGISTER)
          }
          .width('100%')
          .padding(4)
          .backgroundColor('#F1F3F6')
          .borderRadius(10)

          if (this.mode === MODE_LOGIN) {
            Column() {
              this.loginForm()
            }
            .width('100%')
            .margin({ top: 20 })
          } else if (!this.registered) {
            Column() {
              this.registerForm()
            }
            .width('100%')
            .margin({ top: 20 })
          } else {
            Column() {
              this.registerSuccess()
            }
            .width('100%')
            .margin({ top: 20 })
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor(AppColor.card)
        .borderRadius(AppSize.radiusCard)
        .margin({ top: 28 })

        Button('清除本地数据')
          .fontSize(11)
          .fontColor(AppColor.textWeak)
          .height(38)
          .width('100%')
          .backgroundColor(Color.Transparent)
          .margin({ top: 10 })
          .onClick(() => {
            this.confirmClearLocalData();
          })

        Blank()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24, top: 28, bottom: 28 })
      .backgroundColor(AppColor.pageBg)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
