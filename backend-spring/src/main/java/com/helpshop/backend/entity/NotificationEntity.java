package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "notification")
public class NotificationEntity {
    @Id
    public String id;
    @Column(nullable = false, length = 64)
    public String elderlyAccountId;
    @Column(nullable = false, length = 64)
    public String childAccountId;
    @Column(nullable = false, length = 128)
    public String title;
    @Column(length = 512)
    public String message;
    @Column(nullable = false, length = 20)
    public String type;
    @Column(length = 64)
    public String relatedId;
    @Column(nullable = false, length = 8)
    public String read;
    @Column(nullable = false, length = 32)
    public String createdAt;

    public NotificationEntity() {
    }
}
