package com.helpshop.backend.entity;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "audit_log")
public class AuditLogEntity {
    @Id
    public String id;
    public String actorAccountId;
    public String elderlyAccountId;
    public String action;
    public String detail;
    public String createdAt;

    public AuditLogEntity() {
    }
}
