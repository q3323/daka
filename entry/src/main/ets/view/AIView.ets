import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppIcon } from '../common/AppIcon';
import { IconPath } from '../common/IconPath';
import { AppColor, AppSize } from '../common/Theme';
import { AiChatMessage, AiChatResult, AiClient } from '../model/AiClient';

const DOMAIN: number = 0x0000;
const TAG: string = 'AIView';

@Component
export struct AIView {
  @Link baseUrl: string;
  @Link apiKey: string;
  @Link model: string;

  @State messages: AiChatMessage[] = [];
  @State draft: string = '';
  @State sending: boolean = false;
  @State showSettings: boolean = true;

  aboutToAppear(): void {
    this.showSettings = this.baseUrl.length === 0
      || this.apiKey.length === 0
      || this.model.length === 0;
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', error.message);
    }
  }

  private saveSettings(): void {
    if (this.baseUrl.trim().length === 0
      || this.apiKey.trim().length === 0
      || this.model.trim().length === 0) {
      this.toast('请填写 Base URL、API Key 和模型名称');
      return;
    }
    this.showSettings = false;
    this.toast('接口配置已保存，仅当前 App 会话有效');
  }

  private async send(): Promise<void> {
    if (this.sending) {
      return;
    }
    const text: string = this.draft.trim();
    if (text.length === 0) {
      return;
    }
    if (this.baseUrl.trim().length === 0
      || this.apiKey.trim().length === 0
      || this.model.trim().length === 0) {
      this.showSettings = true;
      this.toast('请先配置 AI 接口');
      return;
    }

    const userMessage: AiChatMessage = new AiChatMessage('user', text);
    const withUser: AiChatMessage[] = this.messages.slice();
    withUser.push(userMessage);
    this.messages = withUser;
    this.draft = '';
    this.sending = true;

    const history: AiChatMessage[] = withUser.slice();
    if (history.length > 12) {
      history.splice(0, history.length - 12);
    }
    const result: AiChatResult = await AiClient.chat(
      this.baseUrl.trim(),
      this.apiKey.trim(),
      this.model.trim(),
      history
    );
    const reply: string = result.ok
      ? result.content
      : `请求失败：${result.message}`;
    const next: AiChatMessage[] = this.messages.slice();
    next.push(new AiChatMessage('assistant', reply));
    this.messages = next;
    this.sending = false;
  }

  @Builder
  messageBubble(message: AiChatMessage) {
    Row() {
      if (message.role === 'user') {
        Blank()
      }
      Column() {
        Text(message.content)
          .fontSize(13)
          .fontColor(message.role === 'user' ? Color.White : AppColor.textMain)
          .lineHeight(20)
      }
      .padding(12)
      .backgroundColor(message.role === 'user' ? AppColor.primary : AppColor.card)
      .borderRadius(12)
      .constraintSize({ maxWidth: '84%' })
      if (message.role !== 'user') {
        Blank()
      }
    }
    .width('100%')
    .justifyContent(message.role === 'user' ? FlexAlign.End : FlexAlign.Start)
    .margin({ bottom: 10 })
  }

  @Builder
  settingsCard() {
    Column() {
      Row() {
        Column() {
          Text('AI 接口配置')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.textMain)
          Text('支持 OpenAI 兼容的 Chat Completions 接口')
            .fontSize(10)
            .fontColor(AppColor.textSub)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('收起')
          .fontSize(11)
          .fontColor(AppColor.primary)
          .onClick(() => {
            this.showSettings = false;
          })
      }
      .width('100%')

      TextInput({ placeholder: 'Base URL，例如 https://api.example.com/v1', text: this.baseUrl })
        .height(40)
        .fontSize(12)
        .backgroundColor('#F5F7F9')
        .borderRadius(AppSize.radiusInner)
        .placeholderColor(AppColor.textWeak)
        .margin({ top: 12 })
        .onChange((value: string) => {
          this.baseUrl = value;
        })

      TextInput({ placeholder: 'API Key', text: this.apiKey })
        .type(InputType.Password)
        .height(40)
        .fontSize(12)
        .backgroundColor('#F5F7F9')
        .borderRadius(AppSize.radiusInner)
        .placeholderColor(AppColor.textWeak)
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.apiKey = value;
        })

      TextInput({ placeholder: '模型名称', text: this.model })
        .height(40)
        .fontSize(12)
        .backgroundColor('#F5F7F9')
        .borderRadius(AppSize.radiusInner)
        .placeholderColor(AppColor.textWeak)
        .margin({ top: 8 })
        .onChange((value: string) => {
          this.model = value;
        })

      Row() {
        Text('API Key 只保存在当前 App 会话中')
          .fontSize(10)
          .fontColor(AppColor.textWeak)
          .layoutWeight(1)
        Button('保存配置')
          .fontSize(11)
          .fontColor(Color.White)
          .height(30)
          .padding({ left: 10, right: 10 })
          .backgroundColor(AppColor.primary)
          .onClick(() => {
            this.saveSettings();
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppColor.card)
    .borderRadius(AppSize.radiusCard)
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: AppSize.gap })
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('AI 助手')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textMain)
          Text('给出学习与计划建议，不会修改你的计划')
            .fontSize(11)
            .fontColor(AppColor.textSub)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button({ type: ButtonType.Capsule }) {
          Row() {
            AppIcon({ commands: IconPath.ai, iconSize: 14, color: AppColor.primary, strokeW: 1.8 })
            Text('接口设置')
              .fontSize(11)
              .fontColor(AppColor.primary)
              .margin({ left: 4 })
          }
        }
        .height(34)
        .padding({ left: 10, right: 10 })
        .backgroundColor(AppColor.primarySoft)
        .onClick(() => {
          this.showSettings = true;
        })
      }
      .width('100%')

      if (this.showSettings) {
        this.settingsCard()
      }

      Scroll() {
        Column() {
          if (this.messages.length === 0) {
            Column() {
              Column() {
                AppIcon({ commands: IconPath.ai, iconSize: 30, color: AppColor.primary, strokeW: 1.6 })
              }
              .width(58)
              .height(58)
              .borderRadius(29)
              .backgroundColor(AppColor.primarySoft)
              .justifyContent(FlexAlign.Center)

              Text('有什么可以帮你？')
                .fontSize(14)
                .fontColor(AppColor.textMain)
                .margin({ top: 12 })
              Text('可以问学习规划、数据分析或项目复盘建议')
                .fontSize(11)
                .fontColor(AppColor.textSub)
                .margin({ top: 5 })
            }
            .width('100%')
            .padding({ top: 44, bottom: 44 })
            .justifyContent(FlexAlign.Center)
          } else {
            ForEach(this.messages, (message: AiChatMessage) => {
              this.messageBubble(message)
            }, (message: AiChatMessage, index: number) => `${index}_${message.role}`)

            if (this.sending) {
              Row() {
                Text('AI 正在思考...')
                  .fontSize(11)
                  .fontColor(AppColor.textSub)
              }
              .width('100%')
              .padding({ top: 6, bottom: 10 })
            }
          }
        }
        .width('100%')
        .padding({ top: 14, bottom: 10 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      Column() {
        Row() {
          TextArea({ placeholder: '输入你的问题...', text: this.draft })
            .height(64)
            .fontSize(13)
            .layoutWeight(1)
            .backgroundColor('#F5F7F9')
            .borderRadius(AppSize.radiusInner)
            .placeholderColor(AppColor.textWeak)
            .maxLength(1000)
            .onChange((value: string) => {
              this.draft = value;
            })
          Button(this.sending ? '发送中' : '发送')
            .fontSize(12)
            .fontColor(Color.White)
            .height(40)
            .width(64)
            .backgroundColor(AppColor.primary)
            .margin({ left: 8 })
            .enabled(!this.sending)
            .onClick(() => {
              this.send();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Text('AI 只提供建议，不会修改计划或写入打卡数据')
          .fontSize(9)
          .fontColor(AppColor.textWeak)
          .width('100%')
          .margin({ top: 5 })
      }
      .width('100%')
      .padding({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding(AppSize.pagePadding)
    .backgroundColor(AppColor.pageBg)
    .alignItems(HorizontalAlign.Start)
  }
}
