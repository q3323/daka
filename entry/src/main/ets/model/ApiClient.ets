import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ApiConfig } from '../common/ApiConfig';

const DOMAIN: number = 0x0000;
const TAG: string = 'ApiClient';

/** 统一的接口返回结构，body 保留服务端原始 JSON 文本。 */
export class ApiResult {
  ok: boolean = false;
  statusCode: number = 0;
  message: string = '';
  body: string = '';
}

export class CheckInPlanPayload {
  id: string = '';
  name: string = '';
  timesPerDay: number = 1;
  totalDays: number = 7;
  remark: string = '';
}

export class CheckInUploadPayload {
  clientRecordId: string = '';
  plan: CheckInPlanPayload = new CheckInPlanPayload();
  taskId: string = '';
  point: number = 0;
  kind: string = 'add';
  checkinTime: number = 0;
  content: string = '';
  photoBase64: string = '';
  photoMimeType: string = '';
}

export class ApiAuthUser {
  id: string = '';
  loginId: string = '';
  nickname: string = '';
  role: string = '';
}

export class ApiAuthSession {
  token: string = '';
  user: ApiAuthUser = new ApiAuthUser();
}

export class ApiClassItem {
  id: string = '';
  name: string = '';
  code: string = '';
  createdAt: string = '';
  memberCount: number = 0;
}

export class ApiClassesResponse {
  classes: ApiClassItem[] = [];
}

export class ApiClassResponse {
  class: ApiClassItem = new ApiClassItem();
}

export class ApiStudentItem {
  memberId: string = '';
  userId: string = '';
  name: string = '';
  joinedAt: string = '';
  todayCount: number = 0;
  totalCount: number = 0;
  lastCheckInAt: string = '';
}

export class ApiStudentsResponse {
  students: ApiStudentItem[] = [];
}

export class ApiTaskItem {
  id: string = '';
  classId: string = '';
  content: string = '';
  requiresPhoto: boolean = true;
  completedCount: number = 0;
  memberCount: number = 0;
  createdAt: string = '';
}

export class ApiTaskResponse {
  task: ApiTaskItem = new ApiTaskItem();
}

export class ApiTasksResponse {
  tasks: ApiTaskItem[] = [];
}

export class ApiSubmissionItem {
  memberId: string = '';
  userId: string = '';
  name: string = '';
  completed: boolean = false;
  checkInId: string = '';
  checkinTime: string = '';
  dayKey: string = '';
  content: string = '';
  photoUrl: string = '';
}

export class ApiSubmissionsResponse {
  members: ApiSubmissionItem[] = [];
}

export class ApiCheckInItem {
  id: string = '';
  planId: string = '';
  taskId: string = '';
  planName: string = '';
  clientRecordId: string = '';
  checkinTime: string = '';
  dayKey: string = '';
  photoUrl: string = '';
  content: string = '';
  point: number = 0;
  kind: string = 'add';
}

export class ApiCheckInsResponse {
  checkIns: ApiCheckInItem[] = [];
}

export class ApiPath {
  static readonly loginId: string = '/api/auth/login-id';
  static readonly registerId: string = '/api/auth/register-id';
  static readonly me: string = '/api/auth/me';
  static readonly classes: string = '/api/classes';
  static readonly joinClass: string = '/api/classes/join';
  static readonly checkIns: string = '/api/check-ins';
}

export class ApiClient {
  static async loginWithId(loginId: string): Promise<ApiResult> {
    const body: string = JSON.stringify({ loginId: loginId });
    return ApiClient.request(http.RequestMethod.POST, ApiPath.loginId, '', body);
  }

  static async registerWithId(nickname: string, role: string): Promise<ApiResult> {
    const body: string = JSON.stringify({ nickname: nickname, role: role });
    return ApiClient.request(http.RequestMethod.POST, ApiPath.registerId, '', body);
  }

  static async updateNickname(nickname: string, token: string): Promise<ApiResult> {
    const body: string = JSON.stringify({ nickname: nickname });
    return ApiClient.request(http.RequestMethod.PUT, ApiPath.me, token, body);
  }

