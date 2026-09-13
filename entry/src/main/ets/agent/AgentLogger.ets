import { AgentLogEntry, AgentActionType, IntentType } from './AgentModels';
import { TimeUtils } from '../utils/TimeUtils';
import { CloneUtils } from '../utils/CloneUtils';

export class AgentLogger {
  private static logs: AgentLogEntry[] = [];
  private static readonly MAX_LOGS: number = 200;

  static log(entry: AgentLogEntry): void {
    AgentLogger.logs.unshift(entry);
    if (AgentLogger.logs.length > AgentLogger.MAX_LOGS) {
      AgentLogger.logs = AgentLogger.logs.slice(0, AgentLogger.MAX_LOGS);
    }
  }

  static listLogs(sessionId: string): AgentLogEntry[] {
    if (sessionId.length === 0) {
      return AgentLogger.logs.map((entry: AgentLogEntry) => CloneUtils.cloneAgentLogEntry(entry));
    }
    return AgentLogger.logs
      .filter((entry: AgentLogEntry) => entry.sessionId === sessionId)
      .map((entry: AgentLogEntry) => CloneUtils.cloneAgentLogEntry(entry));
  }

  static listLogsByRole(role: string): AgentLogEntry[] {
    return AgentLogger.logs
      .filter((entry: AgentLogEntry) => entry.skillName.indexOf(role) >= 0)
      .map((entry: AgentLogEntry) => CloneUtils.cloneAgentLogEntry(entry));
  }

  static clearLogs(): void {
    AgentLogger.logs = [];
  }

  static createEntry(
    sessionId: string,
    input: string,
    intentType: IntentType,
    actionType: AgentActionType,
    skillName: string,
    output: string,
    durationMs: number,
    fallbackUsed: boolean
  ): AgentLogEntry {
    return {
      id: 'log-' + Date.now().toString() + '-' + Math.floor(Math.random() * 1000).toString(),
      sessionId: sessionId,
      input: input,
      intentType: intentType,
      actionType: actionType,
      skillName: skillName,
      output: output,
      durationMs: durationMs,
      fallbackUsed: fallbackUsed,
      timestamp: TimeUtils.formatDateWithSeconds(new Date())
    };
  }

}
