/**
 * 线性图标组件：传入 22 x 22 画布下的 SVG 路径即可。
 */
@Component
export struct AppIcon {
  commands: string = '';
  iconSize: number = 22;
  color: ResourceColor = '#16202B';
  strokeW: number = 1.8;

  build() {
    Path()
      .commands(this.commands)
      .width(this.iconSize)
      .height(this.iconSize)
      .fill(Color.Transparent)
      .stroke(this.color)
      .strokeWidth(this.strokeW)
      .strokeLineCap(LineCapStyle.Round)
      .strokeLineJoin(LineJoinStyle.Round)
  }
}