  static async createClass(name: string, token: string): Promise<ApiResult> {
    const body: string = JSON.stringify({ name: name });
    return ApiClient.request(http.RequestMethod.POST, ApiPath.classes, token, body);
  }

  static async joinClass(code: string, token: string): Promise<ApiResult> {
    const body: string = JSON.stringify({ code: code });
    return ApiClient.request(http.RequestMethod.POST, ApiPath.joinClass, token, body);
  }

  static async getClasses(token: string): Promise<ApiResult> {
    return ApiClient.request(http.RequestMethod.GET, ApiPath.classes, token, '');
  }

  static async getClassStudents(classId: string, token: string): Promise<ApiResult> {
    const path: string = `${ApiPath.classes}/${classId}/students`;
    return ApiClient.request(http.RequestMethod.GET, path, token, '');
  }

  static async deleteClass(classId: string, token: string): Promise<ApiResult> {
    const path: string = `${ApiPath.classes}/${classId}`;
    return ApiClient.request(http.RequestMethod.DELETE, path, token, '');
  }

  static async removeMember(classId: string, memberId: string, token: string): Promise<ApiResult> {
    const path: string = `${ApiPath.classes}/${classId}/members/${memberId}`;
    return ApiClient.request(http.RequestMethod.DELETE, path, token, '');
  }

  static async createTask(classId: string, content: string, requiresPhoto: boolean,
    token: string): Promise<ApiResult> {
    const path: string = `${ApiPath.classes}/${classId}/tasks`;
    const body: string = JSON.stringify({ content: content, requiresPhoto: requiresPhoto });
    return ApiClient.request(http.RequestMethod.POST, path, token, body);
  }

  static async getClassTasks(classId: string, token: string): Promise<ApiResult> {
    const path: string = `${ApiPath.classes}/${classId}/tasks`;
    return ApiClient.request(http.RequestMethod.GET, path, token, '');
  }

  static async deleteTask(classId: string, taskId: string, token: string): Promise<ApiResult> {
    const path: string = `${ApiPath.classes}/${classId}/tasks/${taskId}`;
    return ApiClient.request(http.RequestMethod.DELETE, path, token, '');
  }

  static async getTaskSubmissions(classId: string, taskId: string, token: string): Promise<ApiResult> {
    const path: string = `${ApiPath.classes}/${classId}/tasks/${taskId}/submissions`;
    return ApiClient.request(http.RequestMethod.GET, path, token, '');
  }

  static async uploadCheckIn(payload: CheckInUploadPayload, token: string): Promise<ApiResult> {
    return ApiClient.request(http.RequestMethod.POST, ApiPath.checkIns, token, JSON.stringify(payload));
  }

  static async getCheckIns(token: string): Promise<ApiResult> {
    return ApiClient.request(http.RequestMethod.GET, ApiPath.checkIns, token, '');
  }

  private static async request(
    method: http.RequestMethod,
    path: string,
    token: string,
    body: string
  ): Promise<ApiResult> {
    const result: ApiResult = new ApiResult();
    const baseUrl: string = ApiConfig.resolveBaseUrl();
    if (baseUrl.length === 0) {
      result.message = 'API 地址尚未配置';
      return result;
    }

    const request: http.HttpRequest = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: method,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token.length > 0 ? `Bearer ${token}` : ''
        },
        connectTimeout: 10000,
        readTimeout: 15000,
        usingCache: false
      };
      if (body.length > 0) {
        options.extraData = body;
      }
      const response: http.HttpResponse = await request.request(`${baseUrl}${path}`, options);
      result.statusCode = response.responseCode;
      result.ok = response.responseCode >= 200 && response.responseCode < 300;
      result.body = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);
      result.message = result.ok ? 'ok' : `请求失败，HTTP ${response.responseCode}`;
      hilog.info(DOMAIN, TAG, '%{public}s %{public}s -> %{public}d',
        method.toString(), path, response.responseCode);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      result.message = error.message.length > 0 ? error.message : '网络请求失败';
      hilog.error(DOMAIN, TAG, 'request failed: %{public}s', result.message);
    } finally {
      request.destroy();
    }
    return result;
  }
}
