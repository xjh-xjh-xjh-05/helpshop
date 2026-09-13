package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "customer_service_profile")
public class CustomerServiceProfileEntity {
    @Id
    public String id;
    @Column(unique = true, nullable = false, length = 64)
    public String accountId;
    @Column(nullable = false, length = 64)
    public String realName;
    @Column(nullable = false, length = 64)
    public String serviceGroup;
    @Column(nullable = false)
    public int maxConcurrent;
    @Column(nullable = false, length = 20)
    public String status;
    @Column(nullable = false, length = 32)
    public String createdAt;
    @Column(nullable = false, length = 32)
    public String updatedAt;

    public CustomerServiceProfileEntity() {
    }
}
