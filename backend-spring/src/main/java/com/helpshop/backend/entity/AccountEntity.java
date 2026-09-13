package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "account_user")
public class AccountEntity {
    @Id
    public String id;
    @Column(nullable = false)
    public int idUser;
    @Column(unique = true, nullable = false, length = 20)
    public String phone;
    @Column(nullable = false, length = 128)
    public String password;
    @Column(nullable = false, length = 64)
    public String displayName;
    @Column(nullable = false, length = 20)
    public String defaultRole;
    @Column(nullable = false, length = 20)
    public String status;
    @Column(length = 64)
    public String nickName;
    @Column(length = 256)
    public String avatarUri;
    @Column(length = 128)
    public String huaweiOpenId;
    @Column(length = 128)
    public String huaweiUnionId;
    @Column(nullable = false, length = 32)
    public String createdAt;
    @Column(nullable = false, length = 32)
    public String updatedAt;

    public AccountEntity() {
    }
}
