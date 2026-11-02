/**
 * 用 SVG 路径绘制的线性图标，避免依赖第三方图标库。
 * 坐标统一按 22 x 22 的画布书写。
 */
export class IconPath {
  static readonly menu: string = 'M3 5 H19 M3 11 H19 M3 17 H19';
  static readonly close: string = 'M5 5 L17 17 M17 5 L5 17';

  static readonly home: string =
    'M3 9.6 L11 3.2 L19 9.6 L19 19 L3 19 Z M8.4 19 V13.4 H13.6 V19';

  static readonly plan: string =
    'M3.6 5.6 H18.4 V19 H3.6 Z M3.6 9.6 H18.4 M7.6 3.2 V7 M14.4 3.2 V7 ' +
    'M6.6 13 H8.4 M10.1 13 H11.9 M13.6 13 H15.4';

  static readonly reward: string =
    'M11 3.2 L13.6 8.5 L19.4 9.3 L15.2 13.4 L16.2 19.2 L11 16.4 ' +
    'L5.8 19.2 L6.8 13.4 L2.6 9.3 L8.4 8.5 Z';

  static readonly mine: string =
    'M11 11.6 A3.7 3.7 0 1 0 11 4.2 A3.7 3.7 0 1 0 11 11.6 ' +
    'M3.8 19.6 C3.8 15.7 7 14 11 14 C15 14 18.2 15.7 18.2 19.6';

  static readonly ai: string =
    'M11 3 L12.8 8.2 L18 10 L12.8 11.8 L11 17 L9.2 11.8 L4 10 L9.2 8.2 Z ' +
    'M18 15 L18.8 17.2 L21 18 L18.8 18.8 L18 21 L17.2 18.8 L15 18 L17.2 17.2 Z';

  static readonly edit: string =
    'M4 18 L4.8 14.2 L14.4 4.6 L17.4 7.6 L7.8 17.2 Z M12.8 6.2 L15.8 9.2';

  static readonly users: string =
    'M8.4 11 A3.2 3.2 0 1 0 8.4 4.6 A3.2 3.2 0 1 0 8.4 11 ' +
    'M2.8 19 C2.8 15.6 5.4 14.2 8.4 14.2 C11.4 14.2 14 15.6 14 19 ' +
    'M14.8 10.6 A2.4 2.4 0 1 0 14.8 5.8 A2.4 2.4 0 1 0 14.8 10.6 ' +
    'M15.2 14.4 C17.6 14.6 19.2 15.9 19.2 18.8';

  static readonly chevronLeft: string = 'M14 4 L6 11 L14 18';
  static readonly chevronRight: string = 'M8 4 L16 11 L8 18';

  static readonly camera: string =
    'M3 7.6 H7 L8.6 5 H13.4 L15 7.6 H19 V17.6 H3 Z ' +
    'M11 9.4 A3.1 3.1 0 1 0 11 15.6 A3.1 3.1 0 1 0 11 9.4';

  static readonly gallery: string =
    'M3.4 4.6 H18.6 V17.4 H3.4 Z M3.4 13.6 L8 9.4 L11.6 12.6 ' +
    'M11.6 12.6 L14.6 10 L18.6 13.6 M7.6 8.6 A1.1 1.1 0 1 0 7.6 6.4 ' +
    'A1.1 1.1 0 1 0 7.6 8.6';

  static readonly plus: string = 'M4 11 H18 M11 4 V18';
  static readonly minus: string = 'M4 11 H18';
  static readonly trash: string =
    'M4.4 6.2 H17.6 M9 6.2 V3.8 H13 V6.2 M6.2 6.2 V19 H15.8 V6.2 ' +
    'M9.2 9.4 V16 M12.8 9.4 V16';
  static readonly undo: string =
    'M8.4 6.4 H14.6 A4.2 4.2 0 0 1 14.6 14.8 H6.4 M8.4 6.4 L5.2 3.4 ' +
    'M8.4 6.4 L5.2 9.4';
  static readonly check: string = 'M4.4 11.6 L9 16 L17.8 6.4';
  static readonly user: string =
    'M11 11.6 A3.7 3.7 0 1 0 11 4.2 A3.7 3.7 0 1 0 11 11.6 ' +
    'M3.8 19.6 C3.8 15.7 7 14 11 14 C15 14 18.2 15.7 18.2 19.6';
  static readonly clock: string =
    'M11 3.6 A7.4 7.4 0 1 0 11 18.4 A7.4 7.4 0 1 0 11 3.6 M11 7 V11.4 L14.4 13.4';
}
