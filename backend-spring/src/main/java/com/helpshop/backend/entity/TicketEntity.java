package com.helpshop.backend.entity;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "customer_ticket")
public class TicketEntity {
    @Id
    public String id;
    @Column(length = 64)
    public String csAccountId;
    @Column(length = 64)
    public String elderlyAccountId;
    @Column(length = 64)
    public String orderId;
    @Column(nullable = false, length = 128)
    public String title;
    @Column(length = 1024)
    public String content;
    @Column(nullable = false, length = 20)
    public String status;
    @Column(nullable = false, length = 20)
    public String priority;
    @Column(nullable = false, length = 32)
    public String createdAt;
    @Column(nullable = false, length = 32)
    public String updatedAt;

    public TicketEntity() {
    }
}
