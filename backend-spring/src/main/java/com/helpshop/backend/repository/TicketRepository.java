package com.helpshop.backend.repository;

import com.helpshop.backend.entity.TicketEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TicketRepository extends JpaRepository<TicketEntity, String> {
    List<TicketEntity> findAllByOrderByCreatedAtDesc();
    List<TicketEntity> findByStatusOrderByCreatedAtDesc(String status);
    List<TicketEntity> findByCsAccountIdOrderByCreatedAtDesc(String csAccountId);
}
