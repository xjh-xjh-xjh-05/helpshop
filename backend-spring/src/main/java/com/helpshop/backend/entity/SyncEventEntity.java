package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "sync_event")
public class SyncEventEntity {
    @Id
    public String id;
    @Column(nullable = false, length = 64)
    public String elderlyAccountId;
    @Column(nullable = false, length = 32)
    public String type;
    @Column(length = 1024)
    public String payload;
    @Column(nullable = false, length = 32)
    public String createdAt;

    public SyncEventEntity() {
    }
}
