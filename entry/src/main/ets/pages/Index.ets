import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { AppIcon } from '../common/AppIcon';
import { ApiConfig } from '../common/ApiConfig';
import { IconPath } from '../common/IconPath';
import { AppColor } from '../common/Theme';
import {
  CheckInRecord,
  ClassMember,
  ClassRoom,
  ClassTask,
  DakaData,
  KIND_ADD,
  KIND_CUT,
  LocalAccount,
  PlanItem,
  ROLE_STUDENT,
  ROLE_TEACHER,
  calcScore,
  dayKeyOf,
  generateClassCode,
  generateId,
  pointPerCheckIn,
  totalDoneCount,
  totalRequiredCount
} from '../model/DakaModel';
import {
  ApiAuthSession,
  ApiClassItem,
  ApiClassResponse,
  ApiClassesResponse,
  ApiCheckInItem,
  ApiCheckInsResponse,
  ApiClient,
  ApiResult,
  ApiStudentItem,
  ApiStudentsResponse,
  ApiSubmissionItem,
  ApiSubmissionsResponse,
  ApiTaskItem,
  ApiTaskResponse,
  ApiTasksResponse,
  CheckInPlanPayload,
  CheckInUploadPayload
} from '../model/ApiClient';
import { DakaStore, LoadResult } from '../model/DakaStore';
import { AIView } from '../view/AIView';
import { HomeView } from '../view/HomeView';
import { LoginView } from '../view/LoginView';
import { MineView } from '../view/MineView';
import { PlanView } from '../view/PlanView';
import { RewardView } from '../view/RewardView';
import { StudentTasksView } from '../view/StudentTasksView';
import { TeacherEditView } from '../view/TeacherEditView';

const DOMAIN: number = 0x0000;
const TAG: string = 'DakaIndex';

class ApiMessageBody {
  message: string = '';
}

class PhotoPayload {
  valid: boolean = true;
  message: string = '';
  base64: string = '';
  mimeType: string = '';
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State userName: string = '';
  @State role: string = ROLE_STUDENT;
  @State roleSelected: boolean = false;
  @State localAccounts: LocalAccount[] = [];
  @State currentLoginId: string = '';
  @State serverUserId: string = '';
  @State authToken: string = '';
  @State loggedIn: boolean = false;
  @State plans: PlanItem[] = [];
  @State records: CheckInRecord[] = [];
  @State classRecords: CheckInRecord[] = [];
  @State classRooms: ClassRoom[] = [];
  @State members: ClassMember[] = [];
  @State tasks: ClassTask[] = [];
  @State drawerOpen: boolean = false;
  @State demoSeeded: boolean = false;
  @State demoTasksSeeded: boolean = false;
  @State demoTaskSubmissionsSeeded: boolean = false;
  @State aiBaseUrl: string = '';
  @State aiApiKey: string = '';
  @State aiModel: string = '';
  private remoteRefreshInFlight: boolean = false;

  aboutToAppear(): void {
    this.loadData();
  }

  // ---------------------------------------------------------------- 数据读写

  private hostContext(): common.Context | undefined {
    return this.getUIContext().getHostContext();
  }

  private loadData(): void {
    const context: common.Context | undefined = this.hostContext();
    if (context === undefined) {
      return;
    }
    const result: LoadResult = DakaStore.load(context);
    this.userName = result.data.userName;
    this.role = result.data.role;
    this.roleSelected = result.data.roleSelected;
    this.localAccounts = result.data.localAccounts;
    this.currentLoginId = result.data.currentLoginId;
    this.serverUserId = result.data.serverUserId;
    this.authToken = result.data.authToken;
    this.loggedIn = result.data.loggedIn;
    if (ApiConfig.isConfigured() && this.loggedIn && this.authToken.length === 0) {
      this.loggedIn = false;
      this.currentLoginId = '';
    }
    if (this.loggedIn) {
      const account: LocalAccount | undefined = this.currentAccount();
      if (account === undefined) {
        this.loggedIn = false;
      } else {
        this.userName = account.nickname;
        this.role = account.role;
      }
    }
    this.plans = result.data.plans;
    this.records = result.data.records;
    this.classRecords = result.data.classRecords;
    this.classRooms = result.data.classRooms;
    this.members = result.data.members;
    this.tasks = result.data.tasks;
    this.demoSeeded = result.data.demoSeeded;
    this.demoTasksSeeded = result.data.demoTasksSeeded;
    this.demoTaskSubmissionsSeeded = result.data.demoTaskSubmissionsSeeded;
    let shouldPersist: boolean = result.firstRun;
    if (result.firstRun && !ApiConfig.isConfigured()) {
      // 首次进入先放两个示例目标，方便直接预览打卡流程，可在「计划」页删除。
      this.plans = Index.samplePlans();
    }

    if (ApiConfig.isConfigured()) {
      if (this.clearLegacyDemoData()) {
        shouldPersist = true;
      }
      this.demoSeeded = true;
      this.demoTasksSeeded = true;
      this.demoTaskSubmissionsSeeded = true;
    } else if (!this.demoSeeded) {
      this.seedDemoClass();
      shouldPersist = true;
    } else {
      if (this.upgradeDemoRecords()) {
        shouldPersist = true;
      }
      if (!this.demoTasksSeeded) {
        this.upgradeDemoTasks();
        shouldPersist = true;
      }
      if (!this.demoTaskSubmissionsSeeded) {
        this.upgradeDemoTaskSubmissions();
        shouldPersist = true;
      }
    }
    if (shouldPersist) {
      this.persist();
    }
    if (this.loggedIn && this.authToken.length > 0 && ApiConfig.isConfigured()) {
      this.refreshRemoteData();
    }
  }

