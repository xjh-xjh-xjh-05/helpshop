package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "elderly_profile")
public class ElderlyProfileEntity {
    @Id
    public String id;
    @Column(unique = true, nullable = false)
    public String accountId;
    @Column(nullable = false)
    public String realName;
    @Column(nullable = false)
    public Integer age;
    @Column(nullable = false)
    public Integer careModeEnabled;
    @Column(nullable = false)
    public String emergencyPhone;
    @Column(nullable = false)
    public String bindingCode;
    @Column(nullable = false)
    public String createdAt;
    @Column(nullable = false)
    public String updatedAt;

    public ElderlyProfileEntity() {
    }
}
