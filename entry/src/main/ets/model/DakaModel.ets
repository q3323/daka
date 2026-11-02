/**
 * 打卡小程序的数据模型与纯计算函数。
 */

const WEEK_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

export const KIND_ADD: string = 'add';
export const KIND_CUT: string = 'cut';
export const ROLE_STUDENT: string = 'student';
export const ROLE_TEACHER: string = 'teacher';

/** 临时本地账号：ID 是唯一登录凭证。 */
export class LocalAccount {
  id: string = '';
  serverId: string = '';
  nickname: string = '';
  role: string = ROLE_STUDENT;
  createdAt: number = 0;
}

/** 一条打卡计划 / 目标。 */
export class PlanItem {
  id: string = '';
  name: string = '';
  /** 每天需要打卡的次数。 */
  timesPerDay: number = 1;
  /** 一共需要打卡的天数。 */
  totalDays: number = 7;
  remark: string = '';
  createdAt: number = 0;
}

/** 一条积分流水：打卡加分或撤销扣分。 */
export class CheckInRecord {
  id: string = '';
  planId: string = '';
  planName: string = '';
  taskId: string = '';
  /** 学生身份打卡时关联的班级成员，老师端据此聚合学生状态。 */
  memberId: string = '';
  time: number = 0;
  /** 形如 2026-10-14，用于判断「今天」。 */
  dayKey: string = '';
  photoUri: string = '';
  content: string = '';
  point: number = 0;
  kind: string = KIND_ADD;
}

/** 老师创建的班级群，code 是学生加入时使用的唯一班级号。 */
export class ClassRoom {
  id: string = '';
  name: string = '';
  code: string = '';
  teacherName: string = '';
  createdAt: number = 0;
  memberCount: number = 0;
}

/** 班级成员。正式接后端后，id 会对应服务端的成员记录。 */
export class ClassMember {
  id: string = '';
  classId: string = '';
  userId: string = '';
  name: string = '';
  joinedAt: number = 0;
  todayCount: number = 0;
  totalCount: number = 0;
  lastCheckInAt: number = 0;
}

/** 老师发布给某个班级的任务。 */
export class ClassTask {
  id: string = '';
  classId: string = '';
  content: string = '';
  requiresPhoto: boolean = true;
  createdAt: number = 0;
  completedCount: number = 0;
  memberCount: number = 0;
}

/** 需要落盘保存的全部数据。 */
export class DakaData {
  userName: string = '';
  role: string = ROLE_STUDENT;
  roleSelected: boolean = false;
  demoSeeded: boolean = false;
  demoTasksSeeded: boolean = false;
  demoTaskSubmissionsSeeded: boolean = false;
  localAccounts: LocalAccount[] = [];
  currentLoginId: string = '';
  serverUserId: string = '';
  authToken: string = '';
  loggedIn: boolean = false;
  plans: PlanItem[] = [];
  records: CheckInRecord[] = [];
  classRecords: CheckInRecord[] = [];
  classRooms: ClassRoom[] = [];
  members: ClassMember[] = [];
  tasks: ClassTask[] = [];
}

