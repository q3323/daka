/** 全局配色，保持各页面风格统一。 */
export class AppColor {
  static readonly primary: string = '#12B76A';
  static readonly primaryDark: string = '#0B8A4B';
  static readonly primarySoft: string = '#E6F7EF';

  static readonly pageBg: string = '#F2F4F7';
  static readonly card: string = '#FFFFFF';
  static readonly line: string = '#E7EBF0';

  static readonly textMain: string = '#16202B';
  static readonly textSub: string = '#7A8794';
  static readonly textWeak: string = '#A9B3BE';

  static readonly amber: string = '#F79009';
  static readonly amberSoft: string = '#FEF3E2';

  static readonly danger: string = '#F04438';
  static readonly dangerSoft: string = '#FEECEB';

  static readonly info: string = '#2E90FA';
  static readonly infoSoft: string = '#E9F1FE';
}

/** 常用圆角与间距。 */
export class AppSize {
  static readonly radiusCard: number = 12;
  static readonly radiusInner: number = 8;
  static readonly pagePadding: number = 16;
  static readonly gap: number = 12;
}
