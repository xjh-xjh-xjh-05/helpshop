package com.helpshop.backend.entity;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "family_binding")
public class FamilyBindingEntity {
    @Id
    public String id;
    public String elderlyAccountId;
    public String childAccountId;
    public String bindingCode;
    public String status;
    public String createdAt;
    public String updatedAt;

    public FamilyBindingEntity() {
    }
}
