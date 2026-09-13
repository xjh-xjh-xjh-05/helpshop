package com.helpshop.backend.entity;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "reminder")
public class ReminderEntity {
    @Id
    public String id;
    public String orderId;
    public String elderlyAccountId;
    public String childAccountId;
    public String title;
    public String content;
    public Integer readFlag;
    public String createdAt;

    public ReminderEntity() {
    }
}
