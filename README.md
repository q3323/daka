# Daka

一个面向班级签到与任务管理的 HarmonyOS 应用。项目由 ArkTS 客户端、Node.js/Express API 和 MySQL 数据库组成，支持老师和学生两种角色。

## 已实现功能

- ID 注册、登录和 JWT 鉴权
- 老师创建、删除班级并查看班级成员
- 学生通过班级编号加入班级
- 老师发布、删除打卡任务并查看完成情况
- 学生提交打卡内容，可选上传照片
- 老师查看学生的任务完成和未完成列表，以及历史打卡详情
- 老师/学生页面定时刷新
- 按需下载打卡照片
- OpenAI 兼容 API 聊天窗口，用户自行配置接口地址、密钥和模型

## 技术栈

- 客户端：HarmonyOS、ArkTS、ArkUI
- 后端：Node.js 20+、Express、MySQL 8+
- 部署：Nginx、PM2、Linux 云服务器

## 项目结构

```text
.
├── AppScope/                  # HarmonyOS 应用配置
├── entry/                     # ArkTS 客户端源码
├── server/
│   ├── database/              # 建表脚本、迁移和重置脚本
│   ├── deploy/                # Nginx 与 HTTPS 部署说明
│   └── src/                   # Express API
├── .gitignore
└── README.md
```

## 本地运行后端

```bash
cd server
npm install
cp .env.example .env
npm run check
npm start
```

在 `server/.env` 中填写数据库连接信息和 `JWT_SECRET`。不要提交真实 `.env`、数据库备份、私钥或签名证书。

数据库初始化方法见 [server/README.md](server/README.md)，生产部署和 HTTPS 配置见 [server/deploy/HTTPS_DEPLOY.md](server/deploy/HTTPS_DEPLOY.md)。

## 配置客户端

客户端 API 地址位于 `entry/src/main/ets/common/ApiConfig.ets`。部署到新环境后，应同时更新 API 地址并重新构建客户端。

## 上线前注意事项

- 当前 ID-only 登录仅适合测试或内部使用，正式上线前应增加密码、设备绑定或其他验证方式。
- 打卡照片目前存入 MySQL，流量增长前应迁移到 OBS，并在数据库中只保存对象键。
- API 应通过 Nginx 和 HTTPS 对外提供服务，数据库端口和 Node.js 服务端口不应直接暴露公网。
- Git 仓库不得包含 `server/.env`、手机号等个人信息、数据库备份或签名材料。
