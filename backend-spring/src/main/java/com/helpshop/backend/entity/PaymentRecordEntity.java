package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "payment_record")
public class PaymentRecordEntity {
    @Id
    public String id;
    public String orderId;
    public String elderlyAccountId;
    public String productId;
    @Column(nullable = false)
    public Double amount;
    @Column(nullable = false)
    public String method;
    @Column(nullable = false)
    public String status;
    @Column(nullable = false)
    public String message;
    @Column(nullable = false)
    public String createdAt;

    public PaymentRecordEntity() {
    }
}
