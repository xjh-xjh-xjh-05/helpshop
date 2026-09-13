package com.helpshop.backend.repository;

import com.helpshop.backend.entity.OrderEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface OrderRepository extends JpaRepository<OrderEntity, String> {
    List<OrderEntity> findByElderlyAccountIdOrderByCreatedAtDesc(String elderlyAccountId);
    long countByElderlyAccountId(String elderlyAccountId);
}
