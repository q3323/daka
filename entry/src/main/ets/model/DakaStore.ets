import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  CheckInRecord,
  ClassMember,
  ClassRoom,
  ClassTask,
  DakaData,
  KIND_ADD,
  LocalAccount,
  PlanItem,
  ROLE_STUDENT
} from './DakaModel';

const DOMAIN: number = 0x0000;
const TAG: string = 'DakaStore';
const STORE_NAME: string = 'daka_store';
const DATA_KEY: string = 'daka_data_v1';

/** 读取结果：firstRun 为 true 表示本机还没有存过数据。 */
export class LoadResult {
  data: DakaData = new DakaData();
  firstRun: boolean = false;
}

/**
 * 用 Preferences 把数据存在本机，实现「伪登录 + 数据保存」。
 */
export class DakaStore {
  static load(context: common.Context): LoadResult {
    const result: LoadResult = new LoadResult();
    try {
      const store: preferences.Preferences =
        preferences.getPreferencesSync(context, { name: STORE_NAME });
      const raw: string = store.getSync(DATA_KEY, '') as string;
      if (raw.length === 0) {
        result.firstRun = true;
        return result;
      }
      DakaStore.fill(result.data, JSON.parse(raw) as DakaData);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'load failed: %{public}s', error.message);
      // 预览器等环境可能不支持本地存储，此时按首次进入处理，保证界面可看。
      result.firstRun = true;
    }
    return result;
  }

  static save(context: common.Context, data: DakaData): void {
    try {
      const store: preferences.Preferences =
        preferences.getPreferencesSync(context, { name: STORE_NAME });
      store.putSync(DATA_KEY, JSON.stringify(data));
      store.flushSync();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'save failed: %{public}s', error.message);
    }
  }

  static clear(context: common.Context): void {
    try {
      const store: preferences.Preferences =
        preferences.getPreferencesSync(context, { name: STORE_NAME });
      store.deleteSync(DATA_KEY);
      store.flushSync();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'clear failed: %{public}s', error.message);
    }
  }

  /** 把 JSON 解析出来的普通对象补齐成完整的模型对象，避免字段缺失。 */
  private static fill(data: DakaData, raw: DakaData): void {
    data.userName = raw.userName === undefined ? '' : raw.userName;
    data.role = raw.role === undefined ? ROLE_STUDENT : raw.role;
    data.roleSelected = raw.roleSelected === undefined ? false : raw.roleSelected;
    data.demoSeeded = raw.demoSeeded === undefined ? false : raw.demoSeeded;
    data.demoTasksSeeded = raw.demoTasksSeeded === undefined ? false : raw.demoTasksSeeded;
    data.demoTaskSubmissionsSeeded =
      raw.demoTaskSubmissionsSeeded === undefined ? false : raw.demoTaskSubmissionsSeeded;
    data.currentLoginId = raw.currentLoginId === undefined ? '' : raw.currentLoginId;
    data.serverUserId = raw.serverUserId === undefined ? '' : raw.serverUserId;
    data.authToken = raw.authToken === undefined ? '' : raw.authToken;
    data.loggedIn = raw.loggedIn === undefined ? false : raw.loggedIn;

    const accounts: LocalAccount[] = [];
    const rawAccounts: LocalAccount[] = raw.localAccounts === undefined ? [] : raw.localAccounts;
    for (let i = 0; i < rawAccounts.length; i++) {
      const source: LocalAccount = rawAccounts[i];
      const account: LocalAccount = new LocalAccount();
      account.id = source.id;
      account.serverId = source.serverId === undefined ? '' : source.serverId;
      account.nickname = source.nickname;
      account.role = source.role === undefined ? ROLE_STUDENT : source.role;
      account.createdAt = source.createdAt;
      accounts.push(account);
    }
    data.localAccounts = accounts;

    const plans: PlanItem[] = [];
    const rawPlans: PlanItem[] = raw.plans === undefined ? [] : raw.plans;
    for (let i = 0; i < rawPlans.length; i++) {
      const source: PlanItem = rawPlans[i];
      const plan: PlanItem = new PlanItem();
      plan.id = source.id;
      plan.name = source.name;
      plan.timesPerDay = source.timesPerDay;
      plan.totalDays = source.totalDays;
      plan.remark = source.remark === undefined ? '' : source.remark;
      plan.createdAt = source.createdAt;
      plans.push(plan);
    }
    data.plans = plans;

    const records: CheckInRecord[] = [];
    const rawRecords: CheckInRecord[] = raw.records === undefined ? [] : raw.records;
    for (let i = 0; i < rawRecords.length; i++) {
      const source: CheckInRecord = rawRecords[i];
      const record: CheckInRecord = new CheckInRecord();
      record.id = source.id;
      record.planId = source.planId;
      record.planName = source.planName;
      record.taskId = source.taskId === undefined ? '' : source.taskId;
      record.memberId = source.memberId === undefined ? '' : source.memberId;
      record.time = source.time;
      record.dayKey = source.dayKey;
      record.photoUri = source.photoUri === undefined ? '' : source.photoUri;
      record.content = source.content === undefined ? '' : source.content;
      record.point = source.point;
      record.kind = source.kind === undefined ? KIND_ADD : source.kind;
      records.push(record);
    }
    data.records = records;

    const classRecords: CheckInRecord[] = [];
    const rawClassRecords: CheckInRecord[] = raw.classRecords === undefined ? [] : raw.classRecords;
    for (let i = 0; i < rawClassRecords.length; i++) {
      const source: CheckInRecord = rawClassRecords[i];
      const record: CheckInRecord = new CheckInRecord();
      record.id = source.id;
      record.planId = source.planId;
      record.planName = source.planName;
      record.taskId = source.taskId === undefined ? '' : source.taskId;
      record.memberId = source.memberId === undefined ? '' : source.memberId;
      record.time = source.time;
      record.dayKey = source.dayKey;
      record.photoUri = source.photoUri === undefined ? '' : source.photoUri;
      record.content = source.content === undefined ? '' : source.content;
      record.point = source.point;
      record.kind = source.kind === undefined ? KIND_ADD : source.kind;
      classRecords.push(record);
    }
    data.classRecords = classRecords;

    const classRooms: ClassRoom[] = [];
    const rawClassRooms: ClassRoom[] = raw.classRooms === undefined ? [] : raw.classRooms;
    for (let i = 0; i < rawClassRooms.length; i++) {
      const source: ClassRoom = rawClassRooms[i];
      const room: ClassRoom = new ClassRoom();
      room.id = source.id;
      room.name = source.name;
      room.code = source.code;
      room.teacherName = source.teacherName === undefined ? '' : source.teacherName;
      room.createdAt = source.createdAt;
      room.memberCount = source.memberCount === undefined ? 0 : source.memberCount;
      classRooms.push(room);
    }
    data.classRooms = classRooms;

    const members: ClassMember[] = [];
    const rawMembers: ClassMember[] = raw.members === undefined ? [] : raw.members;
    for (let i = 0; i < rawMembers.length; i++) {
      const source: ClassMember = rawMembers[i];
      const member: ClassMember = new ClassMember();
      member.id = source.id;
      member.classId = source.classId;
      member.userId = source.userId === undefined ? '' : source.userId;
      member.name = source.name;
      member.joinedAt = source.joinedAt;
      member.todayCount = source.todayCount === undefined ? 0 : source.todayCount;
      member.totalCount = source.totalCount === undefined ? 0 : source.totalCount;
      member.lastCheckInAt = source.lastCheckInAt === undefined ? 0 : source.lastCheckInAt;
      members.push(member);
    }
    data.members = members;

    const tasks: ClassTask[] = [];
    const rawTasks: ClassTask[] = raw.tasks === undefined ? [] : raw.tasks;
    for (let i = 0; i < rawTasks.length; i++) {
      const source: ClassTask = rawTasks[i];
      const task: ClassTask = new ClassTask();
      task.id = source.id;
      task.classId = source.classId;
      task.content = source.content;
      task.requiresPhoto = source.requiresPhoto === undefined ? true : source.requiresPhoto;
      task.createdAt = source.createdAt;
      task.completedCount = source.completedCount === undefined ? 0 : source.completedCount;
      task.memberCount = source.memberCount === undefined ? 0 : source.memberCount;
      tasks.push(task);
    }
    data.tasks = tasks;
  }
}
