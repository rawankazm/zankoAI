import { logger, redactSensitiveData } from '../config/logger.js';
import { Request } from 'express';

export type SecurityEventType =
  | 'AUTH_SUCCESS'
  | 'AUTH_FAILURE'
  | 'TOKEN_REVOKED'
  | 'TOKEN_INVALID'
  | 'ACCOUNT_SUSPENDED'
  | 'BRUTE_FORCE_BLOCKED'
  | 'RATE_LIMIT_EXCEEDED'
  | 'FORBIDDEN_ACCESS'
  | 'IDOR_ATTEMPT'
  | 'PRIVILEGE_ESCALATION_ATTEMPT'
  | 'MASS_ASSIGNMENT_ATTEMPT'
  | 'MALICIOUS_UPLOAD_BLOCKED'
  | 'SSRF_ATTEMPT_BLOCKED'
  | 'ADMIN_ACTION'
  | 'QUOTA_EXCEEDED'
  | 'SUSPICIOUS_PAYLOAD'
  | (string & {});

export type SecuritySeverity = 'INFO' | 'WARN' | 'CRITICAL' | string;

export interface SecurityAuditEntry {
  timestamp: string;
  eventType: SecurityEventType;
  severity: SecuritySeverity;
  ip?: string;
  userAgent?: string;
  userId?: string;
  userRole?: string;
  resource?: string;
  action?: string;
  status: 'BLOCKED' | 'DENIED' | 'ALLOWED' | 'SUCCESS' | string;
  details?: Record<string, any>;
}

export class SecurityLogger {
  /**
   * Log a structured security audit event
   */
  static log(
    entryOrType: Omit<SecurityAuditEntry, 'timestamp'> | string,
    severity?: SecuritySeverity,
    status?: 'BLOCKED' | 'DENIED' | 'ALLOWED' | 'SUCCESS' | string,
    details?: Record<string, any>
  ): void {
    let auditRecord: SecurityAuditEntry;

    if (typeof entryOrType === 'string') {
      const sanitizedDetails = details ? redactSensitiveData(details) : undefined;
      auditRecord = {
        timestamp: new Date().toISOString(),
        eventType: entryOrType as any,
        severity: (severity as any) || 'INFO',
        status: (status as any) || 'BLOCKED',
        ip: details?.ip || 'internal',
        userId: details?.userId,
        resource: details?.resource || 'system',
        details: sanitizedDetails,
      };
    } else {
      const sanitizedDetails = entryOrType.details ? redactSensitiveData(entryOrType.details) : undefined;
      auditRecord = {
        timestamp: new Date().toISOString(),
        ...entryOrType,
        ip: entryOrType.ip || 'internal',
        details: sanitizedDetails,
      };
    }

    const logMessage = `[SECURITY_AUDIT] [${auditRecord.severity}] ${auditRecord.eventType} - ${auditRecord.status} from ${auditRecord.ip} (${auditRecord.userId || 'anon'}) on ${auditRecord.resource || 'unknown'}`;

    if (auditRecord.severity === 'CRITICAL') {
      logger.error(logMessage, { securityAudit: auditRecord });
    } else if (auditRecord.severity === 'WARN') {
      logger.warn(logMessage, { securityAudit: auditRecord });
    } else {
      logger.info(logMessage, { securityAudit: auditRecord });
    }
  }

  /**
   * Helper to extract client IP and userAgent from Express Request
   */
  static fromRequest(
    req: Request,
    eventType: SecurityEventType,
    severity: SecuritySeverity,
    status: 'BLOCKED' | 'DENIED' | 'ALLOWED' | 'SUCCESS',
    details?: Record<string, any>
  ): void {
    const ip =
      (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ||
      req.socket.remoteAddress ||
      req.ip ||
      'unknown';
    const userAgent = req.headers['user-agent'];

    this.log({
      eventType,
      severity,
      ip,
      userAgent,
      userId: req.user?.id || req.profile?.id,
      userRole: req.profile?.role,
      resource: `${req.method} ${req.originalUrl || req.url}`,
      action: req.method,
      status,
      details,
    });
  }
}
