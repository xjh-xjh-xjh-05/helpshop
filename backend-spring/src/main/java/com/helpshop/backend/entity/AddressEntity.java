package com.helpshop.backend.entity;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "address")
public class AddressEntity {
    @Id
    public String id;
    public String elderlyAccountId;
    public String managedByChildAccountId;
    public String receiver;
    public String phone;
    public String detail;
    public Integer isDefault;
    public String createdAt;
    public String updatedAt;

    public AddressEntity() {
    }
}
