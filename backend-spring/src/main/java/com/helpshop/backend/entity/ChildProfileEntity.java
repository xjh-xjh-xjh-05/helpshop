package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "child_profile")
public class ChildProfileEntity {
    @Id
    public String id;
    @Column(unique = true, nullable = false)
    public String accountId;
    @Column(nullable = false)
    public String realName;
    @Column(nullable = false)
    public String relation;
    @Column(nullable = false)
    public Integer notificationEnabled;
    @Column(nullable = false)
    public String createdAt;
    @Column(nullable = false)
    public String updatedAt;

    public ChildProfileEntity() {
    }
}