  private clearLegacyDemoData(): boolean {
    const demoClassIds: string[] = [];
    const nextRooms: ClassRoom[] = [];
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].name === '演示班级 · 高一（3）班') {
        demoClassIds.push(this.classRooms[i].id);
      } else {
        nextRooms.push(this.classRooms[i]);
      }
    }
    if (demoClassIds.length === 0) {
      return false;
    }

    const demoMemberIds: string[] = [];
    const nextMembers: ClassMember[] = [];
    for (let i = 0; i < this.members.length; i++) {
      let remove: boolean = false;
      for (let j = 0; j < demoClassIds.length; j++) {
        if (this.members[i].classId === demoClassIds[j]) {
          remove = true;
          break;
        }
      }
      if (remove) {
        demoMemberIds.push(this.members[i].id);
      } else {
        nextMembers.push(this.members[i]);
      }
    }

    const demoTasks: ClassTask[] = [];
    const nextTasks: ClassTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      let remove: boolean = false;
      for (let j = 0; j < demoClassIds.length; j++) {
        if (this.tasks[i].classId === demoClassIds[j]) {
          remove = true;
          break;
        }
      }
      if (remove) {
        demoTasks.push(this.tasks[i]);
      } else {
        nextTasks.push(this.tasks[i]);
      }
    }

    const nextRecords: CheckInRecord[] = [];
    for (let i = 0; i < this.classRecords.length; i++) {
      let remove: boolean = false;
      for (let j = 0; j < demoMemberIds.length; j++) {
        if (this.classRecords[i].memberId === demoMemberIds[j]) {
          remove = true;
          break;
        }
      }
      if (!remove) {
        for (let j = 0; j < demoTasks.length; j++) {
          if (this.classRecords[i].taskId === demoTasks[j].id) {
            remove = true;
            break;
          }
        }
      }
      if (!remove) {
        nextRecords.push(this.classRecords[i]);
      }
    }

    this.classRooms = nextRooms;
    this.members = nextMembers;
    this.tasks = nextTasks;
    this.classRecords = nextRecords;
    return true;
  }

  private persist(): void {
    const context: common.Context | undefined = this.hostContext();
    if (context === undefined) {
      return;
    }
    const data: DakaData = new DakaData();
    data.userName = this.userName;
    data.role = this.role;
    data.roleSelected = this.roleSelected;
    data.localAccounts = this.localAccounts;
    data.currentLoginId = this.currentLoginId;
    data.serverUserId = this.serverUserId;
    data.authToken = this.authToken;
    data.loggedIn = this.loggedIn;
    data.plans = this.plans;
    data.records = this.records;
    data.classRecords = this.classRecords;
    data.classRooms = this.classRooms;
    data.members = this.members;
    data.tasks = this.tasks;
    data.demoSeeded = this.demoSeeded;
    data.demoTasksSeeded = this.demoTasksSeeded;
    data.demoTaskSubmissionsSeeded = this.demoTaskSubmissionsSeeded;
    DakaStore.save(context, data);
  }

  private static samplePlans(): PlanItem[] {
    const first: PlanItem = new PlanItem();
    first.id = generateId('plan');
    first.name = '每日晨跑';
    first.timesPerDay = 1;
    first.totalDays = 30;
    first.remark = '拍一张运动后的照片，记录当天状态';
    first.createdAt = Date.now();

    const second: PlanItem = new PlanItem();
    second.id = generateId('plan');
    second.name = '背单词';
    second.timesPerDay = 2;
    second.totalDays = 30;
    second.remark = '上午和晚上各完成一次';
    second.createdAt = Date.now();

    const list: PlanItem[] = [];
    list.push(first);
    list.push(second);
    return list;
  }

  private demoRecord(memberId: string, daysAgo: number, hour: number, minute: number,
    content: string): CheckInRecord {
    const date: Date = new Date();
    date.setDate(date.getDate() - daysAgo);
    date.setHours(hour, minute, 0, 0);

    const record: CheckInRecord = new CheckInRecord();
    record.id = generateId('class_rec');
    record.planId = 'demo_class_plan';
    record.planName = '班级晨读';
    record.memberId = memberId;
    record.time = date.getTime();
    record.dayKey = dayKeyOf(record.time);
    record.photoUri = '';
    record.content = content;
    record.point = 0;
    record.kind = KIND_ADD;
    return record;
  }

  private seedDemoClass(): void {
    const room: ClassRoom = new ClassRoom();
    room.id = generateId('class');
    room.name = '演示班级 · 高一（3）班';
    room.code = generateClassCode(this.classRooms);
    room.teacherName = this.userName.length > 0 ? this.userName : '演示老师';
    room.createdAt = Date.now();

    const nextRooms: ClassRoom[] = this.classRooms.slice();
    nextRooms.push(room);
    this.classRooms = nextRooms;

    const names: string[] = ['林晓', '陈晨', '周宁', '赵一'];
    const memberIds: string[] = [];
    const nextMembers: ClassMember[] = this.members.slice();
    for (let i = 0; i < names.length; i++) {
      const member: ClassMember = new ClassMember();
      member.id = generateId('member');
      member.classId = room.id;
      member.name = names[i];
      member.joinedAt = Date.now() - (i + 1) * 86400000;
      nextMembers.push(member);
      memberIds.push(member.id);
    }
    this.members = nextMembers;

    const nextRecords: CheckInRecord[] = this.classRecords.slice();
    nextRecords.push(this.demoRecord(memberIds[0], 0, 7, 20, '完成晨读，背诵单词 20 个'));
    nextRecords.push(this.demoRecord(memberIds[0], 0, 12, 10, '午间阅读 30 分钟'));
    nextRecords.push(this.demoRecord(memberIds[0], 1, 7, 30, '完成语文课文朗读'));
    nextRecords.push(this.demoRecord(memberIds[0], 2, 8, 0, '整理英语课堂笔记'));
    nextRecords.push(this.demoRecord(memberIds[1], 0, 8, 5, '完成英语听力练习'));
    nextRecords.push(this.demoRecord(memberIds[1], 1, 8, 10, '完成数学课后作业'));
    nextRecords.push(this.demoRecord(memberIds[1], 2, 7, 55, '背诵古诗词一首'));
    nextRecords.push(this.demoRecord(memberIds[2], 1, 7, 50, '完成数学错题整理'));
    nextRecords.push(this.demoRecord(memberIds[2], 3, 8, 20, '完成物理实验记录'));
    nextRecords.push(this.demoRecord(memberIds[3], 2, 8, 15, '完成课文朗读'));
    this.classRecords = nextRecords;

    const nextTasks: ClassTask[] = this.tasks.slice();
    const firstTask: ClassTask = new ClassTask();
    firstTask.id = generateId('task');
    firstTask.classId = room.id;
    firstTask.content = '完成晨读，并上传一张晨读照片';
    firstTask.requiresPhoto = true;
    firstTask.createdAt = Date.now() - 3600000;
    nextTasks.push(firstTask);

    const secondTask: ClassTask = new ClassTask();
    secondTask.id = generateId('task');
    secondTask.classId = room.id;
    secondTask.content = '完成课后阅读 20 分钟';
    secondTask.requiresPhoto = false;
    secondTask.createdAt = Date.now() - 7200000;
    nextTasks.push(secondTask);
    this.tasks = nextTasks;

    this.demoTasksSeeded = true;
    this.demoSeeded = true;
  }

  private upgradeDemoRecords(): boolean {
    let changed: boolean = false;
    const next: CheckInRecord[] = this.classRecords.slice();
    for (let i = 0; i < next.length; i++) {
      const record: CheckInRecord = next[i];
      if (record.planId === 'demo_class_plan' && record.content.length === 0) {
        record.content = '完成班级晨读';
        changed = true;
      }
    }
    if (changed) {
      this.classRecords = next;
    }
    return changed;
  }

  private upgradeDemoTasks(): void {
    let demoRoom: ClassRoom | undefined = undefined;
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].name === '演示班级 · 高一（3）班') {
        demoRoom = this.classRooms[i];
        break;
      }
    }
    if (demoRoom === undefined) {
      this.demoTasksSeeded = true;
      return;
    }

    let existingCount: number = 0;
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].classId === demoRoom.id) {
        existingCount++;
      }
    }
    if (existingCount === 0) {
      const next: ClassTask[] = this.tasks.slice();
      const firstTask: ClassTask = new ClassTask();
      firstTask.id = generateId('task');
      firstTask.classId = demoRoom.id;
      firstTask.content = '完成晨读，并上传一张晨读照片';
      firstTask.requiresPhoto = true;
      firstTask.createdAt = Date.now() - 3600000;
      next.push(firstTask);

      const secondTask: ClassTask = new ClassTask();
      secondTask.id = generateId('task');
      secondTask.classId = demoRoom.id;
      secondTask.content = '完成课后阅读 20 分钟';
      secondTask.requiresPhoto = false;
      secondTask.createdAt = Date.now() - 7200000;
      next.push(secondTask);
      this.tasks = next;
    }
    this.demoTasksSeeded = true;
  }

  private demoTaskRecord(memberId: string, taskId: string, daysAgo: number, hour: number,
    minute: number, content: string): CheckInRecord {
    const record: CheckInRecord = this.demoRecord(memberId, daysAgo, hour, minute, content);
    record.taskId = taskId;
    return record;
  }

  private upgradeDemoTaskSubmissions(): void {
    if (this.demoTaskSubmissionsSeeded) {
      return;
    }
    let demoRoom: ClassRoom | undefined = undefined;
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].name === '演示班级 · 高一（3）班') {
        demoRoom = this.classRooms[i];
        break;
      }
    }
    if (demoRoom === undefined) {
      this.demoTaskSubmissionsSeeded = true;
      return;
    }

    const demoTasks: ClassTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].classId === demoRoom.id) {
        demoTasks.push(this.tasks[i]);
      }
    }
    const demoMembers: ClassMember[] = [];
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].classId === demoRoom.id) {
        demoMembers.push(this.members[i]);
      }
    }
    if (demoTasks.length === 0 || demoMembers.length === 0) {
      this.demoTaskSubmissionsSeeded = true;
      return;
    }

    const next: CheckInRecord[] = this.classRecords.slice();
    for (let i = 0; i < demoTasks.length && i < 2; i++) {
      let existing: number = 0;
      for (let j = 0; j < next.length; j++) {
        if (next[j].taskId === demoTasks[i].id) {
          existing++;
        }
      }
      if (existing > 0) {
        continue;
      }
      const count: number = i === 0 ? Math.min(3, demoMembers.length) : Math.min(2, demoMembers.length);
      for (let j = 0; j < count; j++) {
        next.push(this.demoTaskRecord(
          demoMembers[j].id,
          demoTasks[i].id,
          i,
          9 + j,
          10,
          `已完成：${demoTasks[i].content}`
        ));
      }
    }
    this.classRecords = next;
    this.demoTaskSubmissionsSeeded = true;
  }

  private async addTask(classId: string, content: string, requiresPhoto: boolean): Promise<string> {
    if (!this.ensureServerSession()) {
      return '';
    }
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      const result: ApiResult =
        await ApiClient.createTask(classId, content, requiresPhoto, this.authToken);
      const source: ApiTaskItem | undefined = this.parseTaskEnvelope(result);
      if (source === undefined) {
        this.toast(`发布任务失败：${this.apiMessage(result)}`);
        return '';
      }
      const task: ClassTask = this.taskFromApi(source);
      const next: ClassTask[] = this.tasks.slice();
      next.push(task);
      this.tasks = next;
      this.persist();
      await this.refreshRemoteData(true);
      this.toast('任务已发布');
      return task.id;
    }

    const task: ClassTask = new ClassTask();
    task.id = generateId('task');
    task.classId = classId;
    task.content = content;
    task.requiresPhoto = requiresPhoto;
    task.createdAt = Date.now();

    const next: ClassTask[] = this.tasks.slice();
    next.push(task);
    this.tasks = next;
    this.persist();
    this.toast('任务已发布');
    return task.id;
  }

  private async removeTask(taskId: string): Promise<boolean> {
    if (!this.ensureServerSession()) {
      return false;
    }
    let classId: string = '';
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === taskId) {
        classId = this.tasks[i].classId;
        break;
      }
    }
    if (ApiConfig.isConfigured() && this.authToken.length > 0 && classId.length > 0) {
      const result: ApiResult = await ApiClient.deleteTask(classId, taskId, this.authToken);
      if (!result.ok) {
        this.toast(`删除任务失败：${this.apiMessage(result)}`);
        return false;
      }
    }

    const next: ClassTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id !== taskId) {
        next.push(this.tasks[i]);
      }
    }
    this.tasks = next;
    const nextRecords: CheckInRecord[] = [];
    for (let i = 0; i < this.classRecords.length; i++) {
      if (this.classRecords[i].taskId !== taskId) {
        nextRecords.push(this.classRecords[i]);
      }
    }
    this.classRecords = nextRecords;
    this.persist();
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      await this.refreshRemoteData(true);
    }
    return true;
  }

  // ------------------------------------------------------------------ 计算值

  private score(): number {
    return calcScore(this.plans, this.records);
  }

  private perPoint(): number {
    return pointPerCheckIn(this.plans);
  }

  private requiredCount(): number {
    return totalRequiredCount(this.plans);
  }

  private doneCount(): number {
    return totalDoneCount(this.records);
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 1800 });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'toast failed: %{public}s', error.message);
    }
  }

  // ------------------------------------------------------------------ 打卡

  private currentMemberId(): string {
    if (this.role !== ROLE_STUDENT || this.userName.length === 0) {
      return '';
    }
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].name === this.userName) {
        return this.members[i].id;
      }
    }
    return '';
  }

  private doCheckIn(planId: string, photoUri: string): void {
    const plan: PlanItem | undefined = this.findPlan(planId);
    if (plan === undefined) {
      return;
    }
    const point: number = this.perPoint();
    const now: number = Date.now();

    const record: CheckInRecord = new CheckInRecord();
    record.id = generateId('rec');
    record.planId = plan.id;
    record.planName = plan.name;
    record.memberId = this.currentMemberId();
    record.content = plan.remark.length > 0 ? plan.remark : `完成${plan.name}`;
    record.time = now;
    record.dayKey = dayKeyOf(now);
    record.photoUri = photoUri;
    record.point = point;
    record.kind = KIND_ADD;

    const next: CheckInRecord[] = this.records.slice();
    next.push(record);
    this.records = next;
    this.persist();

    this.toast(photoUri.length > 0
      ? `打卡成功，积分 +${point}`
      : `已打卡（无照片），积分 +${point}`);
  }

  private doUndo(recordId: string): void {
    const target: CheckInRecord | undefined = this.findRecord(recordId);
    if (target === undefined) {
      return;
    }
    const point: number = this.perPoint();
    const now: number = Date.now();

    const next: CheckInRecord[] = [];
    for (let i = 0; i < this.records.length; i++) {
      const record: CheckInRecord = this.records[i];
      if (record.id !== recordId) {
        next.push(record);
      }
    }

    const cut: CheckInRecord = new CheckInRecord();
    cut.id = generateId('cut');
    cut.planId = target.planId;
    cut.planName = target.planName;
    cut.memberId = target.memberId;
    cut.time = now;
    cut.dayKey = dayKeyOf(now);
    cut.photoUri = '';
    cut.point = -point;
    cut.kind = KIND_CUT;
    next.push(cut);

    this.records = next;
    this.persist();
    this.toast(`已撤销打卡，积分 -${point}`);
  }

  private findPlan(planId: string): PlanItem | undefined {
    for (let i = 0; i < this.plans.length; i++) {
      if (this.plans[i].id === planId) {
        return this.plans[i];
      }
    }
    return undefined;
  }

  private findRecord(recordId: string): CheckInRecord | undefined {
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].id === recordId) {
        return this.records[i];
      }
    }
    return undefined;
  }

  private readPhoto(uri: string): PhotoPayload {
    const result: PhotoPayload = new PhotoPayload();
    if (uri.length === 0) {
      return result;
    }

    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      const stat: fileIo.Stat = fileIo.statSync(file.fd);
      if (stat.size <= 0) {
        result.valid = false;
        result.message = '照片内容为空';
        return result;
      }
      if (stat.size > 5 * 1024 * 1024) {
        result.valid = false;
        result.message = '照片不能超过 5MB';
        return result;
      }
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      const helper: util.Base64Helper = new util.Base64Helper();
      result.base64 = helper.encodeToStringSync(new Uint8Array(buffer));
      result.mimeType = uri.toLowerCase().includes('png') ? 'image/png' : 'image/jpeg';
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'read photo failed: %{public}s', error.message);
      result.valid = false;
      result.message = '读取照片失败';
    } finally {
      if (file !== undefined) {
        try {
          fileIo.closeSync(file);
        } catch (err) {
          hilog.warn(DOMAIN, TAG, 'close photo failed');
        }
      }
    }
    return result;
  }

  private async submitTask(taskId: string, content: string, photoUri: string): Promise<boolean> {
    if (!this.ensureServerSession()) {
      return false;
    }
    const task: ClassTask | undefined = this.findTask(taskId);
    if (task === undefined) {
      this.toast('任务不存在');
      return false;
    }
    for (let i = 0; i < this.classRecords.length; i++) {
      if (this.classRecords[i].taskId === taskId) {
        this.toast('这个任务已经提交过了');
        return false;
      }
    }
    if (task.requiresPhoto && photoUri.length === 0) {
      this.toast('这个任务需要上传照片');
      return false;
    }

    const photo: PhotoPayload = this.readPhoto(photoUri);
    if (!photo.valid) {
      this.toast(photo.message);
      return false;
    }

    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      const plan: CheckInPlanPayload = new CheckInPlanPayload();
      plan.id = `task_${task.id}`;
      plan.name = task.content.substring(0, 100);
      plan.timesPerDay = 1;
      plan.totalDays = 1;
      plan.remark = task.content.substring(0, 500);

      const payload: CheckInUploadPayload = new CheckInUploadPayload();
      payload.clientRecordId = generateId('task_record');
      payload.plan = plan;
      payload.taskId = task.id;
      payload.point = 0;
      payload.kind = KIND_ADD;
      payload.checkinTime = Date.now();
      payload.content = content;
      payload.photoBase64 = photo.base64;
      payload.photoMimeType = photo.mimeType;

      const result: ApiResult = await ApiClient.uploadCheckIn(payload, this.authToken);
      if (!result.ok) {
        this.toast(`提交失败：${this.apiMessage(result)}`);
        return false;
      }
      this.toast('任务提交成功');
      await this.refreshRemoteData(true);
      return true;
    }

    const record: CheckInRecord = new CheckInRecord();
    record.id = generateId('task_record');
    record.planId = `task_${task.id}`;
    record.planName = task.content.substring(0, 100);
    record.taskId = task.id;
    record.memberId = this.currentMemberId();
    record.time = Date.now();
    record.dayKey = dayKeyOf(record.time);
    record.photoUri = photoUri;
    record.content = content;
    record.point = 0;
    record.kind = KIND_ADD;
    const next: CheckInRecord[] = this.classRecords.slice();
    next.push(record);
    this.classRecords = next;
    this.persist();
    this.toast('任务提交成功');
    return true;
  }

  private findTask(taskId: string): ClassTask | undefined {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === taskId) {
        return this.tasks[i];
      }
    }
    return undefined;
  }

  // ------------------------------------------------------------------ 计划

  private addPlan(plan: PlanItem): void {
    const next: PlanItem[] = this.plans.slice();
    next.push(plan);
    this.plans = next;
    this.persist();
  }

  private removePlan(planId: string): void {
    const nextPlans: PlanItem[] = [];
    for (let i = 0; i < this.plans.length; i++) {
      if (this.plans[i].id !== planId) {
        nextPlans.push(this.plans[i]);
      }
    }
    const nextRecords: CheckInRecord[] = [];
    for (let i = 0; i < this.records.length; i++) {
      if (this.records[i].planId !== planId) {
        nextRecords.push(this.records[i]);
      }
    }
    this.plans = nextPlans;
    this.records = nextRecords;
    this.persist();
  }

  // ------------------------------------------------------------------ 我的

  private currentAccount(): LocalAccount | undefined {
    for (let i = 0; i < this.localAccounts.length; i++) {
      if (this.localAccounts[i].id === this.currentLoginId) {
        return this.localAccounts[i];
      }
    }
    return undefined;
  }

  private ensureServerSession(): boolean {
    if (!ApiConfig.isConfigured()) {
      return true;
    }
    if (this.authToken.length > 0) {
      return true;
    }
    this.loggedIn = false;
    this.currentLoginId = '';
    this.serverUserId = '';
    this.authToken = '';
    this.persist();
    this.toast('登录已失效，请重新登录');
    return false;
  }

  private apiMessage(result: ApiResult): string {
    if (result.body.length > 0) {
      try {
        const parsed: ApiMessageBody = JSON.parse(result.body) as ApiMessageBody;
        if (parsed.message !== undefined && parsed.message.length > 0) {
          return parsed.message;
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to parse API message');
      }
    }
    return result.message;
  }

  private parseAuthSession(result: ApiResult): ApiAuthSession | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const session: ApiAuthSession = JSON.parse(result.body) as ApiAuthSession;
      if (session.token.length === 0 || session.user.id.length === 0
        || session.user.loginId.length === 0) {
        return undefined;
      }
      return session;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse auth session');
      return undefined;
    }
  }

  private upsertLocalAccount(session: ApiAuthSession): LocalAccount {
    let account: LocalAccount | undefined = undefined;
    for (let i = 0; i < this.localAccounts.length; i++) {
      if (this.localAccounts[i].id === session.user.loginId) {
        account = this.localAccounts[i];
        break;
      }
    }
    if (account === undefined) {
      account = new LocalAccount();
      account.id = session.user.loginId;
      account.createdAt = Date.now();
      const next: LocalAccount[] = this.localAccounts.slice();
      next.push(account);
      this.localAccounts = next;
    }
    account.serverId = session.user.id;
    account.nickname = session.user.nickname;
    account.role = session.user.role;
    return account;
  }

  private generateLoginId(): string {
    const chars: string = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let id: string = '';
    while (id.length === 0) {
      let candidate: string = 'DK-';
      for (let i = 0; i < 6; i++) {
        candidate += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      let used: boolean = false;
      for (let i = 0; i < this.localAccounts.length; i++) {
        if (this.localAccounts[i].id === candidate) {
          used = true;
          break;
        }
      }
      if (!used) {
        id = candidate;
      }
    }
    return id;
  }

  private registerLocalAccount(nickname: string, role: string): LocalAccount {
    const account: LocalAccount = new LocalAccount();
    account.id = this.generateLoginId();
    account.nickname = nickname;
    account.role = role === ROLE_TEACHER ? ROLE_TEACHER : ROLE_STUDENT;
    account.createdAt = Date.now();

    const next: LocalAccount[] = this.localAccounts.slice();
    next.push(account);
    this.localAccounts = next;
    this.persist();
    return account;
  }

  private async registerAccount(nickname: string, role: string): Promise<LocalAccount> {
    if (!ApiConfig.isConfigured()) {
      return this.registerLocalAccount(nickname, role);
    }

    const result: ApiResult = await ApiClient.registerWithId(nickname, role);
    const session: ApiAuthSession | undefined = this.parseAuthSession(result);
    if (session === undefined) {
      this.toast(this.apiMessage(result));
      return new LocalAccount();
    }

    this.authToken = session.token;
    this.serverUserId = session.user.id;
    this.currentLoginId = session.user.loginId;
    const account: LocalAccount = this.upsertLocalAccount(session);
    this.persist();
    return account;
  }

  private activateAccount(account: LocalAccount): void {
    this.currentLoginId = account.id;
    this.serverUserId = account.serverId;
    this.loggedIn = true;
    this.roleSelected = true;
    this.userName = account.nickname;
    this.role = account.role;
    this.currentIndex = 0;
  }

  private async loginById(id: string): Promise<boolean> {
    const normalized: string = id.trim().toUpperCase();
    if (ApiConfig.isConfigured()) {
      const result: ApiResult = await ApiClient.loginWithId(normalized);
      const session: ApiAuthSession | undefined = this.parseAuthSession(result);
      if (session === undefined) {
        this.toast(this.apiMessage(result));
        return false;
      }
      this.authToken = session.token;
      this.serverUserId = session.user.id;
      const account: LocalAccount = this.upsertLocalAccount(session);
      this.activateAccount(account);
      this.persist();
      await this.refreshRemoteData();
      return true;
    }

    for (let i = 0; i < this.localAccounts.length; i++) {
      if (this.localAccounts[i].id === normalized) {
        this.activateAccount(this.localAccounts[i]);
        this.persist();
        return true;
      }
    }
    return false;
  }

  private async enterRegistered(id: string): Promise<boolean> {
    if (this.currentLoginId === id && this.authToken.length > 0) {
      const account: LocalAccount | undefined = this.currentAccount();
      if (account !== undefined) {
        this.activateAccount(account);
        this.persist();
        await this.refreshRemoteData();
        return true;
      }
    }
    return this.loginById(id);
  }

  private timestampOf(value: string | null | undefined): number {
    if (value === undefined || value === null || value.length === 0) {
      return Date.now();
    }
    const parsed: number = Date.parse(value);
    return Number.isNaN(parsed) ? Date.now() : parsed;
  }

  private textOf(value: string | null | undefined): string {
    return value === undefined || value === null ? '' : value;
  }

  private parseClasses(result: ApiResult): ApiClassItem[] | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const response: ApiClassesResponse = JSON.parse(result.body) as ApiClassesResponse;
      return response.classes === undefined || response.classes === null ? undefined : response.classes;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse classes');
      return undefined;
    }
  }

  private parseStudents(result: ApiResult): ApiStudentItem[] | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const response: ApiStudentsResponse = JSON.parse(result.body) as ApiStudentsResponse;
      return response.students === undefined || response.students === null ? undefined : response.students;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse students');
      return undefined;
    }
  }

  private parseTasks(result: ApiResult): ApiTaskItem[] | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const response: ApiTasksResponse = JSON.parse(result.body) as ApiTasksResponse;
      return response.tasks === undefined || response.tasks === null ? undefined : response.tasks;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse tasks');
      return undefined;
    }
  }

  private parseSubmissions(result: ApiResult): ApiSubmissionItem[] | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const response: ApiSubmissionsResponse = JSON.parse(result.body) as ApiSubmissionsResponse;
      return response.members === undefined || response.members === null ? undefined : response.members;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse submissions');
      return undefined;
    }
  }

  private parseCheckIns(result: ApiResult): ApiCheckInItem[] | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const response: ApiCheckInsResponse = JSON.parse(result.body) as ApiCheckInsResponse;
      return response.checkIns === undefined || response.checkIns === null ? undefined : response.checkIns;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse check-ins');
      return undefined;
    }
  }

  private parseClassEnvelope(result: ApiResult): ApiClassItem | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const response: ApiClassResponse = JSON.parse(result.body) as ApiClassResponse;
      return response.class.id.length > 0 ? response.class : undefined;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse class response');
      return undefined;
    }
  }

  private parseTaskEnvelope(result: ApiResult): ApiTaskItem | undefined {
    if (!result.ok || result.body.length === 0) {
      return undefined;
    }
    try {
      const response: ApiTaskResponse = JSON.parse(result.body) as ApiTaskResponse;
      return response.task.id.length > 0 ? response.task : undefined;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to parse task response');
      return undefined;
    }
  }

  private roomFromApi(source: ApiClassItem): ClassRoom {
    const room: ClassRoom = new ClassRoom();
    room.id = this.textOf(source.id);
    room.name = this.textOf(source.name);
    room.code = this.textOf(source.code);
    room.teacherName = this.role === ROLE_TEACHER ? this.userName : '';
    room.createdAt = this.timestampOf(source.createdAt);
    room.memberCount = Number(source.memberCount) || 0;
    return room;
  }

  private taskFromApi(source: ApiTaskItem): ClassTask {
    const task: ClassTask = new ClassTask();
    task.id = this.textOf(source.id);
    task.classId = this.textOf(source.classId);
    task.content = this.textOf(source.content);
    task.requiresPhoto = source.requiresPhoto;
    task.createdAt = this.timestampOf(source.createdAt);
    task.completedCount = Number(source.completedCount) || 0;
    task.memberCount = Number(source.memberCount) || 0;
    return task;
  }

  private async refreshRemoteData(silent: boolean = false): Promise<void> {
    if (this.remoteRefreshInFlight) {
      return;
    }
    if (!ApiConfig.isConfigured()) {
      return;
    }
    if (this.authToken.length === 0) {
      if (this.loggedIn) {
        this.loggedIn = false;
        this.currentLoginId = '';
        this.serverUserId = '';
        this.persist();
        if (!silent) {
          this.toast('登录已失效，请重新登录');
        }
      }
      return;
    }
    this.remoteRefreshInFlight = true;
    try {
      await this.loadRemoteDataNow(silent);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'refresh remote data failed: %{public}s', error.message);
      if (!silent) {
        this.toast('刷新服务器数据失败');
      }
    } finally {
      this.remoteRefreshInFlight = false;
    }
  }

  private async loadRemoteDataNow(silent: boolean): Promise<void> {
    const classResult: ApiResult = await ApiClient.getClasses(this.authToken);
    const remoteClasses: ApiClassItem[] | undefined = this.parseClasses(classResult);
    if (remoteClasses === undefined) {
      if (classResult.statusCode === 401) {
        this.loggedIn = false;
        this.currentLoginId = '';
        this.serverUserId = '';
        this.authToken = '';
        this.persist();
      }
      if (!silent) {
        this.toast(`加载班级失败：${this.apiMessage(classResult)}`);
      }
      return;
    }

    const rooms: ClassRoom[] = [];
    const remoteMembers: ClassMember[] = [];
    const remoteTasks: ClassTask[] = [];
    const remoteRecords: CheckInRecord[] = [];
    let studentCheckIns: ApiCheckInItem[] = [];

    if (this.role === ROLE_STUDENT) {
      const checkInResult: ApiResult = await ApiClient.getCheckIns(this.authToken);
      const parsedCheckIns: ApiCheckInItem[] | undefined = this.parseCheckIns(checkInResult);
      if (parsedCheckIns !== undefined) {
        studentCheckIns = parsedCheckIns;
      }
    }

    for (let i = 0; i < remoteClasses.length; i++) {
      const source: ApiClassItem = remoteClasses[i];
      const room: ClassRoom = this.roomFromApi(source);
      rooms.push(room);

      if (this.role === ROLE_TEACHER) {
        const studentResult: ApiResult = await ApiClient.getClassStudents(source.id, this.authToken);
        const students: ApiStudentItem[] | undefined = this.parseStudents(studentResult);
        if (students !== undefined) {
          for (let j = 0; j < students.length; j++) {
            const student: ApiStudentItem = students[j];
            const member: ClassMember = new ClassMember();
            member.id = this.textOf(student.memberId);
            member.classId = source.id;
            member.userId = this.textOf(student.userId);
            member.name = this.textOf(student.name);
            member.joinedAt = this.timestampOf(student.joinedAt);
            member.todayCount = Number(student.todayCount) || 0;
            member.totalCount = Number(student.totalCount) || 0;
            const lastCheckInAt: string = this.textOf(student.lastCheckInAt);
            member.lastCheckInAt = lastCheckInAt.length > 0 ? this.timestampOf(lastCheckInAt) : 0;
            remoteMembers.push(member);
          }
        }
      }

      const taskResult: ApiResult = await ApiClient.getClassTasks(source.id, this.authToken);
      const tasks: ApiTaskItem[] | undefined = this.parseTasks(taskResult);
      if (tasks === undefined) {
        continue;
      }
      for (let j = 0; j < tasks.length; j++) {
        const sourceTask: ApiTaskItem = tasks[j];
        const task: ClassTask = this.taskFromApi(sourceTask);
        remoteTasks.push(task);

        if (this.role === ROLE_TEACHER) {
          const submissionResult: ApiResult =
            await ApiClient.getTaskSubmissions(source.id, task.id, this.authToken);
          const submissions: ApiSubmissionItem[] | undefined = this.parseSubmissions(submissionResult);
          if (submissions === undefined) {
            continue;
          }
          for (let k = 0; k < submissions.length; k++) {
            const submission: ApiSubmissionItem = submissions[k];
            if (!submission.completed) {
              continue;
            }
            const record: CheckInRecord = new CheckInRecord();
            record.id = this.textOf(submission.checkInId);
            record.planId = task.id;
            record.planName = '班级任务';
            record.taskId = task.id;
            record.memberId = this.textOf(submission.memberId);
            record.time = this.timestampOf(submission.checkinTime);
            record.dayKey = this.textOf(submission.dayKey);
            const submissionPhoto: string = this.textOf(submission.photoUrl);
            record.photoUri = submissionPhoto.length > 0
              ? `${ApiConfig.resolveBaseUrl()}${submissionPhoto}`
              : '';
            record.content = this.textOf(submission.content);
            record.point = 0;
            record.kind = KIND_ADD;
            remoteRecords.push(record);
          }
        }
      }
    }

    this.classRooms = rooms;
    this.tasks = remoteTasks;
    if (this.role === ROLE_TEACHER) {
      this.members = remoteMembers;
      this.classRecords = remoteRecords;
    } else {
      this.members = [];
      const ownTaskRecords: CheckInRecord[] = [];
      for (let i = 0; i < studentCheckIns.length; i++) {
        const source: ApiCheckInItem = studentCheckIns[i];
        if (source.taskId.length === 0) {
          continue;
        }
        const record: CheckInRecord = new CheckInRecord();
        record.id = this.textOf(source.id);
        record.planId = this.textOf(source.planId);
        record.planName = this.textOf(source.planName);
        record.taskId = this.textOf(source.taskId);
        record.time = this.timestampOf(source.checkinTime);
        record.dayKey = this.textOf(source.dayKey);
        const checkInPhoto: string = this.textOf(source.photoUrl);
        record.photoUri = checkInPhoto.length > 0
          ? `${ApiConfig.resolveBaseUrl()}${checkInPhoto}`
          : '';
        record.content = this.textOf(source.content);
        record.point = source.point;
        record.kind = source.kind;
        ownTaskRecords.push(record);
      }
      this.classRecords = ownTaskRecords;
    }
    this.demoSeeded = true;
    this.demoTasksSeeded = true;
    this.demoTaskSubmissionsSeeded = true;
    this.persist();
  }

  private async saveName(name: string): Promise<void> {
    if (!this.ensureServerSession()) {
      return;
    }
    this.userName = name;
    for (let i = 0; i < this.localAccounts.length; i++) {
      if (this.localAccounts[i].id === this.currentLoginId) {
        this.localAccounts[i].nickname = name;
        break;
      }
    }
    this.persist();
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      const result: ApiResult = await ApiClient.updateNickname(name, this.authToken);
      if (!result.ok) {
        this.toast(`昵称同步失败：${this.apiMessage(result)}`);
      }
    }
  }

  private changeRole(role: string): void {
    if (role !== ROLE_STUDENT && role !== ROLE_TEACHER) {
      return;
    }
    if (ApiConfig.isConfigured()) {
      this.toast('连接后端后，身份由登录账号决定');
      return;
    }
    this.role = role;
    this.roleSelected = true;
    for (let i = 0; i < this.localAccounts.length; i++) {
      if (this.localAccounts[i].id === this.currentLoginId) {
        this.localAccounts[i].role = role;
        break;
      }
    }
    if (role !== ROLE_TEACHER && this.currentIndex === 5) {
      this.currentIndex = 0;
    }
    this.persist();
    this.toast(role === ROLE_TEACHER ? '已切换到老师身份' : '已切换到学生身份');
  }

  private async addClass(name: string): Promise<string> {
    if (!this.ensureServerSession()) {
      return '';
    }
    if (this.role !== ROLE_TEACHER) {
      return '';
    }
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      const result: ApiResult = await ApiClient.createClass(name, this.authToken);
      const source: ApiClassItem | undefined = this.parseClassEnvelope(result);
      if (source === undefined) {
        this.toast(`创建班级失败：${this.apiMessage(result)}`);
        return '';
      }
      const room: ClassRoom = this.roomFromApi(source);
      const next: ClassRoom[] = this.classRooms.slice();
      next.push(room);
      this.classRooms = next;
      this.persist();
      this.toast(`班级已创建，班级号 ${room.code}`);
      return room.id;
    }

    const room: ClassRoom = new ClassRoom();
    room.id = generateId('class');
    room.name = name;
    room.code = generateClassCode(this.classRooms);
    room.teacherName = this.userName;
    room.createdAt = Date.now();

    const next: ClassRoom[] = this.classRooms.slice();
    next.push(room);
    this.classRooms = next;
    this.persist();
    this.toast(`班级已创建，班级号 ${room.code}`);
    return room.id;
  }

  private async joinClass(code: string): Promise<boolean> {
    if (!this.ensureServerSession()) {
      return false;
    }
    if (this.userName.length === 0) {
      this.toast('请先在「我的」保存姓名');
      return false;
    }
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      const result: ApiResult = await ApiClient.joinClass(code, this.authToken);
      const source: ApiClassItem | undefined = this.parseClassEnvelope(result);
      if (source === undefined) {
        this.toast(`加入班级失败：${this.apiMessage(result)}`);
        return false;
      }
      const room: ClassRoom = this.roomFromApi(source);
      let exists: boolean = false;
      const next: ClassRoom[] = this.classRooms.slice();
      for (let i = 0; i < next.length; i++) {
        if (next[i].id === room.id) {
          next[i] = room;
          exists = true;
          break;
        }
      }
      if (!exists) {
        next.push(room);
      }
      this.classRooms = next;
      this.persist();
      this.toast(`已加入「${room.name}」`);
      await this.refreshRemoteData(true);
      return true;
    }

    let target: ClassRoom | undefined = undefined;
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].code === code) {
        target = this.classRooms[i];
        break;
      }
    }
    if (target === undefined) {
      this.toast('班级号不存在');
      return false;
    }
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].classId === target.id && this.members[i].name === this.userName) {
        this.toast('你已经加入该班级');
        return false;
      }
    }

    const member: ClassMember = new ClassMember();
    member.id = generateId('member');
    member.classId = target.id;
    member.name = this.userName;
    member.joinedAt = Date.now();

    const next: ClassMember[] = this.members.slice();
    next.push(member);
    this.members = next;
    this.persist();
    this.toast(`已加入「${target.name}」`);
    return true;
  }

  private async removeMember(memberId: string): Promise<boolean> {
    if (!this.ensureServerSession()) {
      return false;
    }
    let classId: string = '';
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].id === memberId) {
        classId = this.members[i].classId;
        break;
      }
    }
    if (ApiConfig.isConfigured() && this.authToken.length > 0 && classId.length > 0) {
      const result: ApiResult = await ApiClient.removeMember(classId, memberId, this.authToken);
      if (!result.ok) {
        this.toast(`移除学生失败：${this.apiMessage(result)}`);
        return false;
      }
    }

    const next: ClassMember[] = [];
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].id !== memberId) {
        next.push(this.members[i]);
      }
    }
    this.members = next;
    const nextRecords: CheckInRecord[] = [];
    for (let i = 0; i < this.classRecords.length; i++) {
      if (this.classRecords[i].memberId !== memberId) {
        nextRecords.push(this.classRecords[i]);
      }
    }
    this.classRecords = nextRecords;
    this.persist();
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      await this.refreshRemoteData(true);
    }
    return true;
  }

  private async removeClass(classId: string): Promise<boolean> {
    if (!this.ensureServerSession()) {
      return false;
    }
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      const result: ApiResult = await ApiClient.deleteClass(classId, this.authToken);
      if (!result.ok) {
        this.toast(`删除班级失败：${this.apiMessage(result)}`);
        return false;
      }
    }

    const nextRooms: ClassRoom[] = [];
    for (let i = 0; i < this.classRooms.length; i++) {
      if (this.classRooms[i].id !== classId) {
        nextRooms.push(this.classRooms[i]);
      }
    }
    const removedMemberIds: string[] = [];
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].classId === classId) {
        removedMemberIds.push(this.members[i].id);
      }
    }
    const nextMembers: ClassMember[] = [];
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].classId !== classId) {
        nextMembers.push(this.members[i]);
      }
    }
    const nextClassRecords: CheckInRecord[] = [];
    for (let i = 0; i < this.classRecords.length; i++) {
      let removed: boolean = false;
      for (let j = 0; j < removedMemberIds.length; j++) {
        if (this.classRecords[i].memberId === removedMemberIds[j]) {
          removed = true;
          break;
        }
      }
      if (!removed) {
        nextClassRecords.push(this.classRecords[i]);
      }
    }
    const nextTasks: ClassTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].classId !== classId) {
        nextTasks.push(this.tasks[i]);
      }
    }
    this.classRooms = nextRooms;
    this.members = nextMembers;
    this.classRecords = nextClassRecords;
    this.tasks = nextTasks;
    this.persist();
    if (ApiConfig.isConfigured() && this.authToken.length > 0) {
      await this.refreshRemoteData(true);
    }
    return true;
  }

  private clearRecords(): void {
    this.records = [];
    this.persist();
  }

  private clearAll(): void {
    this.userName = '';
    this.localAccounts = [];
    this.currentLoginId = '';
    this.serverUserId = '';
    this.authToken = '';
    this.loggedIn = false;
    this.plans = [];
    this.records = [];
    this.classRecords = [];
    this.classRooms = [];
    this.members = [];
    this.tasks = [];
    this.demoSeeded = false;
    this.demoTasksSeeded = false;
    this.demoTaskSubmissionsSeeded = false;
    this.role = ROLE_STUDENT;
    this.roleSelected = false;
    this.currentIndex = 0;
    this.drawerOpen = false;
    const context: common.Context | undefined = this.hostContext();
    if (context !== undefined) {
      DakaStore.clear(context);
    }
  }

  private logout(): void {
    this.loggedIn = false;
    this.currentLoginId = '';
    this.serverUserId = '';
    this.authToken = '';
    this.drawerOpen = false;
    this.currentIndex = 0;
    this.persist();
  }

  private switchTo(index: number): void {
    this.currentIndex = index;
    this.drawerOpen = false;
    if (index === 5 && this.loggedIn && this.authToken.length > 0) {
      this.refreshRemoteData(true);
    }
  }

  // ------------------------------------------------------------------ 界面

  @Builder
  navItem(index: number, title: string, commands: string) {
    Row() {
      AppIcon({
        commands: commands,
        iconSize: 20,
        color: this.currentIndex === index ? AppColor.primary : AppColor.textWeak,
        strokeW: this.currentIndex === index ? 2 : 1.7
      })
      Text(title)
        .fontSize(14)
        .fontColor(this.currentIndex === index ? AppColor.primary : AppColor.textMain)
        .margin({ left: 12 })
        .layoutWeight(1)
      if (this.currentIndex === index) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(AppColor.primary)
      }
    }
    .width('100%')
    .height(46)
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.currentIndex === index ? AppColor.primarySoft : Color.Transparent)
    .borderRadius(8)
    .margin({ bottom: 4 })
    .onClick(() => {
      this.switchTo(index);
    })
  }

  @Builder
  sideBar() {
    Column() {
      Row() {
        Column() {
          Text('打卡小助手')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColor.textMain)
          Text(this.role === ROLE_TEACHER ? '老师端' : '学生端')
            .fontSize(11)
            .fontColor(AppColor.textSub)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button({ type: ButtonType.Circle }) {
          AppIcon({ commands: IconPath.close, iconSize: 18, color: AppColor.textSub, strokeW: 1.8 })
        }
        .width(36)
        .height(36)
        .backgroundColor('#F1F3F6')
        .onClick(() => {
          this.drawerOpen = false;
        })
      }
      .width('100%')
      .height(68)
      .padding({ left: 16, right: 10 })

      Divider()
        .color(AppColor.line)

      Column() {
        this.navItem(0, '首页', IconPath.home)
        this.navItem(1, '计划', IconPath.plan)
        this.navItem(2, 'AI', IconPath.ai)
        this.navItem(3, '奖惩', IconPath.reward)
        this.navItem(4, '我的', IconPath.mine)
        if (this.role === ROLE_TEACHER) {
          this.navItem(5, '编辑', IconPath.edit)
        } else {
          this.navItem(5, '任务', IconPath.plan)
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 10 })

      Blank()

      Row() {
        Column() {
          Text(this.userName.length > 0 ? this.userName : '未设置姓名')
            .fontSize(13)
            .fontColor(AppColor.textMain)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.role === ROLE_TEACHER ? '老师身份' : '学生身份')
            .fontSize(10)
            .fontColor(AppColor.textSub)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(16)
    }
    .width(272)
    .height('100%')
    .backgroundColor(AppColor.card)
  }

  @Builder
  topBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        AppIcon({ commands: IconPath.menu, iconSize: 21, color: AppColor.textMain, strokeW: 2 })
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.drawerOpen = true;
      })

      Column() {
        Text('打卡小助手')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.textMain)
        Text(this.role === ROLE_TEACHER ? '老师端' : '学生端')
          .fontSize(10)
          .fontColor(AppColor.textSub)
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 4 })

      Blank()

      Text(this.role === ROLE_TEACHER ? '老师' : '学生')
        .fontSize(11)
        .fontColor(this.role === ROLE_TEACHER ? AppColor.primary : AppColor.info)
        .padding({ left: 9, right: 9, top: 4, bottom: 4 })
        .backgroundColor(this.role === ROLE_TEACHER ? AppColor.primarySoft : AppColor.infoSoft)
        .borderRadius(10)
    }
    .width('100%')
    .height(56)
    .padding({ left: 8, right: 16 })
  }

  build() {
    if (!this.loggedIn) {
      LoginView({
        serverMode: ApiConfig.isConfigured(),
        onLogin: (id: string) => {
          return this.loginById(id);
        },
        onRegister: (nickname: string, role: string) => {
          return this.registerAccount(nickname, role);
        },
        onEnter: (id: string) => {
          return this.enterRegistered(id);
        },
        onMessage: (message: string) => {
          this.toast(message);
        },
        onClearLocalData: () => {
          this.clearAll();
        }
      })
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.topBar()

        Column() {
          if (this.currentIndex === 0) {
            HomeView({
              plans: $plans,
              records: $records,
              userName: this.userName,
              score: this.score(),
              perPoint: this.perPoint(),
              onCheckIn: (planId: string, photoUri: string) => {
                this.doCheckIn(planId, photoUri);
              },
              onUndo: (recordId: string) => {
                this.doUndo(recordId);
              },
              onGoPlan: () => {
                this.switchTo(1);
              }
            })
          } else if (this.currentIndex === 1) {
            PlanView({
              plans: $plans,
              records: $records,
              onAddPlan: (plan: PlanItem) => {
                this.addPlan(plan);
              },
              onRemovePlan: (planId: string) => {
                this.removePlan(planId);
              }
            })
          } else if (this.currentIndex === 2) {
            AIView({
              baseUrl: $aiBaseUrl,
              apiKey: $aiApiKey,
              model: $aiModel
            })
          } else if (this.currentIndex === 3) {
            RewardView({
              records: $records,
              score: this.score(),
              perPoint: this.perPoint(),
              totalRequired: this.requiredCount(),
              totalDone: this.doneCount()
            })
          } else if (this.currentIndex === 4) {
            MineView({
              plans: $plans,
              records: $records,
              classRooms: $classRooms,
              members: $members,
              userName: this.userName,
              score: this.score(),
              role: this.role,
              loginId: this.currentLoginId,
              serverMode: ApiConfig.isConfigured(),
              roleEditable: !ApiConfig.isConfigured(),
              onSaveName: (name: string) => {
                this.saveName(name);
              },
              onClearRecords: () => {
                this.clearRecords();
              },
              onClearAll: () => {
                this.clearAll();
              },
              onChangeRole: (role: string) => {
                this.changeRole(role);
              },
              onJoinClass: (code: string) => {
                return this.joinClass(code);
              },
              onLogout: () => {
                this.logout();
              }
            })
          } else if (this.currentIndex === 5) {
            if (this.role === ROLE_TEACHER) {
              TeacherEditView({
                classRooms: $classRooms,
                members: $members,
                records: $classRecords,
                tasks: $tasks,
                onAddClass: (name: string) => {
                  return this.addClass(name);
                },
                onRemoveMember: (memberId: string) => {
                  return this.removeMember(memberId);
                },
                onRemoveClass: (classId: string) => {
                  return this.removeClass(classId);
                },
                onAddTask: (classId: string, content: string, requiresPhoto: boolean) => {
                  return this.addTask(classId, content, requiresPhoto);
                },
                onRemoveTask: (taskId: string) => {
                  return this.removeTask(taskId);
                },
                onRefresh: () => {
                  return this.refreshRemoteData(true);
                }
              })
            } else {
              StudentTasksView({
                classRooms: $classRooms,
                tasks: $tasks,
                records: $classRecords,
                onRefresh: () => {
                  return this.refreshRemoteData(true);
                },
                onSubmit: (taskId: string, content: string, photoUri: string) => {
                  return this.submitTask(taskId, content, photoUri);
                }
              })
            }
          }
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      if (this.drawerOpen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.drawerOpen = false;
          })

        this.sideBar()
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColor.pageBg)
    }
  }
}
