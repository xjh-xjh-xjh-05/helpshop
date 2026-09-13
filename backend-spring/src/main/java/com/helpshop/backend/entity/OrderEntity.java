package com.helpshop.backend.entity;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "order_record")
public class OrderEntity {
    @Id
    public String id;
    public String elderlyAccountId;
    public String managedByChildAccountId;
    public String productId;
    public String productName;
    public String platform;
    public Integer quantity;
    public String addressId;
    public Double totalPrice;
    public String paymentMethod;
    public String paymentStatus;
    public String createdAt;

    public OrderEntity() {
    }
}
