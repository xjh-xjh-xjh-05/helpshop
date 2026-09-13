import { http } from '@kit.NetworkKit';
import { CopilotConfig } from '../config/AppConfig';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class LLMMessage {
  role: string = '';
  content: string = '';

  constructor(role: string, content: string) {
    this.role = role;
    this.content = content;
  }
}

class LLMResponseMessage {
  role: string = '';
  content: string = '';
  reasoning_content: string = '';
}

class LLMChoice {
  message: LLMResponseMessage = new LLMResponseMessage();
  finish_reason: string = '';
}

class LLMResponseBody {
  choices: LLMChoice[] = [];
}

export class LLMService {
  private static instance: LLMService | undefined = undefined;

  static getInstance(): LLMService {
    if (!LLMService.instance) {
      LLMService.instance = new LLMService();
    }
    return LLMService.instance;
  }

  async chat(messages: LLMMessage[], temperature: number = 0.7, maxTokens: number = 256): Promise<string> {
    if (CopilotConfig.apiKey.trim().length === 0) {
      hilog.warn(0x0001, 'LLMService', 'apiKey not configured, skip LLM call');
      return '';
    }
    const url: string = CopilotConfig.baseUrl + '/chat/completions';
    let msgJson: string = '';
    for (let i = 0; i < messages.length; i += 1) {
      if (i > 0) {
        msgJson += ',';
      }
      const item: LLMMessage = messages[i];
      msgJson += '{"role":"' + item.role + '","content":' + JSON.stringify(item.content) + '}';
    }
    const bodyStr: string =
      '{"model":"' + CopilotConfig.model +
      '","messages":[' + msgJson +
      '],"temperature":' + temperature.toString() +
      ',"max_tokens":' + maxTokens.toString() + '}';
    hilog.info(0x0001, 'LLMService', 'LLM request body len=%{public}d preview: %{public}s',
      bodyStr.length, bodyStr.substring(0, 300));
    hilog.info(0x0001, 'LLMService', 'LLM request body full: %{public}s', bodyStr);
    try {
      const request: http.HttpRequest = http.createHttp();
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + CopilotConfig.apiKey
        },
        extraData: bodyStr,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      const responseResult: string = typeof response.result === 'string'
        ? response.result as string
        : JSON.stringify(response.result);
      hilog.info(0x0001, 'LLMService', 'LLM response status=%{public}d, bodyLen=%{public}d',
        response.responseCode, responseResult.length);
      if (response.responseCode === 200 && responseResult.length > 0) {
        const parsed: LLMResponseBody = JSON.parse(responseResult) as LLMResponseBody;
        if (parsed.choices.length > 0) {
          const msg: LLMResponseMessage = parsed.choices[0].message;
          let text: string = msg.content;
          if (text.length === 0 && msg.reasoning_content.length > 0) {
            text = msg.reasoning_content;
            hilog.info(0x0001, 'LLMService', 'LLM content empty, using reasoning_content len=%{public}d', text.length);
          }
          if (text.length > 0) {
            return text.trim();
          }
        }
      }
      hilog.warn(0x0001, 'LLMService', 'LLM unexpected response code=%{public}d body=%{public}s',
        response.responseCode, responseResult.substring(0, 500));
      return '';
    } catch (error) {
      hilog.error(0x0001, 'LLMService', 'LLM request failed: %{public}s', JSON.stringify(error));
      return '';
    }
  }

  async generateVoicePrompt(systemPrompt: string, userContext: string, fallbackText: string): Promise<string> {
    const messages: LLMMessage[] = [
      new LLMMessage('system', systemPrompt),
      new LLMMessage('user', userContext)
    ];
    const result: string = await this.chat(messages, 0.6, 150);
    return result.length > 0 ? result : fallbackText;
  }
}