export function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function dayKeyOf(time: number): string {
  const date: Date = new Date(time);
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

export function todayKey(): string {
  return dayKeyOf(Date.now());
}

export function formatDateTitle(time: number): string {
  const date: Date = new Date(time);
  return `${date.getMonth() + 1}月${date.getDate()}日 ${WEEK_NAMES[date.getDay()]}`;
}

export function formatTime(time: number): string {
  const date: Date = new Date(time);
  return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

export function formatDateTime(time: number): string {
  const date: Date = new Date(time);
  return `${pad2(date.getMonth() + 1)}-${pad2(date.getDate())} ${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
}

export function round2(value: number): number {
  return Math.round(value * 100) / 100;
}

/** 积分的展示文案，例如 +3.33 / -1。 */
export function formatPoint(point: number): string {
  const value: number = round2(point);
  return value > 0 ? `+${value}` : `${value}`;
}

/** 单条计划一共需要打卡多少次。 */
export function planRequiredCount(plan: PlanItem): number {
  return plan.timesPerDay * plan.totalDays;
}

/** 所有计划加起来一共需要打卡多少次。 */
export function totalRequiredCount(plans: PlanItem[]): number {
  let total: number = 0;
  for (let i = 0; i < plans.length; i++) {
    total += planRequiredCount(plans[i]);
  }
  return total;
}

/** 今天一共需要打卡多少次。 */
export function todayRequiredCount(plans: PlanItem[]): number {
  let total: number = 0;
  for (let i = 0; i < plans.length; i++) {
    total += plans[i].timesPerDay;
  }
  return total;
}

/**
 * 每打卡一次增加的积分：满分为 100 分，按总打卡次数平均分配，
 * 即 100 / 总需打卡次数。
 */
export function pointPerCheckIn(plans: PlanItem[]): number {
  const total: number = totalRequiredCount(plans);
  if (total <= 0) {
    return 0;
  }
  return round2(100 / total);
}

/**
 * 当前积分 = 全部流水求和，限制在 0 ~ 100 之间；
 * 所有计划的打卡次数都完成时，直接记满分 100。
 */
export function calcScore(plans: PlanItem[], records: CheckInRecord[]): number {
  let score: number = 0;
  for (let i = 0; i < records.length; i++) {
    score += records[i].point;
  }

  const required: number = totalRequiredCount(plans);
  if (required > 0 && totalDoneCount(records) >= required) {
    return 100;
  }

  if (score < 0) {
    score = 0;
  }
  if (score > 100) {
    score = 100;
  }
  return round2(score);
}

/** 某条计划累计完成的打卡次数。 */
export function planDoneCount(records: CheckInRecord[], planId: string): number {
  let count: number = 0;
  for (let i = 0; i < records.length; i++) {
    if (records[i].kind === KIND_ADD && records[i].planId === planId) {
      count++;
    }
  }
  return count;
}

/** 某条计划今天已完成的打卡次数。 */
export function planTodayCount(records: CheckInRecord[], planId: string, key: string): number {
  let count: number = 0;
  for (let i = 0; i < records.length; i++) {
    const record: CheckInRecord = records[i];
    if (record.kind === KIND_ADD && record.planId === planId && record.dayKey === key) {
      count++;
    }
  }
  return count;
}

/** 今天所有计划合起来已完成的打卡次数。 */
export function todayDoneCount(records: CheckInRecord[], key: string): number {
  let count: number = 0;
  for (let i = 0; i < records.length; i++) {
    const record: CheckInRecord = records[i];
    if (record.kind === KIND_ADD && record.dayKey === key) {
      count++;
    }
  }
  return count;
}

/** 累计有效打卡次数。 */
export function totalDoneCount(records: CheckInRecord[]): number {
  let count: number = 0;
  for (let i = 0; i < records.length; i++) {
    if (records[i].kind === KIND_ADD) {
      count++;
    }
  }
  return count;
}

/** 累计奖励分。 */
export function sumAddedPoints(records: CheckInRecord[]): number {
  let total: number = 0;
  for (let i = 0; i < records.length; i++) {
    if (records[i].point > 0) {
      total += records[i].point;
    }
  }
  return round2(total);
}

/** 累计惩罚分（正数展示）。 */
export function sumCutPoints(records: CheckInRecord[]): number {
  let total: number = 0;
  for (let i = 0; i < records.length; i++) {
    if (records[i].point < 0) {
      total -= records[i].point;
    }
  }
  return round2(total);
}

/** 全部计划的整体完成率，0 ~ 1。 */
export function finishRate(plans: PlanItem[], records: CheckInRecord[]): number {
  const required: number = totalRequiredCount(plans);
  if (required <= 0) {
    return 0;
  }
  const done: number = totalDoneCount(records);
  const rate: number = done / required;
  return rate > 1 ? 1 : rate;
}

export function scoreLevel(score: number): string {
  if (score >= 100) {
    return '满分达人';
  }
  if (score >= 80) {
    return '自律冠军';
  }
  if (score >= 50) {
    return '打卡能手';
  }
  if (score >= 20) {
    return '渐入佳境';
  }
  return '刚刚起步';
}

export function generateId(prefix: string): string {
  const random: number = Math.floor(Math.random() * 100000);
  return `${prefix}_${Date.now()}_${random}`;
}

/** 生成六位班级号，并避免与已有班级重复。 */
export function generateClassCode(existing: ClassRoom[]): string {
  let code: string = '';
  while (code.length === 0) {
    const candidate: string = `${Math.floor(100000 + Math.random() * 900000)}`;
    let used: boolean = false;
    for (let i = 0; i < existing.length; i++) {
      if (existing[i].code === candidate) {
        used = true;
        break;
      }
    }
    if (!used) {
      code = candidate;
    }
  }
  return code;
}
