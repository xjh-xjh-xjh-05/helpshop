package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "admin_profile")
public class AdminProfileEntity {
    @Id
    public String id;
    @Column(unique = true, nullable = false, length = 64)
    public String accountId;
    @Column(nullable = false, length = 64)
    public String realName;
    @Column(nullable = false, length = 64)
    public String department;
    @Column(nullable = false, length = 256)
    public String permissions;
    @Column(nullable = false, length = 32)
    public String createdAt;
    @Column(nullable = false, length = 32)
    public String updatedAt;

    public AdminProfileEntity() {
    }
}
